###########################################
# ALERTING & EVENT DRIVEN INFRASTRUCTURE  #
###########################################

# 1. Pub/Sub Topic for Cost Anomalies
# Acts as the central fan-out queue for all cost anomaly overrun events
resource "google_pubsub_topic" "anomalies" {
  name    = "ccm-cost-anomalies-${var.environment}"
  project = local.project_id

  labels = {
    environment = var.environment
    component   = "alerting"
  }
}

# 2. Pub/Sub Push Subscription to Unified Cloud Run Endpoint
# Secured via OIDC token authentication using dedicated subscriber Service Account
resource "google_pubsub_subscription" "cloudrun_push" {
  name    = "ccm-cost-anomalies-push-${var.environment}"
  project = local.project_id
  topic   = google_pubsub_topic.anomalies.name

  # Extended ack deadline to allow container and AI procedures sufficient processing headroom
  ack_deadline_seconds = 60

  push_config {
    # References the Cloud Run service defined in cloud_run.tf, targeting the /pubsub-email-alerts subscriber route
    push_endpoint = "${google_cloud_run_v2_service.anomaly_alert.uri}/pubsub-email-alerts"

    oidc_token {
      # Enforces IMPLICIT dependency: Binds straight to the SA resource output created in iam.tf
      service_account_email = google_service_account.pubsub_subscriber.email
      audience              = google_cloud_run_v2_service.anomaly_alert.uri
    }
  }

  depends_on = [
    google_pubsub_topic.anomalies
  ]
}

# 3. Secret Manager Container for Gmail SMTP Credentials
# Re-instated: Stores the sensitive App Password needed to execute standard unblocked SMTP relays via Gmail
resource "google_secret_manager_secret" "smtp_creds" {
  secret_id = "ccm-alert-smtp-credentials-${var.environment}"
  project   = local.project_id

  labels = {
    environment = var.environment
    component   = "alerting"
  }

  replication {
    auto {}
  }
}

# 4. Placeholder Secret Version (Commented out so Terraform does not overwrite the existing active App Password version in Secret Manager)
# resource "google_secret_manager_secret_version" "smtp_creds_placeholder" {
#   secret      = google_secret_manager_secret.smtp_creds.id
#   secret_data = "PLACEHOLDER_ENTER_GMAIL_APP_PASSWORD_IN_CONSOLE"
#
#   lifecycle {
#     ignore_changes = [
#       secret_data
#     ]
#   }
# }
