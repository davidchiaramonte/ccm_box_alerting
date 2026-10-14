#######################################
# CLOUD RUN V2 SERVICE CONFIGURATIONS #
#######################################

# The core unified container compute engine for the alerting pipeline.
# It hosts both the BQ Remote Function endpoint (/) and the Pub/Sub Push consumer endpoint (/pubsub-email-alerts).
resource "google_cloud_run_v2_service" "anomaly_alert" {
  name     = "ccm-anomaly-alert-${var.environment}"
  project  = local.project_id
  location = var.region # Dynamically driven by var.region (us-central1)

  # Standard public networking secured via token and IAM connections
  ingress = "INGRESS_TRAFFIC_ALL" 

  template {
    # Enforces true HCL IMPLICIT dependency: Binds straight to SA resource output in iam.tf
    service_account = google_service_account.cloudrun.email

    containers {
      # [NEW ADVANCED AUTOMATION]: Dynamically construct the full Artifact Registry container path
      # Links directly to the repository created in artifact_registry.tf to make deployment truly "free"
      image = "${var.region}-docker.pkg.dev/${local.project_id}/${google_artifact_registry_repository.ccm_repo.repository_id}/${var.cloud_run_image_name}:${var.cloud_run_image_tag}"

      # Environment variables injected into the container for runtime SDK configurations
      env {
        name  = "PROJECT_ID"
        value = local.project_id
      }
      env {
        name  = "DATASET_ID"
        value = local.dataset_configs.anomaly_detection.dataset_id
      }
      env {
        name  = "PUBSUB_PROJECT_ID"
        value = local.project_id
      }
      env {
        name  = "PUBSUB_TOPIC_ID"
        value = google_pubsub_topic.anomalies.name # Local topic created in alerting.tf
      }
      env {
        name  = "CC_EMAILS"
        value = var.cc_emails
      }
      env {
        name  = "GEMINI_MODEL_NAME"
        value = var.gemini_model_name # Parameterized Gemini Model
      }

      # --- Re-instated SMTP Hardened Relays Injections ---
      env {
        name  = "SMTP_SERVER"
        value = var.smtp_server
      }
      env {
        name  = "SMTP_PORT"
        value = var.smtp_port
      }
      env {
        name  = "SMTP_USER"
        value = var.smtp_user # Injected from tfvars (Abstracted user mailbox)
      }
      # Passes the Secret ID name so the consumer code can access the App Password using Google Secret Manager SDK
      env {
        name  = "SMTP_SECRET_ID"
        value = google_secret_manager_secret.smtp_creds.secret_id
      }

      resources {
        cpu_idle = true
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }

    scaling {
      # Enforce maximum 1 instance to trap BigQuery speculative execution duplicate calls via global python dictionary cache
      max_instance_count = 1
    }
  }

  deletion_protection = false # Allow clean terraform destroy in dev

  depends_on = [
    null_resource.cloud_build_image
  ]
}

# Allow BigQuery Connection System SA to invoke this Cloud Run service.
# Required by BQ Remote Functions to execute serverless containers passwordless.
resource "google_cloud_run_v2_service_iam_member" "bq_connection_invoker" {
  project  = google_cloud_run_v2_service.anomaly_alert.project
  location = google_cloud_run_v2_service.anomaly_alert.location
  name     = google_cloud_run_v2_service.anomaly_alert.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_bigquery_connection.bigquery_cloudrun_connection.cloud_resource[0].service_account_id}"
}

# Allow Pub/Sub Subscriber Service Account to invoke this Cloud Run service.
# Required by Pub/Sub Push subscription to call /pubsub-email-alerts.
resource "google_cloud_run_v2_service_iam_member" "pubsub_invoker" {
  project  = google_cloud_run_v2_service.anomaly_alert.project
  location = google_cloud_run_v2_service.anomaly_alert.location
  name     = google_cloud_run_v2_service.anomaly_alert.name
  role     = "roles/run.invoker"
  member   = google_service_account.pubsub_subscriber.member
}
