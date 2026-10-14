###################################
# NON-PRODUCTION ENVIRONMENT VARS #
###################################

project_id               = "dsc-sandbox-474521"
environment              = "np"
instance_id              = "box_demo"
region                   = "us-central1"
location                 = "US"
deletion_protection      = false
enable_dataform_repo     = false
gemini_model_name        = "gemini-3.8-flash"

# Email / SMTP routing configurations
cc_emails                = ""
smtp_server              = "smtp.gmail.com"
smtp_port                = 587
smtp_user                = "admin@dchiaramonte.altostrat.com"

# Raw Billing Data Sources
raw_billing_project_id   = "dsc-sandbox-474521"
raw_billing_dataset_name = "billing_exports"
raw_billing_table_name   = "gcp_billing_export_v1_018F4B_B3B47C_3ECC2B"
