############################################
# CONSOLIDATED IAM & SERVICE ACCOUNTS SETUP #
############################################

# ------------------------------------------------------------------
# 1. Service Account Creations
# ------------------------------------------------------------------

resource "google_service_account" "cloudrun" {
  account_id   = "gsvc-ccm-cloudrun-${var.environment}"
  display_name = "CCM Cloud Run Alerting Service Account (${var.environment})"
  description  = "Service account used by Cloud Run anomaly alerting app to query BQ, call Vertex AI, and publish to Pub/Sub"
  project      = local.project_id
}

resource "google_service_account" "datastudio" {
  account_id   = "gsvc-ccm-datastudio-${var.environment}"
  display_name = "CCM Data Studio Service Account (${var.environment})"
  description  = "Service account used by Data Studio for read-only access to FinOps dashboards"
  project      = local.project_id
}

resource "google_service_account" "pubsub_subscriber" {
  account_id   = "gsvc-ccm-pubsub-sub-${var.environment}"
  display_name = "CCM Pub/Sub Subscriber Service Account (${var.environment})"
  description  = "Service account used by Pub/Sub Push subscription to authenticate requests against Cloud Run"
  project      = local.project_id
}

resource "google_service_account" "scheduler" {
  account_id   = "gsvc-ccm-scheduler-${var.environment}"
  display_name = "CCM Alerting Scheduler Service Account (${var.environment})"
  description  = "Service account used by BigQuery Scheduled Queries to run ARIMA training and trigger anomaly alerts"
  project      = local.project_id
}

# ------------------------------------------------------------------
# 2. Project-Level IAM Role Memberships (google_project_iam_member)
# ------------------------------------------------------------------

# Cloud Run Alerting SA Roles
resource "google_project_iam_member" "cloudrun_roles" {
  for_each = toset([
    "roles/bigquery.dataEditor", # Needs to write logs to cost_anomaly_alert_log and query views
    "roles/bigquery.jobUser",
    "roles/aiplatform.user",       # Vertex AI access for Gemini
    "roles/pubsub.publisher",      # Needs to publish to local Pub/Sub topic
    "roles/secretmanager.secretAccessor" # Re-instated: Needed to resolve SMTP Gmail App password at runtime
  ])
  project = local.project_id
  role    = each.value
  member  = google_service_account.cloudrun.member
}

# Data Studio SA Roles (Simplified Read-Only access)
resource "google_project_iam_member" "datastudio_roles" {
  for_each = toset([
    "roles/bigquery.dataViewer",
    "roles/bigquery.jobUser"
  ])
  project = local.project_id
  role    = each.value
  member  = google_service_account.datastudio.member
}

# Scheduler SA Roles
resource "google_project_iam_member" "scheduler_roles" {
  for_each = toset([
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
    "roles/bigquery.connectionUser"
  ])
  project = local.project_id
  role    = each.value
  member  = google_service_account.scheduler.member
}

# ------------------------------------------------------------------
# 3. Service Account Specific IAM Permissions (Impersonation)
# ------------------------------------------------------------------

# ------------------------------------------------------------------

# Ensure Pub/Sub and BigQuery Data Transfer Service Agent identities exist before binding
resource "google_project_service_identity" "pubsub_agent" {
  provider = google-beta
  project  = local.project_id
  service  = "pubsub.googleapis.com"

  depends_on = [google_project_service.services]
}

resource "google_project_service_identity" "bq_dts_agent" {
  provider = google-beta
  project  = local.project_id
  service  = "bigquerydatatransfer.googleapis.com"

  depends_on = [google_project_service.services]
}

# Grant Pub/Sub Service Agent access to impersonate the Pub/Sub Subscriber Service Account
# Required for Pub/Sub to mint OIDC tokens for push subscriptions
resource "google_service_account_iam_member" "pubsub_agent_impersonation" {
  service_account_id = google_service_account.pubsub_subscriber.id
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_project_service_identity.pubsub_agent.email}"
}

# Grant BigQuery DTS Service Agent access to impersonate the Scheduler Service Account
# Required for scheduled queries to run as a Service Account
resource "google_service_account_iam_member" "bq_dts_agent_impersonation" {
  service_account_id = google_service_account.scheduler.id
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_project_service_identity.bq_dts_agent.email}"
}

# ------------------------------------------------------------------
# 4. External Project Data Access Permissions
# ------------------------------------------------------------------

# ------------------------------------------------------------------
# 5. [ADVANCED AUTOMATION] IAM Propagation Wait & Cloud Build Fixes
# ------------------------------------------------------------------

# Resolves Dataform Gaia 404 Race Condition:
# Forces a 30-second pause after SA creation before child modules try to bind their Gaia IDs
resource "time_sleep" "wait_for_iam" {
  create_duration = "30s"

  depends_on = [
    google_service_account.cloudrun,
    google_service_account.datastudio,
    google_service_account.pubsub_subscriber,
    google_service_account.scheduler
  ]
}

# Resolves Cloud Build 403 Storage Denial:
# Cloud Build uses the default Compute SA to extract code source tarballs during 'local-exec'.
# We dynamically construct and grant it read-only objectViewer access to unblock builds.
resource "google_project_iam_member" "compute_sa_storage_read" {
  project = local.project_id
  role    = "roles/storage.objectViewer" 
  member  = "serviceAccount:${local.project_number}-compute@developer.gserviceaccount.com" 
}

# Resolves Cloud Build Logging Denial:
# Grant default Compute SA access to write logs to Cloud Logging during builds.
resource "google_project_iam_member" "compute_sa_logging_write" {
  project = local.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${local.project_number}-compute@developer.gserviceaccount.com"
}


