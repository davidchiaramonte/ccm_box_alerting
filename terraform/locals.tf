###############
# CORE LOCALS #
###############

locals {
  project_id     = var.project_id
  project_number = data.google_project.project.number

  # Service Account emails (constructed to match the resource names that will be created in iam.tf)
  dataform_sa_email   = "gsvc-ccm-toolkit${var.instance_id == "" ? "" : "-${replace(var.instance_id, "_", "-")}"}@${var.project_id}.iam.gserviceaccount.com"
  cloudrun_sa_email   = "gsvc-ccm-cloudrun-${var.environment}@${var.project_id}.iam.gserviceaccount.com"
  datastudio_sa_email = "gsvc-ccm-datastudio-${var.environment}@${var.project_id}.iam.gserviceaccount.com"
  pubsub_sub_sa_email = "gsvc-ccm-pubsub-sub-${var.environment}@${var.project_id}.iam.gserviceaccount.com"

  # BigQuery Dataset naming configurations to be used across BQ tf files
  dataset_configs = {
    anomaly_detection = {
      dataset_id   = "anomaly_detection"
      description  = "The anomaly detection dataset for CCM Toolkit"
    }
  }

  # Reference the BQ dataset created by the Dataform module
  gcp_billing_dataset_id = "ccm_toolkit${var.instance_id == "" ? "" : "_${var.instance_id}"}"
}

data "google_project" "project" {
  project_id = var.project_id
}
