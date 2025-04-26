output "github_repo_url" {
	value = data.github_repository.dataform_repo.html_url
}
output "github_repo_name" {
	value = data.github_repository.dataform_repo.full_name
}
output "github_token" {
	value     = var.github_token
	sensitive = true
}
