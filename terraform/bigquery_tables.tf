###########################################
# NATIVE BIGQUERY TABLE PROVISIONING      #
###########################################

# [CRITICAL ENVIRONMENT WORKAROUND]: We use raw, explicit resource blocks here
# instead of looping via the child module. This completely bypasses a severe
# Terraform 0.14 `go-cty` binary panic ("panic: inconsistent list element types")
# caused by mixed optional attribute shapes in child module lists (partitioning vs non-partitioning).

# 1. Simplified Project to Alert Owner/Recipient Mapping Table
resource "google_bigquery_table" "project_owner_mapping" {
  project    = local.project_id
  dataset_id = module.bigquery_infra["anomaly_detection"].dataset_id
  table_id   = "project_owner_mapping"

  description = "Simplified mapping table for project ID to alert recipient owner email and department name"
  schema      = file("schemas/project_owner_mapping.json")

  # Deletion protection parameterization honored
  deletion_protection = var.deletion_protection

  labels = {
    environment = var.environment
    component   = "bigquery"
  }
}

# 2. Anomaly Alert Log (Tracks suppression and email states)
resource "google_bigquery_table" "cost_anomaly_alert_log" {
  project    = local.project_id
  dataset_id = module.bigquery_infra["anomaly_detection"].dataset_id
  table_id   = "cost_anomaly_alert_log"

  description = "Logs all cost anomaly alerts sent and suppressed"
  schema      = file("schemas/cost_anomaly_alert_log.json")

  deletion_protection = var.deletion_protection

  # Active Time Partitioning block
  time_partitioning {
    type  = "DAY"
    field = "usage_start_date"
  }

  # Active Clustering array
  clustering = ["project_id", "anomaly_id"]

  labels = {
    environment = var.environment
    component   = "bigquery"
  }
}

# 3. Anomaly Custom Threshold Settings (Allows overriding delta/percentage defaults)
resource "google_bigquery_table" "anomaly_threshold_settings" {
  project    = local.project_id
  dataset_id = module.bigquery_infra["anomaly_detection"].dataset_id
  table_id   = "anomaly_threshold_settings"

  description = "Stores custom anomaly alerting thresholds for specific projects and time periods"
  schema      = file("schemas/anomaly_threshold_settings.json")

  deletion_protection = var.deletion_protection

  # Active Clustering without partitioning
  clustering = ["project_id", "setting_start_date"]

  labels = {
    environment = var.environment
    component   = "bigquery"
  }
}

# 4. BQML Model Version Metadata Log (Required by train_arima_model.sql DML)
resource "google_bigquery_table" "anomaly_detection_bqml_model_info" {
  project    = local.project_id
  dataset_id = module.bigquery_infra["anomaly_detection"].dataset_id
  table_id   = "anomaly_detection_bqml_model_info"

  description = "Table containing versioning information on the ARIMA Model"
  schema      = file("schemas/anomaly_detection_bqml_model_info.json")

  deletion_protection = var.deletion_protection

  labels = {
    environment = var.environment
    component   = "bigquery"
  }
}

# 5. ARIMA Evaluate Coefficients Output Table (Required by train_arima_model.sql DML)
resource "google_bigquery_table" "arima_evaluate_project_net_cost_forecast" {
  project    = local.project_id
  dataset_id = module.bigquery_infra["anomaly_detection"].dataset_id
  table_id   = "arima_evaluate_project_net_cost_forecast"

  description = "Output of the ml.arima_evaluate and ml.arima_coefficients functions for every project"
  schema      = file("schemas/arima_evaluate_project_net_cost_forecast.json")

  deletion_protection = var.deletion_protection

  labels = {
    environment = var.environment
    component   = "bigquery"
  }
}

# 6. Model Creation Runtime Staging Log (Required by train_arima_model.sql DML Truncate/Insert)
resource "google_bigquery_table" "project_create_model_net_cost" {
  project    = local.project_id
  dataset_id = module.bigquery_infra["anomaly_detection"].dataset_id
  table_id   = "project_create_model_net_cost"

  description = "Table for logging creation metadata for the project grain model"
  schema      = file("schemas/project_create_model_net_cost.json")

  deletion_protection = var.deletion_protection

  labels = {
    environment = var.environment
    component   = "bigquery"
  }
}
