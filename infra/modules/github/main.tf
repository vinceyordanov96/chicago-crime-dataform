/** 
 * This is the GitHub Terraform Configuration
 * for the Chicago Crime Dataform project. Note that
 * this is only used for the dev environment. This is 
 * because both the dev and prod environments use the
 * same GitHub repository, with prod pointing to the
 * main branch (created by default). 
 */


# This needs to be here to force a match between provider
# versions, otherwise Terraform defaults to using an 
# outdated source (i.e., hashicorp/github) and this leads
# to issues when trying to manage GitHub resources. 
terraform {
    required_providers {
        github = {
        source  = "integrations/github"
        version = "~> 5.0"
        configuration_aliases = [ github ]
        }
    }
}

/* Create the GitHub repository only once */
resource "github_repository" "dataform_remote_repo" {
    count       = var.github_environment == "dev" ? 1 : 0
    name        = var.github_remote_repo_name
    description = var.github_remote_repo_description
    visibility  = var.github_remote_repo_visibility
    auto_init   = true

    lifecycle {
        ignore_changes = [
            auto_init,
            gitignore_template,
            has_issues,
            has_projects,
            has_wiki,
            license_template,
            name,
            owner,
            private,
            template,
            topics,
            visibility,
            allow_merge_commit,
            allow_squash_merge,
            allow_rebase_merge,
            delete_branch_on_merge,
            has_downloads,
            has_pages,
            has_projects,
            has_wiki
        ]
    }
}

/* Create the branch */
resource "github_branch" "branch" {
    count         = var.github_environment == "dev" ? 1 : 0
    repository    = var.github_remote_repo_name
    branch        = var.github_branch_default
    source_branch = "main"
    depends_on    = [
        github_repository.dataform_remote_repo
    ]
}

/* Set the default branch only once */
resource "github_branch_default" "default" {
    count       = var.github_environment == "dev" ? 1 : 0
    repository  = github_repository.dataform_remote_repo[0].name
    branch      = var.github_branch_default
    depends_on  = [
        github_branch.branch
    ]

    lifecycle {
        prevent_destroy = true
    }
}

# Data source to read repository info (available in both environments)
data "github_repository" "dataform_repo" {
	name 	    = var.github_remote_repo_name
	depends_on  = [
		github_repository.dataform_remote_repo
	]
}
