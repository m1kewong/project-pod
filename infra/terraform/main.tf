# Configure Terraform
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Configure the Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Define variables
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "asia-east1"  # Taiwan region for APAC focus
}

variable "environment" {
  description = "The deployment environment (dev, prod)"
  type        = string
  default     = "dev"
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "cloudrun.googleapis.com",
    "firestore.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "cloudfunctions.googleapis.com",
    "transcoder.googleapis.com",
    "cloudbuild.googleapis.com",
    "firebase.googleapis.com",
    "compute.googleapis.com",
    "cloudcdn.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com"
  ])
  
  project = var.project_id
  service = each.value
  
  disable_dependent_services = true
  disable_on_destroy         = false
}

# Service Account for Cloud Run
resource "google_service_account" "cloudrun_sa" {
  account_id   = "${var.environment}-cloudrun-sa"
  display_name = "Cloud Run Service Account - ${var.environment}"
  description  = "Service account for Cloud Run services"
}

# Service Account for video processing
resource "google_service_account" "video_processor_sa" {
  account_id   = "${var.environment}-video-processor-sa"
  display_name = "Video Processor Service Account - ${var.environment}"
  description  = "Service account for video processing functions"
}

# Service Account for client applications
resource "google_service_account" "client_sa" {
  account_id   = "${var.environment}-client-sa"
  display_name = "Client Service Account - ${var.environment}"
  description  = "Service account for client applications"
}

# IAM roles for Cloud Run service account
resource "google_project_iam_member" "cloudrun_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

resource "google_project_iam_member" "cloudrun_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

resource "google_project_iam_member" "cloudrun_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

resource "google_project_iam_member" "cloudrun_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

# IAM roles for video processor service account
resource "google_project_iam_member" "video_processor_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.video_processor_sa.email}"
}

resource "google_project_iam_member" "video_processor_transcoder_user" {
  project = var.project_id
  role    = "roles/transcoder.admin"
  member  = "serviceAccount:${google_service_account.video_processor_sa.email}"
}

resource "google_project_iam_member" "video_processor_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.video_processor_sa.email}"
}

# IAM roles for client service account
resource "google_project_iam_member" "client_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.client_sa.email}"
}

resource "google_project_iam_member" "client_firebase_user" {
  project = var.project_id
  role    = "roles/firebase.developAdmin"
  member  = "serviceAccount:${google_service_account.client_sa.email}"
}

# Secret Manager for sensitive configuration
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.environment}-db-password"
  
  replication {
    automatic = true
  }
  
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "${var.environment}-jwt-secret"
  
  replication {
    automatic = true
  }
  
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "jwt_secret" {
  secret      = google_secret_manager_secret.jwt_secret.id
  secret_data = random_password.jwt_secret.result
}

# Generate random passwords
resource "random_password" "jwt_secret" {
  length  = 32
  special = true
}

# Cloud Storage buckets for video storage
resource "google_storage_bucket" "video_uploads" {
  name          = "${var.project_id}-${var.environment}-video-uploads"
  location      = var.region
  force_destroy = var.environment == "dev" ? true : false
  
  uniform_bucket_level_access = true
  
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
  
  lifecycle_rule {
    condition {
      age = var.environment == "dev" ? 30 : 365
    }
    action {
      type = "Delete"
    }
  }
  
  depends_on = [google_project_service.apis]
}

resource "google_storage_bucket" "video_processed" {
  name          = "${var.project_id}-${var.environment}-video-processed"
  location      = var.region
  force_destroy = var.environment == "dev" ? true : false
  
  uniform_bucket_level_access = true
  
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
  
  lifecycle_rule {
    condition {
      age = var.environment == "dev" ? 90 : 730
    }
    action {
      type = "Delete"
    }
  }
  
  depends_on = [google_project_service.apis]
}

# Cloud CDN for video delivery
resource "google_compute_global_address" "cdn_ip" {
  name = "${var.environment}-cdn-ip"
}

resource "google_compute_backend_bucket" "video_backend" {
  name        = "${var.environment}-video-backend"
  bucket_name = google_storage_bucket.video_processed.name
  enable_cdn  = true
  
  cdn_policy {
    cache_mode                   = "CACHE_ALL_STATIC"
    default_ttl                  = 3600
    max_ttl                      = 86400
    negative_caching             = true
    negative_caching_policy {
      code = 404
      ttl  = 120
    }
  }
}

resource "google_compute_url_map" "cdn_url_map" {
  name            = "${var.environment}-cdn-url-map"
  default_service = google_compute_backend_bucket.video_backend.id
}

resource "google_compute_target_https_proxy" "cdn_proxy" {
  name             = "${var.environment}-cdn-proxy"
  url_map          = google_compute_url_map.cdn_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.cdn_cert.id]
}

resource "google_compute_managed_ssl_certificate" "cdn_cert" {
  name = "${var.environment}-cdn-cert"
  
  managed {
    domains = [var.environment == "prod" ? "cdn.genz-video.app" : "cdn-dev.genz-video.app"]
  }
}

resource "google_compute_global_forwarding_rule" "cdn_forwarding_rule" {
  name                  = "${var.environment}-cdn-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  target                = google_compute_target_https_proxy.cdn_proxy.id
  ip_address            = google_compute_global_address.cdn_ip.id
}

# Cloud SQL instance for PostgreSQL
resource "google_sql_database_instance" "main" {
  name             = "${var.project_id}-${var.environment}-db"
  database_version = "POSTGRES_13"
  region           = var.region
    settings {
    tier = var.db_tier
    
    backup_configuration {
      enabled                        = var.environment == "prod" ? true : false
      start_time                     = "02:00"
      point_in_time_recovery_enabled = var.environment == "prod" ? true : false
      backup_retention_settings {
        retained_backups = var.backup_retention_days
      }
    }
    
    ip_configuration {
      ipv4_enabled    = true
      require_ssl     = true
      authorized_networks {
        name  = "allow-cloud-run"
        value = "0.0.0.0/0"
      }
    }
    
    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }
    
    database_flags {
      name  = "log_connections"
      value = "on"
    }
    
    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }
  }
  
  deletion_protection = var.enable_deletion_protection
  
  depends_on = [google_project_service.apis]
}

# Cloud Run service for backend
resource "google_cloud_run_service" "backend" {
  name     = "${var.project_id}-${var.environment}-backend"
  location = var.region
  
  template {    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"         = tostring(var.max_scale)
        "run.googleapis.com/cloudsql-instances"    = google_sql_database_instance.main.connection_name
        "run.googleapis.com/execution-environment" = "gen2"
        "run.googleapis.com/vpc-access-connector"  = ""
      }
    }
    
    spec {
      service_account_name = google_service_account.cloudrun_sa.email
      
      containers {
        image = "gcr.io/${var.project_id}/genz-video-app-${var.environment}:latest"
        
        env {
          name  = "ENVIRONMENT"
          value = var.environment
        }
        
        env {
          name  = "DATABASE_URL"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.db_password.secret_id
              key  = "latest"
            }
          }
        }
        
        env {
          name  = "JWT_SECRET"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.jwt_secret.secret_id
              key  = "latest"
            }
          }
        }
          resources {
          limits = {
            cpu    = var.environment == "dev" ? "1000m" : "2000m"
            memory = var.environment == "dev" ? "512Mi" : "2Gi"
          }
          requests = {
            cpu    = var.environment == "dev" ? "100m" : "200m"
            memory = var.environment == "dev" ? "128Mi" : "256Mi"
          }
        }
        
        ports {
          container_port = 8080
        }
      }
    }
  }
  
  traffic {
    percent         = 100
    latest_revision = true
  }
  
  depends_on = [google_project_service.apis]
}

# Allow unauthenticated access to Cloud Run
resource "google_cloud_run_service_iam_member" "backend_invoker" {
  location = google_cloud_run_service.backend.location
  project  = google_cloud_run_service.backend.project
  service  = google_cloud_run_service.backend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Generate a random password for the database
resource "random_password" "db_password" {
  length  = 16
  special = false
}

# Create a database user
resource "google_sql_user" "users" {
  name     = "postgres"
  instance = google_sql_database_instance.main.name
  password = random_password.db_password.result
}

# Cloud Function for video processing
resource "google_cloudfunctions_function" "video_processor" {
  name        = "${var.environment}-video-processor"
  description = "Process uploaded videos"
  runtime     = "nodejs18"
  
  available_memory_mb   = var.environment == "dev" ? 512 : 2048
  source_archive_bucket = google_storage_bucket.video_uploads.name
  source_archive_object = "video-processor.zip"
  trigger {
    event_type = "google.storage.object.finalize"
    resource   = google_storage_bucket.video_uploads.name
  }
  entry_point = "processVideo"
  
  service_account_email = google_service_account.video_processor_sa.email
  
  environment_variables = {
    ENVIRONMENT = var.environment
    OUTPUT_BUCKET = google_storage_bucket.video_processed.name
  }
  
  depends_on = [google_project_service.apis]
}

# Outputs
output "cloud_run_url" {
  value       = google_cloud_run_service.backend.status[0].url
  description = "URL of the deployed Cloud Run service"
}

output "video_upload_bucket" {
  value       = google_storage_bucket.video_uploads.name
  description = "Name of the video upload bucket"
}

output "video_processed_bucket" {
  value       = google_storage_bucket.video_processed.name
  description = "Name of the processed video bucket"
}

output "database_connection_name" {
  value       = google_sql_database_instance.main.connection_name
  description = "Connection name for the Cloud SQL instance"
}

output "cdn_ip_address" {
  value       = google_compute_global_address.cdn_ip.address
  description = "IP address of the CDN"
}

output "service_account_emails" {
  value = {
    cloudrun        = google_service_account.cloudrun_sa.email
    video_processor = google_service_account.video_processor_sa.email
    client          = google_service_account.client_sa.email
  }
  description = "Email addresses of all service accounts"
}

output "secret_names" {
  value = {
    db_password = google_secret_manager_secret.db_password.secret_id
    jwt_secret  = google_secret_manager_secret.jwt_secret.secret_id
  }
  description = "Names of all secrets in Secret Manager"
}

# Cloud Storage bucket IAM permissions
# Video uploads bucket - allow uploads from client and processing from video processor
resource "google_storage_bucket_iam_member" "video_uploads_client_write" {
  bucket = google_storage_bucket.video_uploads.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.client_sa.email}"
}

resource "google_storage_bucket_iam_member" "video_uploads_processor_read" {
  bucket = google_storage_bucket.video_uploads.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.video_processor_sa.email}"
}

resource "google_storage_bucket_iam_member" "video_uploads_processor_delete" {
  bucket = google_storage_bucket.video_uploads.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.video_processor_sa.email}"
}

# Video processed bucket - allow writes from video processor, public reads
resource "google_storage_bucket_iam_member" "video_processed_processor_write" {
  bucket = google_storage_bucket.video_processed.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.video_processor_sa.email}"
}

resource "google_storage_bucket_iam_member" "video_processed_public_read" {
  bucket = google_storage_bucket.video_processed.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Allow CloudRun service to access both buckets for serving
resource "google_storage_bucket_iam_member" "video_uploads_cloudrun_read" {
  bucket = google_storage_bucket.video_uploads.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

resource "google_storage_bucket_iam_member" "video_processed_cloudrun_read" {
  bucket = google_storage_bucket.video_processed.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}
