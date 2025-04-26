# Global variables
environment = "prod"
project_id = "your-project-id"
project_number = "your-project-number"
region = "your-region"
zone = "your-zone"
backend_gcs_bucket = "your-backend-gcs-bucket"
service_account = "your-service-account"


# Services
services = [
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

# IAM
service_account_list = [ 
    {
        name = "ingestion",
        display_name = "Raw Data Ingestion GCF Service Account",
        description = "Service account for the GCF which will ingest raw data from the Chicago Data Portal into BigQuery",
        roles = [
            "roles/secretmanager.secretAccessor",
            "roles/iam.serviceAccountTokenCreator",
            "roles/bigquery.dataEditor",
            "roles/bigquery.jobUser",
            "roles/workflows.invoker"
        ]
    },
    {
        name = "ingestion-trigger",
        display_name = "Ingestion Trigger Service Account",
        description = "Service account for the Cloud Scheduler which will trigger the ingestion of raw data (GCF) into BigQuery",
        roles = [
            "roles/cloudfunctions.invoker",
            "roles/cloudscheduler.admin",
            "roles/iam.serviceAccountTokenCreator",
            "roles/run.invoker"
        ]
    },
    {
        name = "orchestrator",
        display_name = "Orchestrator Service Account",
        description = "Service account for the Workflows which will orchestrate the dataform pipeline",
        roles = [
            "roles/workflows.editor",
            "roles/dataform.editor",
            "roles/bigquery.jobUser",
            "roles/bigquery.dataEditor",
            "roles/iam.serviceAccountTokenCreator"
        ]
    },
    {
        name = "dataform",
        display_name = "Dataform Service Account",
        description = "Service account for the Dataform project",
        roles = [
            "roles/bigquery.dataOwner",
            "roles/bigquery.metadataViewer",
            "roles/bigquery.jobUser",
            "roles/secretmanager.secretAccessor",
            "roles/iam.serviceAccountTokenCreator"
        ]
    }
]


# WIF
repo_name = "your-repo-name"
github_username = "your-username"
repository_id = "your-repository-id"
pool_id = "your-pool-id"
pool_display_name = "your-pool-display-name"
pool_description = "your-pool-description"
provider_id = "your-provider-id"
provider_display_name = "your-provider-display-name"
provider_description = "your-provider-description"


# BigQuery
bq_region = "your-region"
bq_raw_dataset_id = "your-raw-dataset-id"
bq_staging_dataset_id = "your-staging-dataset-id"
bq_transformed_dataset_id = "your-transformed-dataset-id"
bq_lookup_dataset_id = "your-lookup-dataset-id"
bq_delete_contents_on_destroy = true
bq_table_id_raw = "your-table-id-raw"
bq_table_id_lookup = "your-table-id-lookup"
bq_table_id_transformed = "your-table-id-transformed"
bq_data_source_id = "your-data-source-id"
bq_deletion_protection = false
bq_partition_type = "your-partition-type"
bq_partition_field = "your-partition-field"
bq_partition_expiration_ms = null


# Scheduler
scheduler_name = "your-scheduler-name"
scheduler_description = "your-scheduler-description"
scheduler_time_zone = "your-time-zone"
scheduler_service_account = "your-service-account"
scheduler_oauth_scope = "your-oauth-scope"
scheduler_http_method = "your-http-method"


# Cloud Function
gcf_name = "your-gcf-name"
gcf_description = "your-gcf-description"
gcf_runtime = "your-runtime"
gcf_memory = "your-memory"
gcf_timeout = 3600
gcf_ingress_settings = "your-ingress-settings"
gcf_cpu = "your-cpu"
gcf_downstream_workflow_id = "your-downstream-workflow-id"
gcf_service_account = "your-service-account"
gcf_service_account_name = "your-service-account-name"
gcf_invoker_service_account_name = "your-invoker-service-account-name"
gcf_invoker_service_account_role = "your-invoker-service-account-role"




# GitHub
github_branch_default = "your-branch-default"
github_remote_repo_name = "your-remote-repo-name"
github_remote_repo_description = "your-remote-repo-description"
github_remote_repo_visibility = "your-remote-repo-visibility"
github_remote_repo_init_file = "your-remote-repo-init-file"
github_remote_dataform_dir = "your-remote-dataform-dir"
github_create_resources = false

# Secret Manager
secret_manager_secret_name = "your-secret-manager-secret-name"
secret_manager_socrata_app_token_name = "your-socrata-app-token-name"

# Dataform
dataform_project_id = "your-dataform-project-id"
dataform_region = "your-dataform-region"
dataform_repo_name = "your-dataform-repo-name"
dataform_workspace_name = "your-dataform-workspace-name"
dataform_default_schema = "your-dataform-default-schema"
dataform_service_account = "your-dataform-service-account"
dataform_orchestration_sa = "your-dataform-orchestration-sa"

# Workflows
workflow_name = "your-workflow-name"
workflow_region = "your-workflow-region"
workflow_description = "your-workflow-description"
workflow_service_account = "your-workflow-service-account"
