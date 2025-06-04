# Infrastructure - Gen Z Social Video Platform

This directory contains the complete Infrastructure as Code (IaC) setup for the Gen Z Social Video Platform using Google Cloud Platform (GCP) and Terraform.

## 🏗️ Architecture Overview

The infrastructure includes:

- **Cloud Run**: Serverless backend services
- **Cloud SQL**: PostgreSQL database for structured data
- **Firestore**: NoSQL database for real-time features and user data
- **Cloud Storage**: Video file storage with lifecycle management
- **Cloud CDN**: Global content delivery network for video streaming
- **Cloud Functions**: Video processing and transcoding
- **Firebase**: Authentication and client-side services
- **Secret Manager**: Secure secrets and configuration management
- **IAM**: Service accounts with least-privilege access

## 📋 Prerequisites

1. **Google Cloud SDK**
   ```powershell
   # Install gcloud CLI
   # Download from: https://cloud.google.com/sdk/docs/install
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```

2. **Terraform**
   ```powershell
   # Install Terraform
   # Download from: https://www.terraform.io/downloads
   terraform version
   ```

3. **PowerShell** (Windows) or **Bash** (Linux/macOS)

## 🚀 Quick Start

### 1. Bootstrap GCP Projects

First, create and configure the GCP projects:

```powershell
# Run the bootstrap script to create projects and enable APIs
.\bootstrap.ps1

# Follow the prompts to enter your billing account ID
```

This script will:
- Create dev, staging, and prod GCP projects
- Enable all required APIs
- Set up billing
- Create service accounts with proper IAM roles
- Generate service account keys for Terraform

### 2. Deploy Infrastructure

Deploy to development environment:

```powershell
# Plan the deployment
.\deploy.ps1 dev plan

# Apply the changes
.\deploy.ps1 dev apply
```

Deploy to other environments:

```powershell
# Staging
.\deploy.ps1 staging apply

# Production
.\deploy.ps1 prod apply
```

### 3. Verify Deployment

Test the infrastructure:

```powershell
# Run comprehensive infrastructure tests
.\test-infrastructure.ps1 dev
```

## 📁 Directory Structure

```
infra/
├── terraform/
│   ├── main.tf          # Main Terraform configuration
│   ├── variables.tf     # Variable definitions
│   ├── outputs.tf       # Output values
│   ├── dev.tfvars      # Development environment config
│   ├── staging.tfvars  # Staging environment config
│   └── prod.tfvars     # Production environment config
├── bootstrap.ps1       # GCP project bootstrap script
├── deploy.ps1         # Infrastructure deployment script
├── deploy.sh          # Infrastructure deployment script (bash)
├── test-infrastructure.ps1  # Infrastructure testing script
├── cloudbuild.yaml    # CI/CD configuration
└── README.md          # This file
```

## 🔧 Configuration

### Environment Variables

Each environment is configured through `.tfvars` files:

**Development** (`dev.tfvars`):
- Minimal resources for cost optimization
- Deletion protection disabled
- 7-day backup retention

**Staging** (`staging.tfvars`):
- Mid-tier resources for realistic testing
- Deletion protection disabled
- 14-day backup retention

**Production** (`prod.tfvars`):
- High-performance resources
- Deletion protection enabled
- 30-day backup retention

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `project_id` | GCP project ID | Required |
| `region` | GCP region | `asia-east1` |
| `environment` | Environment name | `dev` |
| `domain_name` | Application domain | `genz-video.app` |
| `db_tier` | Database machine type | `db-f1-micro` |
| `max_scale` | Max Cloud Run instances | `100` |
| `backup_retention_days` | Database backup retention | `30` |

## 🛠️ Manual Commands

### Terraform Operations

```powershell
cd terraform

# Initialize Terraform
terraform init

# Create/select workspace
terraform workspace new dev
terraform workspace select dev

# Plan deployment
terraform plan -var-file=dev.tfvars

# Apply changes
terraform apply -var-file=dev.tfvars

# Show outputs
terraform output

# Destroy (development only!)
terraform destroy -var-file=dev.tfvars
```

### GCP Operations

```powershell
# Set active project
gcloud config set project genz-video-app-dev

# List enabled APIs
gcloud services list --enabled

# Check service accounts
gcloud iam service-accounts list

# List storage buckets
gsutil ls

# Check Cloud Run services
gcloud run services list --region=asia-east1

# View secrets
gcloud secrets list
```

## 🔐 Security

### Service Accounts

The infrastructure creates three service accounts with minimal required permissions:

1. **Cloud Run Service Account** (`{env}-cloudrun-sa`):
   - `roles/cloudsql.client` - Database access
   - `roles/storage.admin` - Storage bucket access
   - `roles/datastore.user` - Firestore access
   - `roles/secretmanager.secretAccessor` - Secrets access

2. **Video Processor Service Account** (`{env}-video-processor-sa`):
   - `roles/storage.admin` - Storage bucket access
   - `roles/transcoder.admin` - Video transcoding
   - `roles/datastore.user` - Firestore access

3. **Client Service Account** (`{env}-client-sa`):
   - `roles/storage.objectViewer` - Read-only storage access
   - `roles/firebase.developAdmin` - Firebase access

### Secrets Management

Sensitive data is stored in Secret Manager:
- Database passwords
- JWT secrets
- API keys (added as needed)

### Network Security

- Cloud SQL requires SSL connections
- Storage buckets use IAM-based access
- Cloud Run services use service accounts
- CORS policies configured for web clients

## 📊 Monitoring and Logging

The infrastructure includes:

- **Cloud Monitoring**: Automatic metrics collection
- **Cloud Logging**: Structured application logs
- **Error Reporting**: Automatic error tracking
- **Cloud Trace**: Request tracing (when enabled)

Access monitoring:
```powershell
# View logs
gcloud logging read "resource.type=cloud_run_revision"

# Check metrics in Cloud Console
open https://console.cloud.google.com/monitoring
```

## 🧪 Testing

### Automated Tests

The `test-infrastructure.ps1` script validates:

✅ Terraform state consistency  
✅ Required APIs enabled  
✅ Service accounts created  
✅ Storage buckets configured  
✅ Cloud SQL instance running  
✅ Cloud Run services deployed  
✅ Secret Manager configured  
✅ IAM permissions correct  

### Manual Verification

1. **Cloud Run Health Check**:
   ```powershell
   # Get Cloud Run URL
   $url = terraform output -raw cloud_run_url
   # Test endpoint
   Invoke-RestMethod "$url/health"
   ```

2. **Database Connectivity**:
   ```powershell
   # Connect using Cloud SQL Proxy
   gcloud sql connect genz-video-app-dev-db --user=postgres
   ```

3. **Storage Access**:
   ```powershell
   # Upload test file
   echo "test" > test.txt
   gsutil cp test.txt gs://genz-video-app-dev-video-uploads/
   ```

## 🔄 CI/CD Integration

The infrastructure supports automated deployment through Cloud Build:

```yaml
# .github/workflows/deploy.yml
- name: Deploy Infrastructure
  run: |
    gcloud auth activate-service-account --key-file=key.json
    ./deploy.ps1 ${{ env.ENVIRONMENT }} apply
```

### Service Account Keys

Store the generated service account keys as GitHub Secrets:
- `GCP_DEV_SA_KEY` - Development service account
- `GCP_STAGING_SA_KEY` - Staging service account  
- `GCP_PROD_SA_KEY` - Production service account

## 📚 Troubleshooting

### Common Issues

1. **API Not Enabled**:
   ```powershell
   gcloud services enable cloudrun.googleapis.com
   ```

2. **Billing Not Configured**:
   ```powershell
   gcloud billing projects link PROJECT_ID --billing-account=BILLING_ID
   ```

3. **Permission Denied**:
   ```powershell
   gcloud projects add-iam-policy-binding PROJECT_ID --member=user:EMAIL --role=roles/editor
   ```

4. **Terraform State Lock**:
   ```powershell
   terraform force-unlock LOCK_ID
   ```

### Logs and Debugging

```powershell
# Terraform debugging
export TF_LOG=DEBUG
terraform apply

# GCP API debugging
gcloud logging read "resource.type=gce_instance" --limit=10

# Cloud Run logs
gcloud run services logs read SERVICE_NAME --region=asia-east1
```

## 💰 Cost Optimization

### Development Environment
- Uses minimal instance sizes
- Automatic resource cleanup
- Short backup retention

### Production Environment
- Optimized for performance and reliability
- Longer backup retention
- Higher availability configurations

### Cost Monitoring
```powershell
# Check current costs
gcloud billing budgets list

# View cost breakdown
# Use Cloud Console Billing reports
```

## 🔄 Backup and Disaster Recovery

### Database Backups
- Automatic daily backups
- Point-in-time recovery (production)
- Cross-region backup storage (production)

### Storage Backup
- Lifecycle policies for automatic cleanup
- Versioning enabled on critical buckets
- Cross-region replication (production)

### Infrastructure Backup
- Terraform state stored in Cloud Storage
- Infrastructure configuration in Git
- Service account keys securely stored

## 📞 Support

For infrastructure issues:

1. Check the testing script output
2. Review GCP Cloud Console for resource status
3. Check Terraform state for inconsistencies
4. Review logs in Cloud Logging

## 🔗 References

- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GCP Best Practices](https://cloud.google.com/docs/enterprise/best-practices-for-enterprise-organizations)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud SQL Best Practices](https://cloud.google.com/sql/docs/postgres/best-practices)
