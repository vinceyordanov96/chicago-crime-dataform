/* Terraform configuration for the Chicago Crime Dataform project. */
terraform {
    required_version = ">=1.8.5"
    required_providers {
        google = {
			source  = "hashicorp/google"
			version = "6.29.0"
		}
		google-beta = {
			source  = "hashicorp/google-beta"
			version = "6.29.0"
		}
        github = {
			source  = "integrations/github"
			version = "~> 5.0"
		}
        null = {
            source  = "hashicorp/null"
        }
    }
    backend "gcs" {}
}

/* Provider Configuration */
provider "google" {
    project     = var.project_id
    region      = var.region
    zone        = var.zone
}

provider "github" {
    token = var.github_token
    owner = var.github_username
}


/* Module for enabling GCP service APIs needed for this project. */
module "services" {
    source                     = "./../modules/services"
    project_id                 = var.project_id
    services                   = var.services
}

/* IAM module for creating service accounts and roles. */
module "iam" {
    source                     = "./../modules/iam"
    iam_project_id             = var.project_id
    iam_service_account_list   = var.service_account_list
    depends_on                 = [ module.services ]
}


/* Workload Identity Federation Module. */
module "wif" {
	source                     = "./../modules/wif"
    github_username            = var.github_username
    repo_name                  = var.repo_name
    repository_id              = var.repository_id 
	project_id                 = var.project_id
	pool_id                    = var.pool_id
	pool_display_name          = var.pool_display_name
	pool_description           = var.pool_description
	provider_id                = var.provider_id
	provider_display_name      = var.provider_display_name
	provider_description       = var.provider_description
	service_account            = var.service_account
    depends_on                 = [ module.iam ] 
}


/* Module for Secret Manager Key storage. */
module "secrets" {
    source                                = "./../modules/secret_manager"
    secret_manager_project_id             = var.project_id
    secret_manager_secret_name            = var.secret_manager_secret_name
    secret_manager_socrata_app_token_name = var.secret_manager_socrata_app_token_name
    secret_manager_socrata_app_token      = var.gcf_socrata_app_token
    secret_manager_github_token           = var.github_token
    depends_on                            = [ module.wif ]
}


/* Module for BigQuery Datasets to which raw, staging and transformed data will be loaded. */
module "bigquery" {
    source                        = "./../modules/bigquery"
    bq_project_id                 = var.project_id
    bq_region                     = var.bq_region
    bq_raw_dataset_id             = var.bq_raw_dataset_id
    bq_staging_dataset_id         = var.bq_staging_dataset_id
    bq_transformed_dataset_id     = var.dataform_default_schema
    bq_lookup_dataset_id          = var.bq_lookup_dataset_id
    bq_table_id_raw               = var.bq_table_id_raw
    bq_table_id_lookup            = var.bq_table_id_lookup
    bq_table_id_transformed       = var.bq_table_id_transformed
    bq_data_source_id             = var.bq_data_source_id
    bq_schedule_query_frequency   = var.bq_schedule_query_frequency
    bq_delete_contents_on_destroy = var.bq_delete_contents_on_destroy
    bq_deletion_protection        = var.bq_deletion_protection
    bq_partition_type             = var.bq_partition_type
    bq_partition_field            = var.bq_partition_field
    bq_partition_expiration_ms    = var.bq_partition_expiration_ms
    depends_on                    = [ module.secrets ] 
}



/* Module for creation of remote GitHub repo. */
module "github" {
    providers = {
        github = github
    }

    source                         = "./../modules/github"
    github_environment             = var.environment
    github_branch_default          = var.github_branch_default
    github_remote_repo_name        = var.github_remote_repo_name
    github_remote_repo_description = var.github_remote_repo_description
    github_remote_repo_visibility  = var.github_remote_repo_visibility
    github_remote_repo_init_file   = var.github_remote_repo_init_file
    github_remote_dataform_dir     = var.github_remote_dataform_dir
    github_token                   = var.github_token
    github_create_resources        = var.github_create_resources
    depends_on                     = [  module.bigquery ]
}



/* Module for Dataform project. */
module "dataform" {
    source                               = "./../modules/dataform"
    dataform_project_id                  = var.project_id
    dataform_region                      = var.region
    dataform_repo_name                   = var.dataform_repo_name
    dataform_remote_repo_name            = var.repo_name
    dataform_workspace_name              = var.dataform_workspace_name
    dataform_default_schema              = var.dataform_default_schema
    dataform_service_account             = module.iam.service_account_emails["dataform"]
    dataform_orchestration_sa            = var.dataform_orchestration_sa
    dataform_github_repo_url             = module.github.github_repo_url
    dataform_github_default_branch       = var.github_branch_default
    dataform_github_token                = var.github_token
    dataform_github_token_secret_version = module.secrets.secret_version_github_token
    dataform_npmrc_secret_version        = module.secrets.secret_version_npmrc
    depends_on                           = [
        module.iam,
        module.github, 
        module.secrets 
    ] 
}


/* Cloud Workflows (orchestration) module. */
module "workflows" {
    source                     = "./../modules/workflows"
    workflow_name              = var.workflow_name
    workflow_project_id        = var.project_id
    workflow_region            = var.workflow_region 
    workflow_description       = var.workflow_description 
    workflow_service_account   = module.iam.service_account_emails["orchestrator"]
    depends_on                 = [ 
        module.iam,
        module.dataform 
    ]
}

/* Module for creating a Cloud Function that will be triggered by the Cloud Scheduler instance. */
module "cloud_function" {
    source                           = "./../modules/gcf"
    gcf_name                         = var.gcf_name
    gcf_description                  = var.gcf_description
    gcf_project_id                   = var.project_id
    gcf_region                       = var.region
    gcf_runtime                      = var.gcf_runtime
    gcf_entry_point                  = var.gcf_entry_point 
	gcf_cpu 				         = var.gcf_cpu
	gcf_timeout 			         = var.gcf_timeout
	gcf_ingress_settings             = var.gcf_ingress_settings
	gcf_memory                       = var.gcf_memory
    gcs_bucket_name                  = var.gcs_bucket_name
    gcs_bucket_location              = var.gcs_bucket_location
    gcs_bucket_storage_class         = var.gcs_bucket_storage_class
    gcf_downstream_workflow_id       = module.workflows.workflow_id # fully qualified path to the workflow
    gcf_environment                  = var.environment
    gcf_ingestion_start_date         = var.gcf_ingestion_start_date
    gcf_invoker_service_account_name = var.gcf_invoker_service_account_name
    gcf_invoker_service_account_role = var.gcf_invoker_service_account_role
    gcf_socrata_app_token            = var.secret_manager_socrata_app_token_name
    gcf_service_account              = module.iam.service_account_emails["ingestion"]
    depends_on                       = [ module.workflows ]
}


/* Cloud Scheduler module for daily raw data ingestion. */
module "scheduler" {
    source                     = "./../modules/scheduler"
    scheduler_name             = var.scheduler_name
    scheduler_description      = var.scheduler_description
    scheduler_project_id       = var.project_id
    scheduler_region           = var.region
    scheduler_zone             = var.zone
    scheduler_time_zone        = var.scheduler_time_zone
    scheduler_oauth_scope      = var.scheduler_oauth_scope
    scheduler_target_audience  = module.cloud_function.gcf_trigger_url
    scheduler_service_account  = module.iam.service_account_emails["ingestion-trigger"]
    depends_on                 = [ module.cloud_function ]
}


/* Output the service account emails for debugging purposes. */
output "debug_all_service_accounts" {
    value = module.iam.service_account_emails
}
output "debug_dataform_service_account" {
    value = module.iam.service_account_emails["dataform"]
}
