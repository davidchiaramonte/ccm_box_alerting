###########################################
# RAW BIGQUERY ROUTINE PROVISIONING       #
###########################################

# [CRITICAL ENVIRONMENT WORKAROUND]: We use raw, explicit resource blocks here
# instead of child module loops. This completely bypasses a second `go-cty` binary
# panic crash caused by mixed routine shapes inside lists (Scalar Remote functions vs standard TVFs).

# 1. Anomaly ID Assignment & Service Attribution TVF
resource "google_bigquery_routine" "sp_assign_anomaly_id" {
  project    = local.project_id
  dataset_id = local.dataset_configs.anomaly_detection.dataset_id
  routine_id = "sp_assign_anomaly_id"

  routine_type = "TABLE_VALUED_FUNCTION"
  language     = "SQL"

  definition_body = templatefile("${path.module}/sql/anomaly_detection/bqrt_assign_anomaly_id.sql", {
    cost_anomaly_alert_log  = "${local.project_id}.${local.dataset_configs.anomaly_detection.dataset_id}.cost_anomaly_alert_log"
    union_gcp_billing_daily = "${local.project_id}.${local.gcp_billing_dataset_id}.gcp_billing_export_daily_summary"
  })

  description = "Table valued function that assigns an anomaly ID and detects the most likely service responsible"

  arguments {
    name      = "p_project_id"
    data_type = jsonencode({ "typeKind" : "STRING" })
  }
  arguments {
    name      = "p_target_date"
    data_type = jsonencode({ "typeKind" : "DATE" })
  }

  # Use jsonencode to safely construct the complex return table schema string
  return_table_type = jsonencode({
    "columns" : [
      {
        "name" : "anomaly_id",
        "type" : { "typeKind" : "STRING" }
      },
      {
        "name" : "anomaly_already_alerted",
        "type" : { "typeKind" : "STRING" }
      },
      {
        "name" : "most_likely_service_description",
        "type" : { "typeKind" : "STRING" }
      },
      {
        "name" : "top_service_increase_list",
        "type" : { "typeKind" : "STRING" }
      }
    ]
  })

  depends_on = [
    module.bigquery_infra,
    google_bigquery_table.cost_anomaly_alert_log
  ]
}

# 2. Master Anomaly Alert Remote Function Hook (Calls Cloud Run)
resource "google_bigquery_routine" "sp_anomaly_alert_function" {
  project    = local.project_id
  dataset_id = local.dataset_configs.anomaly_detection.dataset_id
  routine_id = "sp_anomaly_alert_function"

  routine_type = "SCALAR_FUNCTION"
  description  = "BigQuery Remote Function that invokes the Cloud Run anomaly_alert app endpoint (/)"

  # Remote functions require a single space or empty body definition string
  definition_body = " " 

  arguments {
    name          = "anomaly_details_json"
    data_type     = jsonencode({ "typeKind" : "JSON" })
    argument_kind = "FIXED_TYPE"
  }

  return_type = jsonencode({ "typeKind" : "JSON" })

  # Remote options linking to our unblocked GCP resources
  remote_function_options {
    endpoint   = google_cloud_run_v2_service.anomaly_alert.uri
    connection = google_bigquery_connection.bigquery_cloudrun_connection.id # Full connection ID path
  }

  depends_on = [
    module.bigquery_infra,
    google_bigquery_connection.bigquery_cloudrun_connection,
    google_cloud_run_v2_service.anomaly_alert
  ]
}

# 3. Vertex AI LLM Prompt Builder TVF
resource "google_bigquery_routine" "sp_generate_ai_recommendation_prompt" {
  project    = local.project_id
  dataset_id = local.dataset_configs.anomaly_detection.dataset_id
  routine_id = "sp_generate_ai_recommendation_prompt"

  routine_type = "TABLE_VALUED_FUNCTION"
  language     = "SQL"

  definition_body = templatefile("${path.module}/sql/anomaly_detection/bqrt_generate_ai_recommendation_prompt.sql", {
    union_gcp_billing_daily = "${local.project_id}.${local.gcp_billing_dataset_id}.gcp_billing_export_daily_summary"
  })

  description = "Table valued function that builds the engineering prompt for Vertex AI Gemini"

  arguments {
    name      = "p_project_id"
    data_type = jsonencode({ "typeKind" : "STRING" })
  }
  arguments {
    name      = "p_target_date"
    data_type = jsonencode({ "typeKind" : "DATE" })
  }
  arguments {
    name      = "p_service_description"
    data_type = jsonencode({ "typeKind" : "STRING" })
  }
  arguments {
    name      = "p_project_name"
    data_type = jsonencode({ "typeKind" : "STRING" })
  }
  arguments {
    name      = "p_distance_from_threshold"
    data_type = jsonencode({ "typeKind" : "NUMERIC" })
  }
  arguments {
    name      = "p_top_service_increase_list"
    data_type = jsonencode({ "typeKind" : "STRING" })
  }

  return_table_type = jsonencode({
    "columns" : [
      {
        "name" : "prompt",
        "type" : { "typeKind" : "STRING" }
      }
    ]
  })

  depends_on = [module.bigquery_infra]
}
