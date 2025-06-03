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
    "firebase.googleapis.com"
  ])
  
  project = var.project_id
  service = each.value
  
  disable_dependent_services = true
  disable_on_destroy         = false
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
  
  depends_on = [google_project_service.apis]
}

# Cloud SQL instance for PostgreSQL
resource "google_sql_database_instance" "main" {
  name             = "${var.project_id}-${var.environment}-db"
  database_version = "POSTGRES_13"
  region           = var.region
  
  settings {
    tier = var.environment == "dev" ? "db-f1-micro" : "db-custom-2-4096"
    
    backup_configuration {
      enabled            = var.environment == "prod" ? true : false
      start_time         = "02:00"
      point_in_time_recovery_enabled = var.environment == "prod" ? true : false
    }
  }
  
  deletion_protection = var.environment == "prod" ? true : false
  
  depends_on = [google_project_service.apis]
}

# Cloud Run service for backend
resource "google_cloud_run_service" "backend" {
  name     = "${var.project_id}-${var.environment}-backend"
  location = var.region
  
  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/genz-video-app-${var.environment}:latest"
        
        env {
          name  = "ENVIRONMENT"
          value = var.environment
        }
        
        env {
          name  = "DATABASE_URL"
          value = "postgresql://postgres:${random_password.db_password.result}@/postgres?host=/cloudsql/${google_sql_database_instance.main.connection_name}"
        }
        
        resources {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
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

# Outputs
output "cloud_run_url" {
  value = google_cloud_run_service.backend.status[0].url
}

output "video_upload_bucket" {
  value = google_storage_bucket.video_uploads.name
}

output "video_processed_bucket" {
  value = google_storage_bucket.video_processed.name
}

output "database_connection_name" {
  value = google_sql_database_instance.main.connection_name
}
