variable "project_id" {}

variable "services" {
    description = "List of services to be created"
    type = list(string)
    default = [
        "servicemanagement.googleapis.com",
		"logging.googleapis.com",
		"compute.googleapis.com",
		"bigquery.googleapis.com",
		"bigquerystorage.googleapis.com",
		"bigquerydatatransfer.googleapis.com",
		"dataform.googleapis.com",
		"run.googleapis.com",
		"cloudbuild.googleapis.com",
		"artifactregistry.googleapis.com",
		"cloudfunctions.googleapis.com",
		"cloudscheduler.googleapis.com",
		"secretmanager.googleapis.com",
		"workflows.googleapis.com"
    ]
}
