output "secret_version_github_token" {
    value = google_secret_manager_secret_version.github_token_version.name
}
output "secret_version_socrata_app_token" {
    value = google_secret_manager_secret_version.socrata_app_token_version.name
}
output "secret_version_npmrc" {
    value = google_secret_manager_secret_version.npmrc_version.name
}
