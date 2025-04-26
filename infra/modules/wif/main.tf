# Specify the repository info
locals {
    github_username  = var.github_username    
    repo_name        = var.repo_name
    repository_id    = var.repository_id
}

# Create the WIF pool
resource "google_iam_workload_identity_pool" "github_actions_pool" {
	project                   = var.project_id
	workload_identity_pool_id = var.pool_id
	display_name              = var.pool_display_name
	description               = var.pool_description
}

# Create the WIF provider
resource "google_iam_workload_identity_pool_provider" "github_provider" {
	project                            = var.project_id
	display_name                       = var.provider_display_name
	workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions_pool.workload_identity_pool_id
	workload_identity_pool_provider_id = var.provider_id
	provider                           = google

	oidc {
		issuer_uri = "https://token.actions.githubusercontent.com"
	}

	attribute_mapping = {
		"google.subject"       = "assertion.sub"
		"attribute.actor"      = "assertion.actor"
		"attribute.aud"        = "assertion.aud"
		"attribute.repository" = "assertion.repository"
	}

	// Added this attribute_condition configuration argument
	attribute_condition = "assertion.repository == '${local.github_username}/${local.repo_name}'"
}

# Create the WIF binding needed for the service account that will be used by the GitHub Actions workflow.
resource "google_service_account_iam_binding" "allow_github" {

	service_account_id = "projects/${var.project_id}/serviceAccounts/${var.service_account}"
	role               = "roles/iam.workloadIdentityUser"

	members = [
		"principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions_pool.name}/attribute.repository/${local.github_username}/${local.repo_name}"
	]
}
