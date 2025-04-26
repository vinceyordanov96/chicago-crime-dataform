resource "google_bigquery_dataset" "raw" {
	project 	= var.bq_project_id
	dataset_id 	= var.bq_raw_dataset_id
	location 	= var.bq_region
}
resource "google_bigquery_dataset" "staging" {
    project 	= var.bq_project_id
    dataset_id 	= var.bq_staging_dataset_id
    location 	= var.bq_region
}
resource "google_bigquery_dataset" "lookup" {
    project 	= var.bq_project_id
    dataset_id 	= var.bq_lookup_dataset_id
    location 	= var.bq_region
}


resource "google_bigquery_table" "lookup_table" {
    dataset_id          = google_bigquery_dataset.lookup.dataset_id
    project             = var.bq_project_id
    table_id            = var.bq_table_id_lookup
    deletion_protection = var.bq_deletion_protection
    schema              = file("${path.module}/schemas/lookup.json")
    depends_on  = [
        google_bigquery_dataset.lookup,
    ]
}

resource "google_bigquery_table" "raw_table" {
    
    dataset_id          = google_bigquery_dataset.raw.dataset_id
    project             = var.bq_project_id
    table_id            = var.bq_table_id_raw
    deletion_protection = var.bq_deletion_protection
    schema              = file("${path.module}/schemas/raw.json")
    
    time_partitioning {
        type                    = var.bq_partition_type
        field                   = var.bq_partition_field  
        expiration_ms           = var.bq_partition_expiration_ms          
    }

    depends_on  = [
        google_bigquery_dataset.raw,
    ]
}
