import os
import json
import logging
from google.cloud import pubsub_v1
from datetime import datetime, timezone

# Initialize Pub/Sub Publisher Client
publisher = pubsub_v1.PublisherClient()
PROJECT_ID = os.environ.get('PUBSUB_PROJECT_ID')
TOPIC_ID    = os.environ.get('PUBSUB_TOPIC_ID')

# SMTP Sender Email Username (Resolved strictly from environment - 100% abstracted)
SMTP_USER = os.environ.get('SMTP_USER') 

def get_utc_timestamp() -> str:
  # Returns current UTC time in YYYY-MM-DDT00:00:00Z format
  return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

# ============================================================================
# FUNCTION 1: QUEUE PUBLISHER (Called by main.py Endpoint: '/')
# Packages the cost anomaly metrics into an envelope and pushes it to Pub/Sub
# ============================================================================
def send_email_alert(
      email_recipient_list: str, 
      project_name: str, 
      project_id: str, 
      usage_start_date: str, 
      usage_start_date_str_pretty: str, 
      upper_bound_str: str, 
      total_cost_str: str, 
      absolute_distance_from_threshold_str: str, 
      absolute_percent_from_threshold_str: str, 
      department_name: str, # Simplified 3-column native mapping schema field
      ai_rec: str
  ) -> bool:

  TIME_STAMP = datetime.now().strftime("%Y-%m-%d")

  # Streamlined HTML Template
  html_content = f"""
  <html>
  <body style="font-family: sans-serif; color: #333; line-height: 1.5;">
    <p>Hi,</p>
    <p>It looks like there is an unexpected spike in Google Cloud Platform costs associated with your project: <strong>{project_name}</strong></p>
    
    <p><strong>AI Generated Remediation Recommendation:</strong></p>
    <div style="background-color: #f4f6f9; padding: 15px; border-left: 5px solid #1a73e8; font-style: italic; margin-bottom: 20px; border-radius: 4px;">
      {ai_rec}
    </div>
      
    <p><strong>Cost Anomaly Details:</strong></p>
    <table style="border-collapse: collapse; font-family: sans-serif; width: 100%; max-width: 600px; margin-bottom: 20px;">
      <tr>
        <td style="border: 1px solid #dadce0; padding: 10px; font-weight: bold; background-color: #f8f9fa; width: 40%;">Project Name</td>
        <td style="border: 1px solid #dadce0; padding: 10px;">{project_name}</td>
      </tr>
      <tr>
        <td style="border: 1px solid #dadce0; padding: 10px; font-weight: bold; background-color: #f8f9fa;">Project ID</td>
        <td style="border: 1px solid #dadce0; padding: 10px;">{project_id}</td>
      </tr>
      <tr>
        <td style="border: 1px solid #dadce0; padding: 10px; font-weight: bold; background-color: #f8f9fa;">Anomaly Date</td>
        <td style="border: 1px solid #dadce0; padding: 10px;">{usage_start_date_str_pretty}</td>
      </tr>
      <tr>
        <td style="border: 1px solid #dadce0; padding: 10px; font-weight: bold; color: #d93025; background-color: #fdf2f2;">Anomaly Amount (Overrun)</td> 
        <td style="border: 1px solid #dadce0; padding: 10px; color: #d93025; font-weight: bold; background-color: #fdf2f2;">{absolute_distance_from_threshold_str}</td> 
      </tr>
      <tr>
        <td style="border: 1px solid #dadce0; padding: 10px; font-weight: bold; background-color: #f8f9fa;">Actual Cost for Day</td> 
        <td style="border: 1px solid #dadce0; padding: 10px;">{total_cost_str}</td> 
      </tr>
      <tr>
        <td style="border: 1px solid #dadce0; padding: 10px; font-weight: bold; background-color: #f8f9fa;">Expected Upper Bound</td> 
        <td style="border: 1px solid #dadce0; padding: 10px;">{upper_bound_str}</td> 
      </tr>
      <tr>
        <td style="border: 1px solid #dadce0; padding: 10px; font-weight: bold; background-color: #f8f9fa;">Anomaly Overrun Percentage</td> 
        <td style="border: 1px solid #dadce0; padding: 10px;">{absolute_percent_from_threshold_str}</td> 
      </tr>
      <tr>
        <td style="border: 1px solid #dadce0; padding: 10px; font-weight: bold; background-color: #f8f9fa;">Department Name</td>
        <td style="border: 1px solid #dadce0; padding: 10px;">{department_name}</td>
      </tr>
    </table>
    
    <p>Thanks,<br>
      GCP Anomaly Inspector</p>
  </body>
  </html>
  """

  # Filter valid email recipients
  email_list = [email.strip() for email in email_recipient_list.split(',') if '@' in email]
  email_list_json_block = [{"name": email.split('@')[0].title(), "email": email} for email in email_list]

  if not SMTP_USER:
      logging.error("SMTP_USER environment variable is missing from container context.")
      return False

  # Pack standard payload envelope
  payload = {
    "metadata": {
      "appId": "ccm-toolkit-alerting",
      "messageId": f"ccm_anomaly_{project_id}_{TIME_STAMP}",
      "timestamp": get_utc_timestamp(),
      "priority": "high"
    },
    "headers": {
      "from": {
        "name": "GCP FinOps Alerting System",
        "email": SMTP_USER # Sender resolves strictly from HCL injected environment
      },
      "to": email_list_json_block,
      "subject": f'Action Required! Cost Anomaly in Project: {project_name}'
    },
    "content": {
      "html": html_content,
      "text": f"Action Required! Cost overrun of {absolute_distance_from_threshold_str} detected in project {project_name} ({project_id}) on {usage_start_date_str_pretty}."
    }
  }

  if not PROJECT_ID or not TOPIC_ID:
    logging.error("Pub/Sub target configuration variables are missing (PUBSUB_PROJECT_ID / PUBSUB_TOPIC_ID).")
    return False

  topic_path = publisher.topic_path(PROJECT_ID, TOPIC_ID)
  data = json.dumps(payload).encode("utf-8")

  try:
      future = publisher.publish(topic_path, data)
      message_id = future.result() # Synchronously blocks until published to topic queue
      logging.info(f"Successfully published anomaly payload envelope to Pub/Sub topic. ID: {message_id}")
      return True
  except Exception as e:
      logging.error(f"Failed to publish payload to Pub/Sub topic {TOPIC_ID}: {e}")
      return False
