########################################
# ARTIFACT REGISTRY DOCKER REPOSITORY  #
########################################

# Provisions the native Google Artifact Registry repository to host our anomaly alerting docker images.
resource "google_artifact_registry_repository" "ccm_repo" {
  provider = google-beta

  project       = local.project_id
  location      = var.region # Deployed regionally in us-central1 to serve Cloud Run with low latency
  repository_id = var.gar_repository_name
  description   = "Docker Artifact Registry Repository for CCM Toolkit Alerting Images"
  format        = "DOCKER"

  labels = {
    environment = var.environment
    component   = "compute"
  }

  depends_on = [
    google_project_service.services
  ]
}

# ============================================================================
# [ADVANCED BOOTSTRAP AUTOMATION]: GOOGLE CLOUD BUILD CONTAINER ROLLOUT
# ============================================================================
# This resource completely eliminates the 3-step manual bootstrapping roadblock!
# It automatically runs a serverless 'gcloud builds submit' push right after the
# registry is provisioned, and completely BEFORE Cloud Run is deployed.
#
# [CONTINUOUS DELIVERY]: It tracks MD5 file hashes. If you edit your Python code,
# Terraform will automatically detect the code diff on next plan/apply, trigger
# a serverless compilation, and roll out the container upgrade for you "for free".
resource "null_resource" "cloud_build_image" {
  
  # Tracks changes. If any value here alters, HCL forces the local-exec re-run
  triggers = {
    main_md5        = filemd5("${path.module}/../app/main.py")
    email_alert_md5 = filemd5("${path.module}/../app/email_alert.py")
    dispatcher_md5  = filemd5("${path.module}/../app/smtp_dispatcher.py") # Added to track dispatcher edits
    req_md5         = filemd5("${path.module}/../app/requirements.txt")
    dockerfile_md5  = filemd5("${path.module}/../Dockerfile")
    
    repo_id    = google_artifact_registry_repository.ccm_repo.repository_id
    image_name = var.cloud_run_image_name
    image_tag  = var.cloud_run_image_tag
  }

  provisioner "local-exec" {
    # Invokes serverless Google Cloud Build from your Cloudtop terminal context
    # Compiles from the root folder module parent, picking up the Dockerfile and app/ folder
    command = "/usr/bin/gcloud builds submit --project=${local.project_id} --tag=${var.region}-docker.pkg.dev/${local.project_id}/${google_artifact_registry_repository.ccm_repo.repository_id}/${var.cloud_run_image_name}:${var.cloud_run_image_tag} ${path.module}/.."
  }

  depends_on = [
    google_artifact_registry_repository.ccm_repo,
    google_artifact_registry_repository_iam_member.compute_sa_writer,
    google_project_iam_member.compute_sa_storage_read,
    google_project_iam_member.compute_sa_logging_write
  ]
}

# Grant Compute Engine default Service Account access to write to our repository.
# Required because Cloud Build executes builds using the Compute Engine SA in this environment.
resource "google_artifact_registry_repository_iam_member" "compute_sa_writer" {
  provider   = google-beta
  project    = local.project_id
  location   = google_artifact_registry_repository.ccm_repo.location
  repository = google_artifact_registry_repository.ccm_repo.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${local.project_number}-compute@developer.gserviceaccount.com"
}
