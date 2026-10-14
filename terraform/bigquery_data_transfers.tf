###################################################
# RAW BIGQUERY DATA TRANSFER SERVICE PROVISIONING #
###################################################

# [CRITICAL ENVIRONMENT WORKAROUND]: We convert this to raw resource blocks to
# bypass an API credential panic in child modules. We explicitly inject 
# `service_account_name = local.dataform_sa_email` so that the scheduled jobs 
# execute as a Service Account, bypassing manual user web consent roadblocks.

# 1. Scheduled Query: Retrains the ARIMA ML model monthly
resource "google_bigquery_data_transfer_config" "train_arima_model" {
  project                = local.project_id
  display_name           = "CCM Core - ARIMA Model Monthly Training"
  data_source_id         = "scheduled_query"
  schedule               = "2 of month 10:00" # Monthly rollout

  # Pass the Scheduler Service Account (has jobUser + dataEditor privileges) to execute the query
  service_account_name = google_service_account.scheduler.email

  params = {
    query = templatefile("${path.module}/sql/anomaly_detection/bqdt_train_arima_model.sql", {
      project_net_cost_forecast         = "${local.project_id}.${module.bigquery_infra["anomaly_detection"].dataset_id}.project_net_cost_forecast"
      vw_project_input_data_net_cost    = "${local.project_id}.${module.bigquery_infra["anomaly_detection"].dataset_id}.vw_project_input_data_net_cost"
      project_create_model_net_cost     = "${local.project_id}.${module.bigquery_infra["anomaly_detection"].dataset_id}.project_create_model_net_cost"
      anomaly_detection_bqml_model_info = "${local.project_id}.${module.bigquery_infra["anomaly_detection"].dataset_id}.anomaly_detection_bqml_model_info"
      dataset_id                        = "${local.project_id}.${module.bigquery_infra["anomaly_detection"].dataset_id}"
    })
  }

  depends_on = [
    google_bigquery_table.vw_project_input_data_net_cost,
    google_service_account_iam_member.bq_dts_agent_impersonation,
    google_project_iam_member.scheduler_roles,
    time_sleep.wait_for_iam # Ensure SAs are fully propagated in IAM before binding
  ]
}

resource "google_bigquery_data_transfer_config" "call_anomaly_alerting_function" {
  project                = local.project_id
  display_name           = "CCM Core - Daily Anomaly Alerting Function Trigger"
  data_source_id         = "scheduled_query"
  schedule               = "every day 04:00" # Active daily trigger

  service_account_name = google_service_account.scheduler.email

  params = {
    query = templatefile("${path.module}/sql/anomaly_detection/bqdt_call_anomaly_alerting_function.sql", {
      vw_unalerted_anomalies    = "${local.project_id}.${module.bigquery_infra["anomaly_detection"].dataset_id}.vw_unalerted_anomalies"
      sp_anomaly_alert_function = "${local.project_id}.${module.bigquery_infra["anomaly_detection"].dataset_id}.sp_anomaly_alert_function"
      project_owner_mapping     = "${local.project_id}.${module.bigquery_infra["anomaly_detection"].dataset_id}.project_owner_mapping"
    })
  }

  depends_on = [
    google_bigquery_table.vw_unalerted_anomalies,
    google_bigquery_routine.sp_anomaly_alert_function,
    google_bigquery_table.project_owner_mapping,
    google_service_account_iam_member.bq_dts_agent_impersonation,
    google_project_iam_member.scheduler_roles,
    time_sleep.wait_for_iam
  ]
}
