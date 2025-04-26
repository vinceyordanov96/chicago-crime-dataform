resource "google_cloud_scheduler_job" "workflow_trigger" {
    
    project     = var.scheduler_project_id
    name        = var.scheduler_name
    description = var.scheduler_description
    schedule    = var.scheduler_frequency
    time_zone   = var.scheduler_time_zone
    region      = var.scheduler_region 
    paused      = true

    http_target {
        http_method = var.scheduler_http_method
        uri         = var.scheduler_target_audience
        body        = base64encode(jsonencode({run_type = "daily"}))
        headers     = { 
                "Content-Type" : "application/json", 
                "User-Agent" : "Google-Cloud-Scheduler" 
        }
        oidc_token {
            service_account_email = var.scheduler_service_account
            audience              = var.scheduler_target_audience
        }
    }
}
