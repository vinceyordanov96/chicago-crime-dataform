/* IAM Variables */
variable "iam_project_id" {
    description = "The ID of the project"
    type        = string
}

variable "iam_service_account_list" {
    description = "List of service account details"
    type        = list(object({
        name         = string
        display_name = string
        description  = string
        roles        = list(string)
    }))
}
