variable "github_branch_default" {
    description = "The default branch of the GitHub repository (dev or prod)"
    type        = string
}
variable "github_remote_repo_name" {
    description = "The name of the repository where Dataform project files are stored"
    type        = string
}
variable "github_remote_repo_description" {
    description = "The description of the repository where Dataform project files are stored"
    type        = string
}
variable "github_remote_repo_visibility" {
    description = "The visibility of the repository where Dataform project files are stored"
    type        = string
}
variable "github_remote_repo_init_file" {
    description = "The name of the file which is uploaded to initialize the Dataform configuraiton"
    type        = string
}
variable "github_remote_dataform_dir" {
    description = "The directory where Dataform project files are stored"
    type        = string
    default    = "../../../dataform"
}
variable "github_token" {
    description = "GitHub Personal Access Token"
    type        = string
    sensitive   = true
}
variable "github_create_resources" {
    description = "Whether to create GitHub resources. Should be true only for one environment."
    type        = bool
}
variable "github_environment" {
    description = "The environment to create GitHub resources for"
    type        = string
}
