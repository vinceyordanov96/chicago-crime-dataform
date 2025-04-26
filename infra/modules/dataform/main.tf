/* Create the Dataform repository */
resource "google_dataform_repository" "dataform_repository" {
	provider 								   = google-beta
	
	project 								   = var.dataform_project_id
	region 									   = var.dataform_region
	name 									   = var.dataform_repo_name
	display_name 							   = var.dataform_repo_name
	service_account 				    	   = var.dataform_service_account
	deletion_policy 						   = var.dataform_repo_deletion_policy
	npmrc_environment_variables_secret_version = var.dataform_npmrc_secret_version

	git_remote_settings {
		url			   				        = var.dataform_github_repo_url
		default_branch 					    = var.dataform_github_default_branch
		authentication_token_secret_version = var.dataform_github_token_secret_version
	}

	workspace_compilation_overrides {
		default_database = var.dataform_project_id
		schema_suffix 	 = "$${workspaceName}"
	}

	# Prevent the Dataform repository from being destroyed or updated
	# if any of the below attributes are changed outside of Terraform.
	lifecycle {
		ignore_changes = [
			git_remote_settings,
			workspace_compilation_overrides,
			npmrc_environment_variables_secret_version,
			service_account,
			timeouts
		]
	}
}

/** 
 * Grant the Dataform default service account the necessary project-wide 
 * permissions to execute queries within the dataform repository. 
 */
resource "google_project_iam_member" "dataform_default_sa_iam_member" {
	for_each = toset([
		"roles/iam.serviceAccountTokenCreator",
		"roles/secretmanager.secretAccessor"
	])

	project = var.dataform_project_id
	role    = each.value
	member  = "serviceAccount:service-${var.dataform_project_id}@gcp-sa-dataform.iam.gserviceaccount.com"

	depends_on = [
		google_dataform_repository.dataform_repository
	]
}


/** 
 * Grant the Dataform service account the necessary permissions to execute the project.
 * Note that the orchestration service account is granted the "dataform.editor" role.
 * This is because the orchestration service account is attached to the Cloud Workflows
 * instance (orchestration layer) and therefore needs to be able to execute the Dataform
 * project as a whole.
 */
resource "google_dataform_repository_iam_member" "dataform_repository_iam_member" {
	provider 	 = google-beta
	project 	 = google_dataform_repository.dataform_repository.project
	region 	 	 = google_dataform_repository.dataform_repository.region
	repository 	 = google_dataform_repository.dataform_repository.name
	role 	     = "roles/dataform.admin"
	member 	 	 = "serviceAccount:${var.dataform_service_account}"
	depends_on 	 = [ 
		google_dataform_repository.dataform_repository 
	]
}

resource "google_dataform_repository_iam_member" "dataform_orchestration_sa_iam_member" {
	provider 	 = google-beta
	project 	 = google_dataform_repository.dataform_repository.project
	region 	 	 = google_dataform_repository.dataform_repository.region
	repository 	 = google_dataform_repository.dataform_repository.name
	role 	     = "roles/dataform.editor"
	member 	 	 = "serviceAccount:${var.dataform_orchestration_sa}"
	depends_on 	 = [ 
		google_dataform_repository.dataform_repository 
	]
}

/* Create the Dataform workspace. */
resource "null_resource" "workspace_creation" {

	# These triggers are used to ensure that the workspace is created
	# only when the repository is re-created.
	triggers = {
        repository_id   = google_dataform_repository.dataform_repository.id
    }

	provisioner "local-exec" {
        command = <<-EOT
			
			# Validate the service account running this
			account=$(gcloud config get account)
			echo "Running as $(gcloud config get account)"

            # Create workspace
            curl -X POST \
				"https://dataform.googleapis.com/v1beta1/projects/${var.dataform_project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces?workspaceId=${var.dataform_workspace_name}" \
				-H "Authorization: Bearer $(gcloud auth print-access-token)" \
				-H "Content-Type: application/json" \
				-d '{}'
        EOT
		on_failure = continue
    }
	
    depends_on = [
		google_dataform_repository_iam_member.dataform_repository_iam_member,
		google_dataform_repository.dataform_repository
	]
}




/**
 * Initialize the Dataform project
 * 
 * Here we:
 * 1. Create the default dataform directories (definitions, includes, etc.)
 * 2. Add package.json, workflow_settings.yaml files
 * 3. Upload all template files in this repository. 
 * 4. Install NPM dependencies
 * 5. Commit and push the changes to the remote repository
 */

resource "null_resource" "create_directories" {
	
	# These triggers are used to ensure that the directories are created
	# only when the repository is re-created.
	triggers = {
        repository_id   = google_dataform_repository.dataform_repository.id
    }
	
	provisioner "local-exec" {
		command = <<-EOT
			curl -X POST \
				"https://dataform.googleapis.com/v1beta1/projects/${var.dataform_project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/${var.dataform_workspace_name}:makeDirectory" \
				-H "Authorization: Bearer $(gcloud auth print-access-token)" \
				-H "Content-Type: application/json" \
				-d '{"path": "definitions"}'

			curl -X POST \
				"https://dataform.googleapis.com/v1beta1/projects/${var.dataform_project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/${var.dataform_workspace_name}:makeDirectory" \
				-H "Authorization: Bearer $(gcloud auth print-access-token)" \
				-H "Content-Type: application/json" \
				-d '{"path": "includes"}'
		EOT
	}
	depends_on = [
		null_resource.workspace_creation
	]
}

resource "null_resource" "upload_main_files" {
	
	# These triggers are used to ensure that the main files are uploaded
	# only when the repository is re-created.
	triggers = {
        repository_id   = google_dataform_repository.dataform_repository.id
    }

	provisioner "local-exec" {
		command = <<-EOT
			MAIN_DIR="${path.module}/../../dataform"
			echo "Uploading main files"
			echo "*--------------------------*"
			for file in $(find "$MAIN_DIR" -type f -name "*.yaml" -o -name "*.json"); do
				relative_path=$(realpath --relative-to="$MAIN_DIR" "$file")
				contents=$(cat "$file" | base64 | tr -d '\n')
				curl -X POST \
					"https://dataform.googleapis.com/v1beta1/projects/${var.dataform_project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/${var.dataform_workspace_name}:writeFile" \
					-H "Authorization: Bearer $(gcloud auth print-access-token)" \
					-H "Content-Type: application/json" \
					-d "{\"path\": \"$relative_path\", \"contents\": \"$contents\"}"
			done
		EOT
	}

	depends_on = [
		null_resource.create_directories
	]
}

resource "null_resource" "upload_definitions_files" {
	# These triggers are used to ensure that the definitions files are uploaded
	# only when the repository is re-created.
	triggers = {
        repository_id   = google_dataform_repository.dataform_repository.id
    }
	
	provisioner "local-exec" {
		command = <<-EOT
			DEFINITIONS_DIR="${path.module}/../../dataform/definitions"
			echo "Uploading definitions files"
			echo "*--------------------------*"
			for file in $(find "$DEFINITIONS_DIR" -type f); do
				relative_path=$(realpath --relative-to="$DEFINITIONS_DIR" "$file")
				dir_path=$(dirname "$relative_path")
				contents=$(cat "$file" | base64 | tr -d '\n')
				curl -X POST \
					"https://dataform.googleapis.com/v1beta1/projects/${var.dataform_project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/${var.dataform_workspace_name}:writeFile" \
					-H "Authorization: Bearer $(gcloud auth print-access-token)" \
					-H "Content-Type: application/json" \
					-d "{\"path\": \"definitions/$relative_path\", \"contents\": \"$contents\"}"
			done
		EOT
	}
	
	depends_on = [
		null_resource.create_directories
	]
}

resource "null_resource" "upload_includes_files" {
	# These triggers are used to ensure that the includes files are uploaded
	# only when the repository is re-created.
	triggers = {
        repository_id   = google_dataform_repository.dataform_repository.id
    }

	provisioner "local-exec" {
		command = <<-EOT
			INCLUDES_DIR="${path.module}/../../dataform/includes"
			echo "Uploading includes files"
			echo "*--------------------------*"
			for file in $(find "$INCLUDES_DIR" -type f); do
				relative_path=$(realpath --relative-to="$INCLUDES_DIR" "$file")
				contents=$(cat "$file" | base64 | tr -d '\n')
				curl -X POST \
					"https://dataform.googleapis.com/v1beta1/projects/${var.dataform_project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/${var.dataform_workspace_name}:writeFile" \
					-H "Authorization: Bearer $(gcloud auth print-access-token)" \
					-H "Content-Type: application/json" \
					-d "{\"path\": \"includes/$relative_path\", \"contents\": \"$contents\"}"
			done
		EOT
	}

	depends_on = [
		null_resource.upload_definitions_files
	]
}

/* Install NPM dependencies */
resource "null_resource" "install_npm_dependencies" {
	# These triggers are used to ensure that the NPM dependencies are installed
	# only when the repository is re-created.
	triggers = {
        repository_id   = google_dataform_repository.dataform_repository.id
    }

	provisioner "local-exec" {
		command = <<-EOT
			curl -X POST \
				"https://dataform.googleapis.com/v1beta1/projects/${var.dataform_project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/${var.dataform_workspace_name}:installNpmPackages" \
				-H "Authorization: Bearer $(gcloud auth print-access-token)" \
				-H "Content-Type: application/json" \
				-d '{}'
		EOT
	}

	depends_on = [
		null_resource.upload_includes_files
	]
}

/* Commit the changes to the workspace */
resource "null_resource" "commit_changes" {
	# These triggers are used to ensure that the changes are committed
	# only when the repository is re-created.
	triggers = {
        repository_id   = google_dataform_repository.dataform_repository.id
    }

	provisioner "local-exec" {
		command = <<-EOT
			curl -X POST \
				"https://dataform.googleapis.com/v1beta1/projects/${var.dataform_project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/${var.dataform_workspace_name}:commit" \
				-H "Authorization: Bearer $(gcloud auth print-access-token)" \
				-H "Content-Type: application/json" \
				-d '{
					"author": {
						"name": "Dataform Service Agent",
						"emailAddress": "${var.dataform_service_account}"
					},
					"commitMessage": "Initial commit"
				}'
		EOT
	}
	depends_on = [
		null_resource.install_npm_dependencies
	]
}

/* Push the changes to the remote repository */
resource "null_resource" "push_changes" {
	# These triggers are used to ensure that the changes are pushed
	# only when the repository is re-created.
	triggers = {
        repository_id   = google_dataform_repository.dataform_repository.id
    }

	provisioner "local-exec" {
		command = <<-EOT
			curl -X POST \
				"https://dataform.googleapis.com/v1beta1/projects/${var.dataform_project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/${var.dataform_workspace_name}:push" \
				-H "Authorization: Bearer $(gcloud auth print-access-token)" \
				-H "Content-Type: application/json" \
				-d '{
					"remoteBranch": "${var.dataform_github_default_branch}"
				}'
		EOT
	}

	depends_on = [
		null_resource.commit_changes
	]
}

/* Create the release config */
resource "google_dataform_repository_release_config" "release_config" {
	provider   	  = google-beta

	project    	  = google_dataform_repository.dataform_repository.project
	region     	  = google_dataform_repository.dataform_repository.region
	repository 	  = google_dataform_repository.dataform_repository.name
	name          = var.dataform_github_default_branch
	git_commitish = var.dataform_github_default_branch

	code_compilation_config {
		default_database = var.dataform_project_id
		default_schema   = var.dataform_default_schema
		default_location = var.dataform_region

		vars = {
			is_dev_env = var.dataform_github_default_branch == "dev"
		}
	}
	depends_on = [
		null_resource.push_changes
	]
}
