################################
# BIGQUERY MODULE INTEGRATION  #
################################

# The master BigQuery orchestration module call.
# It loops through all datasets defined in locals.tf and provisions their child tables, views, and routines.
module "bigquery_infra" {
  source = "./modules/gcp_bigquery"

  for_each = local.dataset_configs

  dataset_id    = each.value.dataset_id
  dataset_name  = each.value.dataset_id
  description   = each.value.description
  location      = var.location # Multi-region 'US'
  project_id    = local.project_id
  access        = lookup(each.value, "access", []) # Project SAs are granted roles globally via iam.tf

  # Wire up lookups to locals defined in bigquery_views.tf, bigquery_routines.tf, etc.
  views              = lookup(local.bigquery_view_config, each.key, [])


  dataset_labels = {
    environment = var.environment
    component   = "bigquery"
  }
}


