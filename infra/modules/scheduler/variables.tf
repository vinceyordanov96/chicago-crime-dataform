# -- Define the necessary variables to be used for creating Pub/Sub and BQ resources -- ##
variable "scheduler_project_id" {
    description = "Project ID"
    type        = string
}
variable "scheduler_region" {
    description = "Default region for Cloud Function resources"
    type        = string
}
variable "scheduler_zone" {
    description = "Zone of the GCP project"
    type        = string
}

/* Cloud Scheduler Variables */
variable "scheduler_name" {
    description = "Name of the scheduler job"
    type        = string
}
variable "scheduler_description" {
    description = "Description of the scheduler job"
    type        = string
}
variable "scheduler_frequency" {
    description = "Schedule of the scheduler job"
    type        = string
}
variable "scheduler_time_zone" {
    description = "Time zone of the scheduler job"
    type        = string
    default     = "Europe/Stockholm"
}
variable "scheduler_http_method" {
    description = "HTTP method of the scheduler job"
    type        = string
    default     = "POST"
}
variable "scheduler_oauth_scope" {
    description = "OAuth scope of the scheduler job"
    type        = string
}
variable "scheduler_service_account" {
    description = "Service account which the scheduler will use to invoke the cloud workflow instance"
    type        = string
}
variable "scheduler_target_audience" {
    description = "Audience of the scheduler job"
    type        = string
}
