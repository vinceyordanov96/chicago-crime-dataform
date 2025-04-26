/* GCF Gen2 Variables */
variable "gcf_project_id" {
    description = "The ID of the project"
    type        = string
}
variable "gcf_service_account" {
    description = "The service account which the cloud function will use to carry out operations."
    type        = string
}
variable "gcf_memory" {
    description = "Memory allocated to the cloud function"
    type        = string
}
variable "gcf_runtime" {
    description = "The Python runtime environment for the cloud function"
    type        = string
}
variable "gcf_timeout" {
    description = "Memory allocated to the cloud function"
    type        = number
}
variable "gcf_name" {
    description = "Name of the cloud function"
    type        = string
}
variable "gcf_description" {
    description = "Description of the cloud function"
    type        = string
}
variable "gcf_ingress_settings" {
    description = "Ingress settings of the cloud function"
    type        = string
}
variable "gcf_entry_point" {
    description = "Entry point of the cloud function"
    type        = string
}
variable "gcf_cpu" {
    description = "CPU allocated to the cloud function"
    type        = string
}
variable "gcf_region" {
    description = "Region of the cloud function"
    type        = string
}
variable "gcf_environment" {
    description = "Environment of the cloud function"
    type        = string
}
variable "gcf_invoker_service_account_name" {
    description = "Service account that will invoke the cloud function"
    type        = string
}
variable "gcf_invoker_service_account_role" {
    description = "List of roles for the invoker service account"
    type        = string
}
variable "gcf_ingestion_start_date" {
    description = "Start date for the ingestion process"
    type        = string
    default     = "2001-01-01"
}
variable "gcf_downstream_workflow_id" {
    description = "ID of the downstream workflow"
    type        = string
}
variable "gcf_socrata_app_token" {
    description = "App token to use the Socrata API for the chicago crime data portal"
    type        = string
}

/* GCS Variables */
variable "gcs_bucket_name" {
    description = "Name of the GCS bucket"
    type        = string
}
variable "gcs_bucket_location" {
    description = "Location of the GCS bucket"
    type        = string
}
variable "gcs_bucket_storage_class" {
    description = "Storage class of the GCS bucket"
    type        = string
}
