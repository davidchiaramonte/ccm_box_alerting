variable "dataset_id" {
  description = "Unique ID for the dataset being provisioned."
  type        = string
}

variable "dataset_name" {
  description = "Friendly name for the dataset being provisioned."
  type        = string
  default     = null
}

variable "description" {
  description = "Dataset description."
  type        = string
  default     = null
}

variable "location" {
  description = "The regional location for the dataset only US and EU are allowed in module"
  type        = string
  default     = "US"
}

variable "delete_contents_on_destroy" {
  description = "(Optional) If set to true, delete all the tables in the dataset when destroying the resource; otherwise, destroying the resource will fail if tables are present."
  type        = bool
  default     = null
}

variable "deletion_protection" {
  description = "Whether or not to allow deletion of tables and external tables defined by this module. Can be overriden by table-level deletion_protection configuration."
  type        = bool
  default     = true
}

variable "default_table_expiration_ms" {
  description = "TTL of tables using the dataset in MS"
  type        = number
  default     = null
}

variable "max_time_travel_hours" {
  description = "Defines the time travel window in hours"
  type        = number
  default     = null
}

variable "project_id" {
  description = "Project where the dataset and table are created"
  type        = string
}

variable "encryption_key" {
  description = "Default encryption key to apply to the dataset. Defaults to null (Google-managed)."
  type        = string
  default     = null
}

variable "dataset_labels" {
  description = "Key value pairs in a map for dataset labels"
  type        = map(string)
  default     = {}
}

variable "resource_tags" {
  description = "A map of resource tags to add to the dataset"
  type        = map(string)
  default     = {}
}

variable "storage_billing_model" {
  description = "Specifies the storage billing model for the dataset."
  type        = string
  default     = "PHYSICAL"
}

# Format: list(objects)
# domain: A domain to grant access to.
# group_by_email: An email address of a Google Group to grant access to.
# user_by_email:  An email address of a user to grant access to.
# special_group: A special group to grant access to.
variable "access" {
  description = "An array of objects that define dataset access for one or more entities."
  type        = any

  # At least one owner access is required.
  default = [{
    role          = "roles/bigquery.dataOwner"
    special_group = "projectOwners"
  }]
}

variable "tables" {
  description = "A list of objects which include table_id, table_name, schema, clustering, time_partitioning, range_partitioning, expiration_time and labels."
  default     = []
  type = list(object({
    table_id                 = string,
    description              = optional(string),
    table_name               = optional(string),
    schema                   = string,
    clustering               = optional(list(string)),
    require_partition_filter = optional(bool),
    time_partitioning = optional(object({
      expiration_ms = optional(string),
      field         = optional(string),
      type          = string,
    })),
    range_partitioning = optional(object({
      field = string,
      range = object({
        start    = string,
        end      = string,
        interval = string,
      }),
    })),
    expiration_time     = optional(string),
    deletion_protection = optional(bool),
    labels              = map(string),
  }))
}

variable "views" {
  description = "A list of objects which include view_id and view query"
  default     = []
  type = list(object({
    view_id        = string,
    description    = optional(string),
    query          = string,
    use_legacy_sql = bool,
    labels         = map(string),
    deletion_protection = optional(bool)
  }))
}

variable "materialized_views" {
  description = "A list of objects which includes view_id, view_query, clustering, time_partitioning, range_partitioning, expiration_time and labels"
  default     = []
  type = list(object({
    view_id             = string,
    description         = optional(string),
    query               = string,
    enable_refresh      = bool,
    refresh_interval_ms = string,
    schema              = optional(string),
    clustering          = optional(list(string)),
    time_partitioning = optional(object({
      expiration_ms            = optional(string),
      field                    = optional(string),
      type                     = optional(string),
      require_partition_filter = optional(bool),
    })),
    range_partitioning = optional(object({
      field = string,
      range = object({
        start    = string,
        end      = string,
        interval = string,
      }),
    })),
    expiration_time = optional(string),
    max_staleness   = optional(string),
    labels          = map(string),
    deletion_protection  = optional(bool),
  }))
}

variable "external_tables" {
  description = "A list of objects which include table_id, expiration_time, external_data_configuration, and labels."
  default     = []
  type = list(object({
    table_id              = string,
    description           = optional(string),
    autodetect            = bool,
    compression           = optional(string),
    ignore_unknown_values = bool,
    max_bad_records       = optional(number),
    schema                = optional(string),
    source_format         = string,
    source_uris           = list(string),
    csv_options = optional(object({
      quote                 = string,
      allow_jagged_rows     = optional(bool),
      allow_quoted_newlines = optional(bool),
      encoding              = optional(string),
      field_delimiter       = optional(string),
      skip_leading_rows     = optional(number),
    })),
    google_sheets_options = optional(object({
      range             = optional(string),
      skip_leading_rows = optional(number),
    })),
    hive_partitioning_options = optional(object({
      mode              = optional(string),
      source_uri_prefix = optional(string),
    })),
    expiration_time     = optional(string),
    max_staleness       = optional(string),
    deletion_protection = optional(bool),
    labels              = optional(map(string)),
  }))
}


variable "routines" {
  description = "A list of objects which include routine_id, routine_type, routine_language, definition_body, return_type, routine_description and arguments."
  default     = []
  type = list(object({
    routine_id        = string,
    routine_type      = string,
    language          = optional(string),
    definition_body   = optional(string),
    return_type       = optional(string),
    return_table_type = optional(string),
    description       = optional(string),
    arguments = optional(list(object({
      name            = optional(string),
      data_type       = optional(string),
      argument_kind   = optional(string),
      mode            = optional(string),
    }))),
    remote_function_options = optional(list(object({
      endpoint        = optional(string),
      connection      = optional(string)
    })))
  }))
}

variable "data_transfer_jobs" {
  description = "A list of objects which include display_name, data_source_id, destination_dataset_id, schedule, and params."
  default     = []
  type = list(object({
    job_name = string
    display_name           = string,
    data_source_id         = string,
    schedule = optional(string),
    params = map(string),
    null_dataset_id = optional(bool)
    disable_auto_scheduling = optional(bool)
  }))
}