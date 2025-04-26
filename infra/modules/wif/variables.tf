/* WIF Variables */
variable "project_id" {
    description = "The ID of the project"
    type        = string
}
variable "github_username" {
    description = "The GitHub username"
    type        = string
}
variable "repo_name" {
    description = "The name of the repository"
    type        = string
}
variable "repository_id" {
    description = "The ID of the repository"
    type        = string
}
variable "pool_id" {
    description = "The ID of the WIF pool"
    type        = string
}
variable "pool_display_name" {
    description = "The display name of the WIF pool"
    type        = string
}
variable "pool_description" {
    description = "The description of the WIF pool"
    type        = string
}
variable "provider_id" {
    description = "The ID of the WIF provider"
    type        = string
}
variable "provider_display_name" {
    description = "The display name of the WIF provider"
    type        = string
}
variable "provider_description" {
    description = "The description of the WIF provider"
    type        = string
}
variable "service_account" {
    description = "The google provided service agent for building and deploying alerts cloud function."
    type        = string
}
