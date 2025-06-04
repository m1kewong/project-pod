# Variables for the GCP infrastructure
variable "project_id" {
  description = "The GCP project ID"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "asia-east1"
  validation {
    condition = contains([
      "asia-east1", "asia-east2", "asia-northeast1", "asia-northeast2", "asia-northeast3",
      "asia-south1", "asia-southeast1", "asia-southeast2", "australia-southeast1",
      "europe-north1", "europe-west1", "europe-west2", "europe-west3", "europe-west4", "europe-west6",
      "northamerica-northeast1", "us-central1", "us-east1", "us-east4", "us-west1", "us-west2", "us-west3", "us-west4"
    ], var.region)
    error_message = "Region must be a valid GCP region."
  }
}

variable "environment" {
  description = "The deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "domain_name" {
  description = "The domain name for the application"
  type        = string
  default     = "genz-video.app"
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for critical resources"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain database backups"
  type        = number
  default     = 30
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "Backup retention days must be between 1 and 365."
  }
}

variable "max_scale" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 100
  validation {
    condition     = var.max_scale >= 1 && var.max_scale <= 1000
    error_message = "Max scale must be between 1 and 1000."
  }
}

variable "db_tier" {
  description = "The machine type for the database instance"
  type        = string
  default     = "db-f1-micro"
  validation {
    condition = contains([
      "db-f1-micro", "db-g1-small", "db-n1-standard-1", "db-n1-standard-2", 
      "db-n1-standard-4", "db-n1-standard-8", "db-n1-standard-16",
      "db-custom-1-3840", "db-custom-2-4096", "db-custom-4-8192"
    ], var.db_tier)
    error_message = "DB tier must be a valid Cloud SQL machine type."
  }
}

variable "enable_monitoring" {
  description = "Enable monitoring and alerting"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable structured logging"
  type        = bool
  default     = true
}
