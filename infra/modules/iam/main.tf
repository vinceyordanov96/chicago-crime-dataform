/* Iterate over the list of Objects in the service_account_list variable to create
service accounts and assign roles */

# Local variable to create pairs of service accounts and roles
locals {
    service_account_role_pairs = flatten([
        for sa_index, sa in var.iam_service_account_list : [
            for role in sa.roles : {
                sa_index = sa_index
                role     = role
            }
        ]
    ])
}


resource "google_service_account" "service_accounts" {
    count = length(var.iam_service_account_list)
    
    account_id   = var.iam_service_account_list[count.index].name
    display_name = var.iam_service_account_list[count.index].display_name
    project      = var.iam_project_id
    
}

# Use a flattened structure for role assignments using for_each instead of count
resource "google_project_iam_member" "service_account_roles" {
    for_each   = { for pair in local.service_account_role_pairs : "${pair.sa_index}-${pair.role}" => pair }
    project    = var.iam_project_id
    role       = each.value.role
    member     = "serviceAccount:${google_service_account.service_accounts[each.value.sa_index].email}"
    depends_on = [
        google_service_account.service_accounts
    ]
}
