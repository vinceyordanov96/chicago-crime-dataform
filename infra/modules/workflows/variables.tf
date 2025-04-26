variable "workflow_project_id" {
    description = "The ID of the project"
    type        = string
}
variable "workflow_name" {
    description = "Name of the workflow instance"
    type        = string
}
variable "workflow_description" {
    description = "Description of the workflow instance"
    type        = string
}
variable "workflow_region" {
    description = "Region of the workflow instance"
    type        = string
}
variable "workflow_service_account" {
    description = "Service account which the workflow will use to invoke the cloud function"
    type        = string
}
