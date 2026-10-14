################################
# CORE VARIABLES WITH DEFAULTS #
################################

variable "project_id" {
  description = "The target GCP Project ID where resources are provisioned"
  type        = string
  default     = "ccm-toolkit" # Generic project target name identifier
}

variable "environment" {
  description = "The environment suffix (e.g., np for non-prod, pd for prod)"
  type        = string
}

variable "region" {
  description = "The primary region for compute and regional resources (Compute, Pub/Sub, Artifacts)"
  type        = string
  default     = "us-central1"
}

variable "location" {
  description = "The location for multi-regional resources (BigQuery datasets, GCS buckets)"
  type        = string
  default     = "US"
}

variable "deletion_protection" {
  description = "Enable/Disable deletion protection for BigQuery datasets and tables"
  type        = bool
  default     = true
}

variable "enable_dataform_repo" {
  description = "Conditional flag to enable/disable the creation of the GCP Dataform Repository. NOTE: Defaults to true in nonprod.tfvars. Our module supports local-only repos (no git remote URL required), but blank project first-applies require a targeted bootstrap apply loop due to BigQuery source table validation dependencies (see User Guide section 5)."
  type        = bool
  default     = false
}

variable "gemini_model_name" {
  description = "The Vertex AI Gemini model name for cost recommendations (fully parameterized)"
  type        = string
  default     = "gemini-3.8-flash"
}

variable "cc_emails" {
  description = "Comma-separated list of default email recipients to be CC'd on all alerts"
  type        = string
  default     = ""
}

variable "time_zone" {
  description = "The time zone for setting Dataform release and workflow cron schedules"
  type        = string
  default     = "America/Los_Angeles"
}

variable "raw_billing_project_id" {
  description = "The external GCP Project ID where the raw billing export table is hosted"
  type        = string
  default     = "change-me-external-billing-project" # Abstracted generic placeholder
}

variable "raw_billing_dataset_name" {
  description = "The external BigQuery dataset name containing raw billing exports"
  type        = string
}

variable "raw_billing_table_name" {
  description = "The external BigQuery table name containing raw billing exports"
  type        = string
}

#############################################
# ARTIFACT REGISTRY & CLOUD RUN IMAGE VARS   #
#############################################

variable "gar_repository_name" {
  description = "The repository ID for the Google Artifact Registry Docker registry"
  type        = string
  default     = "ccm-gar-repository"
}

variable "cloud_run_image_name" {
  description = "The container image name for the anomaly alerting application"
  type        = string
  default     = "anomaly-alert"
}

variable "cloud_run_image_tag" {
  description = "The container image tag version for deployment"
  type        = string
  default     = "latest"
}

#############################################
# HARDENED SMTP CONFIGURATIONS VARIABLES    #
#############################################

# Best Practice: SMTP relay variables are fully abstracted.
# Defaults are explicitly documented as chosen due to standard unblocked port compliance in GCP.

variable "smtp_server" {
  description = "The SMTP server address. Default chosen as standard Gmail relay supported in GCP."
  type        = string
  default     = "smtp.gmail.com"
}

variable "smtp_port" {
  description = "The secure SMTP TLS port. Default 587 is fully open and standard for encrypted relays in GCP."
  type        = number
  default     = 587
}

variable "smtp_user" {
  description = "The authenticated email account username sending the alerts (e.g. alert-sender@company.com)"
  type        = string
  default     = "change-me-smtp-user-email@yourdomain.com" # Abstracted generic placeholder
}

#############################################
# PLAN B: DATAFORM GIT REMOTE MIRROR VARS   #
#############################################

variable "dataform_git_remote_url" {
  description = "The Git remote repository URL (e.g., git@github.com:user/repo.git). Required when enable_dataform_repo is true."
  type        = string
  default     = "" 
}

variable "dataform_git_default_branch" {
  description = "The target branch for the Git remote repository mirror"
  type        = string
  default     = "main"
}

variable "dataform_git_host_public_key" {
  description = "Optional: The public SSH host key string for your Git provider to prevent man-in-the-middle attacks."
  type        = string
  default     = ""
}

variable "dataform_workspace_name" {
  description = "The developer workspace branch name to provision natively in the Dataform repository"
  type        = string
  default     = "ccm-toolkit-oss-for-alert"
}

################################
# SENSITIVE/CREDENTIAL VARIABLES #
################################

variable "GIT_DATAFORM_SSH_PRIVATE_KEY" {
  description = "Optional: Github/Git private SSH key for Dataform remote repository (Sensitive)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "REPO_PUBLIC_SSH_KEY" {
  description = "Optional: Public SSH Key associated with the Git remote repository (Sensitive)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "instance_id" {
  description = "The instance ID suffix for the Dataform service account and dataset (must match the Dataform deployment)"
  type        = string
  default     = ""
}
