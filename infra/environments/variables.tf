/* Global Configuration Variables */
variable "environment" {
    description = "Environment (dev/prod) for this project"
    type        = string
}
variable "project_id" {
    description = "The GCP project ID"
    type        = string
}
variable "region" {
    description = "Region of the GCP project"
    type        = string
}
variable "zone" {
    description = "Zone of the GCP project"
    type        = string
}
variable "service_account" {
    description = "Email address of the terraform service account used for deployments."
    type        = string
}
variable "backend_gcs_bucket" {
    description = "The GCS bucket to store the terraform state"
    type        = string
}


/* Services Variables */
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



/* IAM Variables */
variable "service_account_list" {
    description = "List of service accounts"
    type        = list(object({
        name         = string
        display_name = string
        description  = string
        roles        = list(string)
    }))
}


/* GCF Gen2 Variables */
variable "gcf_project_id" {
    description = "The ID of the project"
    type        = string
    default     = "your-project-id"
}
variable "gcf_service_account" {
    description = "The google provided service agent for building and deploying alerts cloud function."
    type        = string
}
variable "gcf_service_account_name" {
    description = "Display Name of the GCF Service Account"
    type        = string
}
variable "gcf_memory" {
    description = "Memory allocated to the cloud function"
    type        = string
}
variable "gcf_runtime" {
    description = "The Python runtime environment for the cloud function"
    type        = string
}
variable "gcf_timeout" {
    description = "Memory allocated to the cloud function"
    type        = number
}
variable "gcf_name" {
    description = "Name of the cloud function"
    type        = string
}
variable "gcf_description" {
    description = "Description of the cloud function"
    type        = string
}
variable "gcf_ingress_settings" {
    description = "Ingress settings of the cloud function"
    type        = string
}
variable "gcf_entry_point" {
    description = "Entry point of the cloud function"
    type        = string
    default     = "main"
}
variable "gcf_cpu" {
    description = "CPU allocated to the cloud function"
    type        = string
}
variable "gcf_region" {
    description = "Region of the cloud function"
    type        = string
    default     = "europe-west1"
}
variable "gcf_invoker_service_account_name" {
    description = "Service account that will invoke the cloud function"
    type        = string
}
variable "gcf_invoker_service_account_role" {
    description = "List of roles for the invoker service account"
    type        = string
}
variable "gcs_bucket_name" {
    description = "Name of the GCS bucket"
    type        = string
    default     = "your-gcs-bucket-name"
}
variable "gcs_bucket_location" {
    description = "Location of the GCS bucket"
    type        = string
    default     = "europe-west1"
}
variable "gcs_bucket_storage_class" {
    description = "Storage class of the GCS bucket"
    type        = string
    default     = "STANDARD"
}
variable "gcf_ingestion_start_date" {
    description = "Start date for the ingestion process"
    type        = string
    default     = "2001-01-01"
}
variable "gcf_downstream_workflow_id" {
    description = "ID of the downstream workflow"
    type        = string
}
variable "gcf_socrata_app_token" {
    description = "Socrata token to store in the secret manager"
    type        = string
    sensitive   = true
}


/* Cloud Scheduler Variables */
variable "scheduler_name" {
    description = "Name of the scheduler job"
    type        = string
}
variable "scheduler_description" {
    description = "Description of the scheduler job"
    type        = string
}
variable "scheduler_frequency" {
    description = "Schedule of the scheduler job"
    type        = string
    default     = "0 2 * * *"
}
variable "scheduler_time_zone" {
    description = "Time zone of the scheduler job"
    type        = string
}
variable "scheduler_http_method" {
    description = "HTTP method of the scheduler job"
    type        = string
}
variable "scheduler_oauth_scope" {
    description = "OAuth scope of the scheduler job"
    type        = string
}
variable "scheduler_service_account" {
    description = "Service account which the scheduler will use to invoke the cloud function"
    type        = string
}


/* BigQuery Variables */
variable "bq_project_id" {
    description = "BigQuery project ID"
    type        = string
    default     = "your-project-id"
}
variable "bq_region" {
    description = "BigQuery region"
    type        = string
}
variable "bq_delete_contents_on_destroy" {
    description = "Delete contents on destroy"
    type        = bool
}
variable "bq_data_source_id" {
    description = "Data source ID"
    type        = string
}
variable "bq_schedule_query_frequency" {
    description = "Frequency of the scheduled query"
    type        = string
    default     = "daily"
}
variable "bq_deletion_protection" {
    description = "Deletion protection"
    type        = bool
    default     = false
}
variable "bq_raw_dataset_id" {
    description = "BigQuery dataset ID for raw data"
    type        = string
}
variable "bq_staging_dataset_id" {
    description = "BigQuery dataset ID for staging data"
    type        = string
}
variable "bq_transformed_dataset_id" {
    description = "BigQuery dataset ID for transformed data"
    type        = string
}
variable "bq_lookup_dataset_id" {
    description = "BigQuery dataset ID for transformed data"
    type        = string
}
variable "bq_table_id_raw" {
    description = "BigQuery table IDs"
    type        = string 
}
variable "bq_table_id_lookup" {
    description = "BigQuery table IDs"
    type        = string 
}
variable "bq_table_id_transformed" {
    description = "BigQuery table IDs"
    type        = string 
}
variable "bq_partition_type" {
    description = "BigQuery partition type"
    type        = string
    default     = "DAY"
}
variable "bq_partition_field" {
    description = "BigQuery partition field"
    type        = string
    default     = "date"
}
variable "bq_partition_field_transformed" {
    description = "BigQuery partition field for transformed table"
    type        = string
    default     = "date"
}
variable "bq_partition_expiration_ms" {
    description = "BigQuery partition expiration in milliseconds"
    type        = number
    default     = null
}


/* GitHub Variables */
variable "github_branch_default" {
    description = "The default branch of the GitHub repository"
    type        = string
}
variable "github_remote_repo_name" {
    description = "The name of the repository where Dataform project files are stored"
    type        = string
}
variable "github_remote_repo_description" {
    description = "The description of the repository where Dataform project files are stored"
    type        = string
}
variable "github_remote_repo_visibility" {
    description = "The visibility of the repository where Dataform project files are stored"
    type        = string
}
variable "github_remote_repo_init_file" {
    description = "The name of the file which is uploaded to initialize the Dataform configuraiton"
    type        = string
}
variable "github_remote_dataform_dir" {
    description = "The directory where Dataform project files are stored"
    type        = string
}
variable "github_token" {
    description = "GitHub Personal Access Token"
    type        = string
    sensitive   = true
}
variable "github_create_resources" {
    description = "Whether to create GitHub resources. Should be true only for one environment."
    type        = bool
}


/* Secret Manager Variables */
variable "secret_manager_secret_name" {
    description = "Name of the secret"
    type        = string
}
variable "secret_manager_socrata_app_token_name" {
    description = "Name of the Socrata token secret"
    type        = string  
}



/* Dataform Variables */
variable "dataform_project_id" {
    description = "The ID of the project"
    type        = string
}
variable "dataform_repo_name" {
    description = "The name of the repository"
    type        = string
}
variable "dataform_workspace_name" {
    description = "The name of the workspace"
    type        = string
}
variable "dataform_service_account" {
    description = "The google provided service agent for building and deploying alerts cloud function."
    type        = string
}
variable "dataform_orchestration_sa" {
    description = "Service account for the orchestration layer"
    type        = string
}
variable "dataform_region" {
  description = "Region of the Dataform project"
  type        = string
  default     = "europe-west1"
}
variable "dataform_default_schema" {
    description = "The default schema for the Dataform project"
    type        = string
    default     = "transformed"
}



/* WIF Variables */
variable "github_username" {
    description = "The GitHub username"
    type        = string
}
variable "repo_name" {
    description = "The name of the repository"
    type        = string
}
variable "repository_id" {
    description = "The ID of the repository"
    type        = string
}
variable "pool_id" {
    description = "The ID of the WIF pool"
    type        = string
}
variable "pool_display_name" {
    description = "The display name of the WIF pool"
    type        = string
}
variable "pool_description" {
    description = "The description of the WIF pool"
    type        = string
}
variable "provider_id" {
    description = "The ID of the WIF provider"
    type        = string
}
variable "provider_display_name" {
    description = "The display name of the WIF provider"
    type        = string
}
variable "provider_description" {
    description = "The description of the WIF provider"
    type        = string
}


/* Cloud Workflows Variables */
variable "workflow_name" {
    description = "Name of the workflow instance"
    type        = string
}
variable "workflow_description" {
    description = "Description of the workflow instance"
    type        = string
}
variable "workflow_region" {
    description = "Region of the workflow instance"
    type        = string
}
variable "workflow_service_account" {
    description = "Service account which the workflow will use to invoke the cloud function"
    type        = string
}
