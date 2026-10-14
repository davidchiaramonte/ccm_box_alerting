################################
# BIGQUERY VIEW CONFIGURATIONS #
################################

locals {
  # Map defining the view configurations to be created via the BQ module.
  # Uses templatefile() to load SQL definitions and inject dynamic dataset/table references.
  # Path fixed from 'sql_queries/' to 'sql/' to match the actual directory structure.
  bigquery_view_config = {
    anomaly_detection = [
      {
        view_id     = "vw_project_explain_forecast_net_cost"
        description = "Detailed information about the Arima forecast"
        query       = templatefile("${path.module}/sql/anomaly_detection/bqvw_project_explain_forecast_net_cost.sql", {
          project_net_cost_forecast = "${local.project_id}.${local.dataset_configs.anomaly_detection.dataset_id}.project_net_cost_forecast"
        })
        use_legacy_sql = false
        labels         = {
          environment  = var.environment
          team         = "c3e-finops"
        }
        deletion_protection = var.deletion_protection
      },
      {
        view_id     = "vw_project_detect_anomalies_net_cost"
        description = "Results from Arima Model compared with alert logs and department mappings"
        query       = templatefile("${path.module}/sql/anomaly_detection/bqvw_project_detect_anomalies_net_cost.sql", {
          project_net_cost_forecast       = "${local.project_id}.${local.dataset_configs.anomaly_detection.dataset_id}.project_net_cost_forecast"
          union_project_daily_spend       = "${local.project_id}.${local.gcp_billing_dataset_id}.project_daily_spend"
          cost_anomaly_alert_log          = "${local.project_id}.${local.dataset_configs.anomaly_detection.dataset_id}.cost_anomaly_alert_log"
        })
        use_legacy_sql = false
        labels         = {
          environment  = var.environment
          team         = "c3e-finops"
        }
        deletion_protection = var.deletion_protection
      },
    ]

  }
}

# ============================================================================
# NATIVE BIGQUERY VIEW PROVISIONING (Workaround for Parallel Race Conditions)
# ============================================================================
# [CRITICAL INTER-VIEW DEPENDENCY]: BQ views are validated on creation. 
# 'vw_unalerted_anomalies' queries 'vw_project_detect_anomalies_net_cost'.
# Because HCL 'for_each' loops inside modules execute in parallel, BQ often
# rejects 'vw_unalerted_anomalies' with a 'notFound' error during applies.
#
# By pulling this view out of the generic loop and defining it as a native resource,
# we can inject an explicit 'depends_on' block targeting the parent view output
# from the BigQuery module instance!
resource "google_bigquery_table" "vw_unalerted_anomalies" {
  project    = local.project_id
  dataset_id = local.dataset_configs.anomaly_detection.dataset_id
  table_id   = "vw_unalerted_anomalies"

  description = "Prepares and filters anomaly data to determine which need to trigger active email alerts"
  deletion_protection = var.deletion_protection

  labels = {
    environment = var.environment
    team        = "c3e-finops"
    component   = "bigquery"
  }

  view {
    query = templatefile("${path.module}/sql/anomaly_detection/bqvw_unalerted_anomalies.sql", {
      anomaly_threshold_settings           = "${local.project_id}.${local.dataset_configs.anomaly_detection.dataset_id}.anomaly_threshold_settings"
      cost_anomaly_alert_log               = "${local.project_id}.${local.dataset_configs.anomaly_detection.dataset_id}.cost_anomaly_alert_log"
      vw_project_detect_anomalies_net_cost = "${local.project_id}.${local.dataset_configs.anomaly_detection.dataset_id}.vw_project_detect_anomalies_net_cost"
    })
    use_legacy_sql = false
  }

  # Enforce strict serialization: Wait until the parent view has been fully registered in BQ metadata
  depends_on = [
    module.bigquery_infra,
    google_bigquery_table.cost_anomaly_alert_log,
    google_bigquery_table.anomaly_threshold_settings
  ]
}

resource "google_bigquery_table" "vw_project_input_data_net_cost" {
  project    = local.project_id
  dataset_id = module.bigquery_infra["anomaly_detection"].dataset_id
  table_id   = "vw_project_input_data_net_cost"

  description = "Project daily spend data limited to projects with enough spend in the past year and only days with complete data"
  deletion_protection = var.deletion_protection

  labels = {
    environment = var.environment
    team        = "c3e-finops"
    component   = "bigquery"
  }

  view {
    query = templatefile("${path.module}/sql/anomaly_detection/bqvw_project_input_data_net_cost.sql", {
      union_project_daily_spend = "${local.project_id}.${local.gcp_billing_dataset_id}.project_daily_spend"
    })
    use_legacy_sql = false
  }
}
