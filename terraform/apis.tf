##########################
# GCP API SERVICE ACTIVATION #
##########################

locals {
  gcp_services = [
    "serviceusage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "bigquery.googleapis.com",
    "bigqueryconnection.googleapis.com",
    "bigquerydatatransfer.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "run.googleapis.com",
    "pubsub.googleapis.com",
    "aiplatform.googleapis.com",
    "dataform.googleapis.com",
    "cloudbuild.googleapis.com"
  ]
}

resource "google_project_service" "services" {
  for_each = toset(local.gcp_services)
  project  = var.project_id
  service  = each.value

  # Keep the service active on terraform destroy to protect shared resources/data
  disable_on_destroy = false
}
