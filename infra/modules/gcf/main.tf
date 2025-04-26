resource "random_id" "chicago_data_ingestion_bucket_id" {
    byte_length = 8
}

resource "google_storage_bucket" "chicago_data_ingestion_workflow_bucket" {
    location                    = var.gcs_bucket_location
    name                        = "${var.gcf_name}-${random_id.chicago_data_ingestion_bucket_id.hex}"
    project                     = var.gcf_project_id 
    force_destroy               = true
    uniform_bucket_level_access = true
}

data "archive_file" "zip_source_chicago_data_ingestion" {
    type        = "zip"
    output_path = "${path.module}/${var.gcf_name}.zip"
    source_dir  = "${path.module}/../../../ingest"
}

resource "google_storage_bucket_object" "chicago_data_ingestion_object" {
    bucket         = google_storage_bucket.chicago_data_ingestion_workflow_bucket.name
    name           = "${var.gcf_name}.${data.archive_file.zip_source_chicago_data_ingestion.output_md5}.zip"
    source         = data.archive_file.zip_source_chicago_data_ingestion.output_path
}

# Local resource containing env variables to be used in the cloud function
locals {
    socrata_app_token = var.gcf_socrata_app_token
    current_date      = formatdate("YYYY-MM-DD", timestamp())
    backfill_range    = jsonencode({
        start_date = var.gcf_ingestion_start_date
        end_date   = local.current_date
    })
}

resource "google_cloudfunctions2_function" "chicago_data_ingestion" {
    location    = var.gcf_region
    name        = var.gcf_name
    project     = var.gcf_project_id  
    
    build_config {
        entry_point = var.gcf_entry_point 
        runtime     = var.gcf_runtime
        
        source {
            storage_source {
                bucket = google_storage_bucket.chicago_data_ingestion_workflow_bucket.name
                object = google_storage_bucket_object.chicago_data_ingestion_object.name
            }
        }
    }
    
    service_config {
        all_traffic_on_latest_revision = true
        available_memory               = var.gcf_memory
        ingress_settings               = var.gcf_ingress_settings
        timeout_seconds                = var.gcf_timeout 
        available_cpu                  = var.gcf_cpu  
        service_account_email          = var.gcf_service_account
        
        environment_variables          = {
            ENVIRONMENT        = var.gcf_environment
            WORKFLOW_ID        = var.gcf_downstream_workflow_id
            DATE_RANGE         = local.backfill_range
            APP_TOKEN_SECRET   = local.socrata_app_token
        }
    }
    
    depends_on = [ 
		google_storage_bucket_object.chicago_data_ingestion_object 
	]
}

/** 
 * This is the IAM role for the service account that will invoke the cloud function. 
 * The service account is the one with which the Cloud Scheduler resource is deployed. 
 * This role is required to allow the Cloud Scheduler to invoke the cloud function.
*/
resource  "google_cloudfunctions2_function_iam_member" "scheduler_invoker_iam_attachment" {
    project                      = google_cloudfunctions2_function.chicago_data_ingestion.project
    location                     = google_cloudfunctions2_function.chicago_data_ingestion.location
    cloud_function               = google_cloudfunctions2_function.chicago_data_ingestion.name
    role                         = var.gcf_invoker_service_account_role
    member                       = "serviceAccount:${var.gcf_invoker_service_account_name}@${var.gcf_project_id}.iam.gserviceaccount.com"
    depends_on                   = [ 
        google_cloudfunctions2_function.chicago_data_ingestion
    ]
}
