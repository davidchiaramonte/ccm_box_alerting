import os
import json
import logging
import asyncio
import base64
from fastapi import FastAPI, Request, HTTPException
from google.cloud import bigquery
from google.cloud import secretmanager
from google import genai
from google.genai import types
import vertexai
from vertexai.generative_models import GenerativeModel
from collections import defaultdict
import time
from typing import Optional, Union

# Import local refactored modules
import email_alert
import smtp_dispatcher # [ISOLATED SERVICE DISPATCHER COMPONENT]

# --- Environment Variables (Configured dynamically via Terraform env blocks) ---
# All hardcoded environment strings scrubbed out to generic placeholders to fulfill strict abstraction rules.
PROJECT_ID_ENV     = os.getenv('PROJECT_ID', 'change-me-gcp-project')
DATASET_ID_ENV     = os.getenv('DATASET_ID', 'anomaly_detection')
CC_EMAILS_ENV      = os.getenv('CC_EMAILS', '') 
GEMINI_MODEL_ENV   = os.getenv('GEMINI_MODEL_NAME', 'gemini-3.8-flash') 
SMTP_SECRET_ID_ENV = os.getenv('SMTP_SECRET_ID') # Full secret manager path

# --- Client & AI SDK Initializations ---
bq_client     = bigquery.Client()
secret_client = secretmanager.SecretManagerServiceClient()

# Initialize Google GenAI SDK (supports global endpoint for Gemini 3.x models) and Vertex AI SDK
genai_client = genai.Client(vertexai=True, project=PROJECT_ID_ENV, location="global")
vertexai.init(project=PROJECT_ID_ENV, location="us-central1")
ai_model = GenerativeModel(GEMINI_MODEL_ENV)
app      = FastAPI()

# Global in-memory cache to trap and suppress BigQuery Speculative Execution duplicate requests.
# Locked to single container instance via scaling parameters.
active_processing_cache = {}

# Configure Logging
logging.basicConfig(level=logging.INFO)

# Core helper to access secret strings at runtime from Secret Manager SDK
def access_secret_version(secret_version_id: str) -> str:
    try:
        response = secret_client.access_secret_version(name=secret_version_id)
        return response.payload.data.decode("UTF-8")
    except Exception as e:
        logging.error(f"SecretManager SDK failed to access version string {secret_version_id}: {e}")
        raise

async def get_anomaly_enrichment(project_id: str, target_date: str) -> Optional[dict]:
    # Queries the direct Dataform output aggregate daily summary table for service grains
    query = f"""
        SELECT
            anomaly_id,
            anomaly_already_alerted,
            most_likely_service_description AS service_description,
            top_service_increase_list
        FROM `{PROJECT_ID_ENV}.{DATASET_ID_ENV}.sp_assign_anomaly_id`('{project_id}', DATE('{target_date}'))
        LIMIT 1
    """
    try:
        query_job = bq_client.query(query)
        rows = await asyncio.to_thread(query_job.result)
        for row in rows:
            return dict(row)
        return None
    except Exception as e:
        logging.error(f"Error in get_anomaly_enrichment for {project_id} on {target_date}: {e}", exc_info=True)
        raise

async def get_ai_recommendation(
    project_id: str, 
    target_date: str, 
    service_description: str, 
    project_name: str, 
    distance_from_threshold: float, 
    top_service_list: str
    ) -> str:

    top_service_list_sql = f"'{top_service_list}'" if top_service_list else "''"
    query = f"""
        SELECT prompt FROM `{PROJECT_ID_ENV}.{DATASET_ID_ENV}.sp_generate_ai_recommendation_prompt` (
            '{project_id}', DATE('{target_date}'), '{service_description}', '{project_name}',
            CAST({distance_from_threshold} AS NUMERIC), {top_service_list_sql}
        ) LIMIT 1
    """
    try:
        query_job = bq_client.query(query)
        rows = await asyncio.to_thread(query_job.result)
        prompt = None
        for row in rows:
            prompt = row.get('prompt')
            break
            
        if not prompt:
            return "No recommendation generated."
        
        # Call the parameterized Gemini AI Model asynchronously via Google GenAI SDK (with Vertex AI fallback)
        try:
            response = await genai_client.aio.models.generate_content(
                model=GEMINI_MODEL_ENV,
                contents=prompt,
                config=types.GenerateContentConfig(
                    max_output_tokens=1000,
                    temperature=0.2,
                    top_p=0.8,
                ),
            )
            return response.text
        except Exception:
            response = await ai_model.generate_content_async(
                [prompt],
                generation_config={"max_output_tokens": 1000, "temperature": 0.2, "top_p": 0.8},
            )
            return response.text
    except Exception as e:
        logging.error(f"Vertex AI / Gemini SDK failure in get_ai_recommendation: {e}")
        raise

async def log_anomaly_bq_async(
        project_id: str, 
        project_name: str, 
        anomaly_date: str, 
        raw_owner: Union[str, list], 
        email_alert_success: bool, 
        alert_suppressed: bool, 
        upper_bound: float, 
        total_net_cost: float, 
        absolute_distance_from_threshold: float, 
        absolute_percent_from_threshold: float, 
        anomaly_id: str, 
        most_likely_service: str, 
        ai_recommendation: str
    ) -> bool:
    
    table_id = f"{PROJECT_ID_ENV}.{DATASET_ID_ENV}.cost_anomaly_alert_log"
    query = f"""
        INSERT INTO `{table_id}` (
            alert_log_timestamp, project_id, project_name, usage_start_date, owner,
            email_alert_success, alert_suppressed, expected_spend,
            actual_cost, absolute_distance_from_threshold,
            absolute_percent_from_threshold, anomaly_id,
            most_likely_service, ai_recommendation
        ) VALUES (
            CURRENT_TIMESTAMP(), @project_id, @project_name, CAST(@usage_start_date AS DATE), @owner,
            @email_alert_success, @alert_suppressed, @expected_spend,
            @actual_cost, @absolute_distance_from_threshold,
            @absolute_percent_from_threshold, @anomaly_id,
            @most_likely_service, @ai_recommendation
        )
    """
    
    expected_spend = round(upper_bound, 4) if upper_bound is not None else None
    actual_cost    = round(total_net_cost, 4) if total_net_cost is not None else None
    abs_dist       = round(absolute_distance_from_threshold, 4) if absolute_distance_from_threshold is not None else None
    abs_pct        = round(absolute_percent_from_threshold, 4) if absolute_percent_from_threshold is not None else None
    owner_str      = ",".join(raw_owner) if isinstance(raw_owner, list) else raw_owner

    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("project_id", "STRING", project_id),
            bigquery.ScalarQueryParameter("project_name", "STRING", project_name),
            bigquery.ScalarQueryParameter("usage_start_date", "STRING", anomaly_date),
            bigquery.ScalarQueryParameter("owner", "STRING", owner_str),
            bigquery.ScalarQueryParameter("email_alert_success", "BOOL", email_alert_success),
            bigquery.ScalarQueryParameter("alert_suppressed", "BOOL", alert_suppressed),
            bigquery.ScalarQueryParameter("expected_spend", "NUMERIC", expected_spend),
            bigquery.ScalarQueryParameter("actual_cost", "NUMERIC", actual_cost),
            bigquery.ScalarQueryParameter("absolute_distance_from_threshold", "NUMERIC", abs_dist),
            bigquery.ScalarQueryParameter("absolute_percent_from_threshold", "NUMERIC", abs_pct),
            bigquery.ScalarQueryParameter("anomaly_id", "STRING", anomaly_id),
            bigquery.ScalarQueryParameter("most_likely_service", "STRING", most_likely_service),
            bigquery.ScalarQueryParameter("ai_recommendation", "STRING", ai_recommendation),
        ]
    )
    try:
        query_job = await asyncio.to_thread(bq_client.query, query, job_config=job_config)
        await asyncio.to_thread(query_job.result) 
        return True
    except Exception as e:
        logging.error(f"Failed to execute BQ DML Log insertion: {e}")
        return False
   
async def process_anomaly(anomaly_details: dict) -> dict:
    project_id  = anomaly_details.get('project_id', 'unknown')
    target_date = anomaly_details.get('anomaly_date')
    
    # --- DEDUPLICATION CACHE LOCK ---
    cache_key    = f"{project_id}_{target_date}"
    current_time = time.time()

    # Evict records older than 10 mins to prevent leaks
    keys_to_delete = [k for k, timestamp in active_processing_cache.items() if (current_time - timestamp) > 600]
    for k in keys_to_delete:
        del active_processing_cache[k]
    
    if cache_key in active_processing_cache:
        logging.info(f"Trapped BQ Speculative duplicate request for {cache_key} via memory cache. Suppressing.")
        return {"anomaly_id": "duplicate_suppressed", "alert_suppressed": True}
        
    active_processing_cache[cache_key] = current_time
    # --------------------------------
    
    enrichment_data = await get_anomaly_enrichment(project_id, target_date)
    if not enrichment_data:
        return {"error": f"No enrichment data returned from procedures for project {project_id}"}

    anomaly_id          = enrichment_data.get('anomaly_id')
    already_alerted     = enrichment_data.get('anomaly_already_alerted') == 'Yes'
    most_likely_service = enrichment_data.get('service_description')
    project_name        = anomaly_details.get('project_name', 'N/A')
    department_name     = anomaly_details.get('department_name', 'N/A') # Simplified 3-column field

    if already_alerted:
        # Log suppression to BQ immediately
        await log_anomaly_bq_async(project_id, project_name, target_date, anomaly_details.get('owner'), False, True, anomaly_details.get('forecast_upper_bound'), anomaly_details.get('total_net_cost'), anomaly_details.get('absolute_distance_from_threshold'), anomaly_details.get('absolute_percent_from_threshold'), anomaly_id, most_likely_service, "N/A (Suppressed - Already Handled)")
        return {"anomaly_id": anomaly_id, "project_id": project_id, "alert_suppressed": True}

    ai_rec_raw = await get_ai_recommendation(project_id, target_date, most_likely_service, anomaly_details.get('project_name'), anomaly_details.get('absolute_distance_from_threshold', 0), enrichment_data.get('top_service_increase_list'))

    if ai_rec_raw:
        ai_rec_cleaned = ai_rec_raw.replace('\n\n•', '\n•').replace('\n\n-', '\n-').replace('\n\n*', '\n*')
        ai_rec = ai_rec_cleaned.replace('\n', '<br>')
    else:
        ai_rec = "No recommendation generated."

    # Pre-format layout data strings for payload envelope
    total_cost_str                       = f"${anomaly_details.get('total_net_cost', 0):,.2f}"
    upper_bound_str                      = f"${anomaly_details.get('forecast_upper_bound', 0):,.2f}"
    absolute_distance_from_threshold_str = f"${anomaly_details.get('absolute_distance_from_threshold', 0):,.2f}"
    absolute_percent_from_threshold_str  = f"{anomaly_details.get('absolute_percent_from_threshold', 0):.1%}"
    
    raw_owner  = anomaly_details.get('owner')
    owner_list = raw_owner if isinstance(raw_owner, list) else ([raw_owner] if raw_owner else [])
    if CC_EMAILS_ENV:
        owner_list.extend(CC_EMAILS_ENV.split(','))
    final_email_string = ",".join(owner_list)

    # Triggers Function 1 in email_alert.py: Packages the email envelope and pushes to local topic queue
    pubsub_success = await asyncio.to_thread(
        email_alert.send_email_alert,
        email_recipient_list=final_email_string,
        project_name=project_name,
        project_id=project_id,
        usage_start_date=target_date,
        usage_start_date_str_pretty=target_date,
        upper_bound_str=upper_bound_str,
        total_cost_str=total_cost_str,
        absolute_distance_from_threshold_str=absolute_distance_from_threshold_str,
        absolute_percent_from_threshold_str=absolute_percent_from_threshold_str,
        department_name=department_name,
        ai_rec=ai_rec
    )

    # Log to BQ, tracking topic queue publish success
    await log_anomaly_bq_async(project_id, project_name, target_date, raw_owner, pubsub_success, False, anomaly_details.get('forecast_upper_bound'), anomaly_details.get('total_net_cost'), anomaly_details.get('absolute_distance_from_threshold'), anomaly_details.get('absolute_percent_from_threshold'), anomaly_id, most_likely_service, ai_rec)

    return {"anomaly_id": anomaly_id, "pubsub_publish_success": pubsub_success, "alert_suppressed": False}

# ============================================================================
# ROUTE 1: PATH FOR BIGQUERY REMOTE FUNCTION CALLS
# Endpoint: '/' (FastAPI POST)
# ============================================================================
@app.post("/")
async def handle_bq_remote_function(request: Request) -> dict:
    request_json = await request.json()
    if 'calls' not in request_json:
        raise HTTPException(status_code=400, detail="Invalid BigQuery remote function invocation envelope")

    anomalies_by_project = defaultdict(list)
    for call in request_json['calls']:
        raw_payload = call[0]
        details = json.loads(raw_payload) if isinstance(raw_payload, str) else raw_payload
        project_id = details.get('project_id', 'unknown')
        anomalies_by_project[project_id].append(details)
        
    tasks = []
    for project_id, anomalies in anomalies_by_project.items():
        # Serial processing within individual project groups to preserve chronological order
        async def process_group(group: list) -> list:
            sorted_group = sorted(group, key=lambda x: x.get('anomaly_date', ''))
            res = []
            for a in sorted_group:
                res.append(await process_anomaly(a))
            return res
        tasks.append(process_group(anomalies))

    results_lists = await asyncio.gather(*tasks, return_exceptions=True)
    flat_replies  = []
    for sublist in results_lists:
        if isinstance(sublist, Exception):
            logging.error(f"A BQ Remote Function call group failed critical async gather: {sublist}")
            flat_replies.append({"error": "Task failed group execution, will be retried by BQ scheduler next cron cycle"})
        else:
            flat_replies.extend(sublist)
    return {"replies": flat_replies}

# ============================================================================
# ROUTE 2: RECEIVER FOR PUBSUB PUSH SUBSCRIPTION
# Endpoint: '/pubsub-email-alerts' (FastAPI POST)
# [ISOLATED PATTERN]: Calls the independent smtp_dispatcher component for proxy delivery
# ============================================================================
@app.post("/pubsub-email-alerts")
async def handle_pubsub_push_subscriber(request: Request) -> dict:
    request_json = await request.json()
    
    # Validate push envelope
    if 'message' not in request_json or 'data' not in request_json['message']:
        raise HTTPException(status_code=400, detail="Invalid Pub/Sub Push subscription event envelope")

    base64_data = request_json['message']['data']
    try:
        json_str = base64.b64decode(base64_data).decode('utf-8')
        payload  = json.loads(json_str)
    except Exception as e:
        logging.error(f"Failed to base64 decode or parse Pub/Sub payload JSON: {e}")
        raise HTTPException(status_code=400, detail="Message data field does not contain valid base64 JSON string")

    logging.info(f"Pub/Sub Push endpoint invoked for messageId: {request_json['message'].get('messageId')}")

    # Extract headers and HTML content from data envelope
    headers      = payload.get('headers', {})
    to_emails    = headers.get('to', [])
    subject      = headers.get('subject', 'GCP FinOps Cost Anomaly Alert')
    html_content = payload.get('content', {}).get('html')

    if not html_content:
        raise HTTPException(status_code=400, detail="Pub/Sub payload missing 'content.html' body block")

    if not SMTP_SECRET_ID_ENV:
        logging.error("SMTP_SECRET_ID environment variable is missing from container context.")
        raise HTTPException(status_code=500, detail="Internal Config Error: Missing secret manager path reference")

    # Resolve full version resource path for Secret Manager SDK
    if not SMTP_SECRET_ID_ENV.startswith("projects/"):
        secret_version_path = f"projects/{PROJECT_ID_ENV}/secrets/{SMTP_SECRET_ID_ENV}/versions/latest"
    else:
        secret_version_path = f"{SMTP_SECRET_ID_ENV}/versions/latest"

    try:
        # Resolve the raw App Password from Secret Manager at runtime using SDK
        smtp_password = access_secret_version(secret_version_path)
    except Exception as e:
        raise HTTPException(status_code=500, detail="Internal Compute Failure: Could not resolve SMTP credentials from Secret Manager")

    # [ISOLATED ROUTING]: Invokes the completely decoupled smtp_dispatcher module.
    # If you swap SMTP for SendGrid later, main.py and this endpoint logic are 100% UNCHANGED.
    email_success = smtp_dispatcher.send_email_via_smtp(
        to_emails=to_emails,
        subject=subject,
        html_content=html_content,
        smtp_password=smtp_password
    )

    if not email_success:
        # Return 500 to Pub/Sub to trigger automatic backoff retry delivery loops
        raise HTTPException(status_code=500, detail="Isolated email proxy component failed to dispatch mail, forcing retry loop")

    return {"status": "success", "message": "Email alert successfully dispatched via isolated service proxy"}

# Readiness health probe endpoint
@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}
