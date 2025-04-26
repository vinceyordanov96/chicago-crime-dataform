output "gcf_name" {
    value = google_cloudfunctions2_function.chicago_data_ingestion.name
}
output "gcf_trigger_url" {
    value = google_cloudfunctions2_function.chicago_data_ingestion.url
    description = "The HTTPS trigger URL of the Cloud Function"
}
