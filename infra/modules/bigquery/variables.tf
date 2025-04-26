/* BigQuery Variables */
variable "bq_project_id" {
    description = "BigQuery project ID"
    type        = string
}
variable "bq_region" {
    description = "BigQuery region"
    type        = string
}
variable "bq_delete_contents_on_destroy" {
    description = "Delete contents on destroy"
    type        = bool
}
variable "bq_data_source_id" {
    description = "Data source ID"
    type        = string
}
variable "bq_schedule_query_frequency" {
    description = "Frequency of the scheduled query"
    type        = string
}
variable "bq_deletion_protection" {
    description = "Deletion protection"
    type        = bool
}
variable "bq_raw_dataset_id" {
    description = "BigQuery dataset ID for raw data"
    type        = string
}
variable "bq_staging_dataset_id" {
    description = "BigQuery dataset ID for staging data"
    type        = string
}
variable "bq_transformed_dataset_id" {
    description = "BigQuery dataset ID for transformed data"
    type        = string
}
variable "bq_lookup_dataset_id" {
    description = "BigQuery dataset ID for transformed data"
    type        = string
}
variable "bq_table_id_raw" {
    description = "BigQuery table IDs"
    type        = string 
}
variable "bq_table_id_lookup" {
    description = "BigQuery table IDs"
    type        = string 
}
variable "bq_table_id_transformed" {
    description = "BigQuery table IDs"
    type        = string 
}
variable "bq_partition_type" {
    description = "BigQuery partition type"
    type        = string
    default     = "DAY"
}
variable "bq_partition_field" {
    description = "BigQuery partition field for raw table"
    type        = string
    default     = "date"
}
variable "bq_partition_field_transformed" {
    description = "BigQuery partition field for transformed table"
    type        = string
    default     = "event_date"
}
variable "bq_partition_expiration_ms" {
    description = "BigQuery partition expiration in milliseconds"
    type        = number
    default     = null
}
