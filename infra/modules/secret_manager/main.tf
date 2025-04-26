resource "google_secret_manager_secret" "github_token" {
    secret_id = var.secret_manager_secret_name
    project   = var.secret_manager_project_id

    replication {
        auto {}
    }
}

resource "google_secret_manager_secret" "npmrc" {
    secret_id = "npmrc"
    project   = var.secret_manager_project_id

    replication {
        auto {}
    }
}

resource "google_secret_manager_secret" "socrata_app_token" {
    secret_id = var.secret_manager_socrata_app_token_name
    project   = var.secret_manager_project_id

    replication {
        auto {}
    }
}


resource "google_secret_manager_secret_version" "github_token_version" {
    secret      = google_secret_manager_secret.github_token.id
    secret_data = var.secret_manager_github_token
}


resource "google_secret_manager_secret_version" "npmrc_version" {
    secret      = google_secret_manager_secret.npmrc.id
    secret_data = <<EOF
    {
        "AUTHENTICATION_TOKEN": "${var.secret_manager_github_token}"
    }
    EOF
}

resource "google_secret_manager_secret_version" "socrata_app_token_version" {
    secret      = google_secret_manager_secret.socrata_app_token.id
    secret_data = var.secret_manager_socrata_app_token
}
