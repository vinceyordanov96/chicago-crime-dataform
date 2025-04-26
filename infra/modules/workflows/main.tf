resource "google_workflows_workflow" "pipeline_orchestration_workflow" {
    project         = var.workflow_project_id
    name            = var.workflow_name
    region          = var.workflow_region
    description     = var.workflow_description
    service_account = var.workflow_service_account
    source_contents = templatefile("${path.module}/../../../orchestration/pipeline.yaml", {})
}
