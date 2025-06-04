# Output values for the GCP infrastructure

output "project_info" {
  description = "Project information"
  value = {
    project_id  = var.project_id
    region      = var.region
    environment = var.environment
  }
}

output "networking" {
  description = "Networking endpoints"
  value = {
    cloud_run_url    = google_cloud_run_service.backend.status[0].url
    cdn_ip_address   = google_compute_global_address.cdn_ip.address
    cdn_domain       = var.environment == "prod" ? "cdn.${var.domain_name}" : "cdn-${var.environment}.${var.domain_name}"
  }
}

output "storage" {
  description = "Storage bucket information"
  value = {
    video_upload_bucket    = google_storage_bucket.video_uploads.name
    video_processed_bucket = google_storage_bucket.video_processed.name
    upload_bucket_url      = google_storage_bucket.video_uploads.url
    processed_bucket_url   = google_storage_bucket.video_processed.url
  }
}

output "database" {
  description = "Database connection information"
  value = {
    connection_name = google_sql_database_instance.main.connection_name
    instance_name   = google_sql_database_instance.main.name
    database_version = google_sql_database_instance.main.database_version
    public_ip       = google_sql_database_instance.main.public_ip_address
  }
  sensitive = false
}

output "service_accounts" {
  description = "Service account information"
  value = {
    cloudrun = {
      email = google_service_account.cloudrun_sa.email
      name  = google_service_account.cloudrun_sa.name
    }
    video_processor = {
      email = google_service_account.video_processor_sa.email
      name  = google_service_account.video_processor_sa.name
    }
    client = {
      email = google_service_account.client_sa.email
      name  = google_service_account.client_sa.name
    }
  }
}

output "secrets" {
  description = "Secret Manager secret information"
  value = {
    db_password = {
      name = google_secret_manager_secret.db_password.secret_id
      id   = google_secret_manager_secret.db_password.id
    }
    jwt_secret = {
      name = google_secret_manager_secret.jwt_secret.secret_id
      id   = google_secret_manager_secret.jwt_secret.id
    }
  }
}

output "cloud_functions" {
  description = "Cloud Functions information"
  value = {
    video_processor = {
      name         = google_cloudfunctions_function.video_processor.name
      trigger_url  = google_cloudfunctions_function.video_processor.https_trigger_url
      source_bucket = google_cloudfunctions_function.video_processor.source_archive_bucket
    }
  }
}

output "enabled_apis" {
  description = "List of enabled APIs"
  value = [
    for api in google_project_service.apis : api.service
  ]
}

# Sensitive outputs (for CI/CD use)
output "database_password" {
  description = "Database password (sensitive)"
  value       = random_password.db_password.result
  sensitive   = true
}

output "jwt_secret" {
  description = "JWT secret (sensitive)"
  value       = random_password.jwt_secret.result
  sensitive   = true
}
