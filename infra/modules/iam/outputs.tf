# Outputs
output "service_account_emails" {
    description = "Map of service account names to their emails"
    value = {
        for idx, sa in google_service_account.service_accounts : var.iam_service_account_list[idx].name => sa.email
    }
}
