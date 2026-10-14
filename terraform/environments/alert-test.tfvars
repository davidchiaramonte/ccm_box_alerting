###################################
# NON-PRODUCTION ENVIRONMENT VARS #
###################################

project_id             = "test-ccm-toolkit-alert"
environment            = "at"
deletion_protection    = false # Enabled false for development agility (allows destroy)
enable_dataform_repo   = true  # Flipped to true by default to automate repository bootstrapping natively

# Core email routing overrides for testing (Crutchfielda domain contexts)
cc_emails              = "finops-alert-response-team@crutchfielda.altostrat.com" # Distribution list Group
smtp_user              = "noreply@crutchfielda.altostrat.com"                     # Dedicated alert sender mailbox

# Cross-Project Data Sources
raw_billing_project_id = "gcp-billing-crutchfielda"
raw_billing_dataset_name = "gcp_billing"
raw_billing_table_name   = "gcp_billing_export_v1_01B9FC_E7CAF7_A48E6B"

# ============================================================================
# [PLAN B]: USER CONFIRMED GIT REMOTE MIRROR CONFIGURATIONS (SSH)
# ============================================================================
dataform_git_remote_url      = "git@github.com:ajcrutch/ccm-toolkit-dataform-remote.git"
dataform_git_default_branch  = "toolkit-alert"

# Verbatim confirmed github.com public host key to pass strict ActAs verification checks
dataform_git_host_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"

dataform_workspace_name      = "ccm-toolkit-alert"
