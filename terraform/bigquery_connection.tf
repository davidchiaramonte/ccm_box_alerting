################################
# BIGQUERY CONNECTION RESOURCE #
################################

# Connection used by BigQuery Remote Functions to authenticate and call Cloud Run
resource "google_bigquery_connection" "bigquery_cloudrun_connection" {
  project       = local.project_id
  location      = var.location # Must match the BigQuery dataset location (e.g., 'US' multi-region)
  connection_id = "ccm-bigquery-cloudrun-connection-${var.environment}"
  cloud_resource {} # Defines it as a cloud resource connection (Remote Functions/BQML Vertex)

  depends_on = [
    google_project_service.services
  ]
}

resource "google_bigquery_connection_iam_member" "dataform_connection_user" {
  project       = google_bigquery_connection.bigquery_cloudrun_connection.project
  location      = google_bigquery_connection.bigquery_cloudrun_connection.location
  connection_id = google_bigquery_connection.bigquery_cloudrun_connection.connection_id
  role          = "roles/bigquery.connectionUser"
  member        = "serviceAccount:${local.dataform_sa_email}"
}
