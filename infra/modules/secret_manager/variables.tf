variable "secret_manager_project_id" {
    description = "GCP Project ID of the project where the secret is to be stored"
    type        = string
}
variable "secret_manager_github_token" {
    description = "GitHub token to store in the secret manager"
    type        = string
    sensitive   = true
}
variable "secret_manager_socrata_app_token" {
    description = "Socrata token to store in the secret manager"
    type        = string
    sensitive   = true
}
variable "secret_manager_secret_name" {
    description = "Name of the secret"
    type        = string
}
variable "secret_manager_socrata_app_token_name" {
    description = "Name of the Socrata token secret"
    type        = string  
}
