variable "dataform_project_id" {
    description = "The ID of the project"
    type        = string
}
variable "dataform_repo_name" {
    description = "The name of the repository"
    type        = string
}
variable "dataform_service_account" {
    description = "The service account that the Dataform project will use to execute operations."
    type        = string
}
variable "dataform_orchestration_sa" {
    description = "The service account that the Dataform project will use to execute orchestration operations."
    type        = string
}
variable "dataform_remote_repo_name" {
    description = "The name of the repository"
    type        = string
}
variable "dataform_github_repo_url" {
    description = "URL of the GitHub repository"
    type        = string
}
variable "dataform_github_default_branch" {
    description = "Default branch of the GitHub repository"
    type        = string
}
variable "dataform_github_token_secret_version" {
    description = "Secret version resource name containing GitHub token"
    type        = string
}
variable "dataform_workspace_name" {
    description = "Secret version resource name containing GitHub token"
    type        = string
    default     = "prod"
}
variable "dataform_region" {
    description = "Region of the Dataform project"
    type        = string
    default     = "europe-west1"
}
variable "dataform_default_schema" {
	description = "The default schema for the Dataform project"
	type        = string
	default     = "transformed"
} 
variable "dataform_github_token" {
    description = "GitHub token for Dataform project (utilized in API call)"
    type        = string
    sensitive   = true
}
variable "dataform_npmrc_secret_version" {
    description = "The Secret Manager Secret Version pointing to the token needed for NPM package installation"
    type        = string
}
variable "dataform_repo_deletion_policy" {
    description = "The deletion policy for the Dataform repository"
    type        = string
    default     = "FORCE"
}
