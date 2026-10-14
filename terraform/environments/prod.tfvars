###################################
# PRODUCTION ENVIRONMENT VARIABLES#
###################################

environment            = "pd"  # pd for Production
deletion_protection    = true  # CRITICAL: Always enabled in Prod to prevent accidental BigQuery data loss
enable_dataform_repo   = true  # Provisions the production Dataform environment

# Core email routing configurations for Production
cc_emails              = "finops-production-alerts@yourdomain.com"  # Production Distribution List Group
smtp_user              = "noreply-finops@yourdomain.com"            # Dedicated production sender mailbox

# Cross-Project Data Sources (Production Raw Billing Export)
raw_billing_project_id = "your-production-billing-export-project-id"
raw_billing_dataset_name = "your_production_raw_billing_dataset"
raw_billing_table_name   = "gcp_billing_export_v1_YYYYYY_YYYYYY_YYYYYY"

# ============================================================================
# [PLAN B]: PRODUCTION GIT REMOTE MIRROR CONFIGURATIONS (SSH)
# ============================================================================
# The production repo should point to your main/production branch mirror
dataform_git_remote_url      = "git@github.com:your-org/ccm-toolkit.git"
dataform_git_default_branch  = "main"

# Public host key of your Git provider (e.g., github.com)
dataform_git_host_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"
