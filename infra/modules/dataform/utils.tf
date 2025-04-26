locals {
	# Define paths to scan for dataform files
	dataform_dirs = ["${path.module}/dataform/includes", "${path.module}/dataform/definitions"]

	# Get all .sqlx and .js files recursively
	sqlx_files = flatten([
		for dir in local.dataform_dirs : [
			for f in fileset("${dir}", "**/*.sqlx") : "${dir}/${f}"
		]
	])

	js_files = flatten([
		for dir in local.dataform_dirs : [
			for f in fileset("${dir}", "**/*.js") : "${dir}/${f}"
		]
	])

	# Combine all files
	all_dataform_files = concat(local.sqlx_files, local.js_files)

	# Create a set of just file paths (not content hashes)
	file_paths = toset(local.all_dataform_files)

	# Hash only the file paths - this changes when files are added/removed, not modified
	files_hash = sha256(jsonencode(local.file_paths))

	# For new files only detection, we need to compare with previous run
	# We'll read the previous file list (if exists) from a state file
	previous_files_content = fileexists("${path.module}/.terraform/dataform_files_list.json") ? file("${path.module}/.terraform/dataform_files_list.json") : "[]"
	previous_files = jsondecode(local.previous_files_content)

	# Find new files by comparing current list with previous list
	# This will be empty on first run (previous_files is empty)
	new_files = [for file in local.all_dataform_files : file if !contains(local.previous_files, file)]
	new_file_set = toset(local.new_files)
}


# Detect if new files are added
resource "null_resource" "detect_file_changes" {
	triggers = {
		files_hash 	  = local.files_hash # Store just the hash of file paths - changes only when files are added/removed
		repository_id = google_dataform_repository.dataform_repository.id # Store the repository ID - changes when repository is recreated
	}

	# Store current file list for comparison on next run
	provisioner "local-exec" {
		command = "echo '${jsonencode(local.all_dataform_files)}' > ${path.module}/.terraform/dataform_files_list.json"
	}

	depends_on = [
		google_dataform_repository.dataform_repository,
		null_resource.workspace_creation
	]
}

