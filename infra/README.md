# Infrastructure - Deployment and Configuration

This directory contains the infrastructure as code and deployment configurations for the Gen Z Social Video Platform.

## Components

- Google Cloud Platform (GCP) infrastructure setup
- Terraform scripts for infrastructure provisioning
- Cloud Build configuration for CI/CD
- Kubernetes configurations (if needed in the future)
- Docker configurations

## Setup

1. Install Google Cloud SDK
2. Install Terraform
3. Configure GCP authentication:
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

4. Initialize Terraform:
```bash
cd terraform
terraform init
```

## Infrastructure Components

- **Cloud Run**: Hosting for the backend services
- **Cloud SQL**: PostgreSQL database for structured data
- **Firestore**: NoSQL database for real-time features
- **Cloud Storage**: Storage for video files and assets
- **Firebase**: Authentication and client-side services
- **Cloud CDN**: Content delivery network for video streaming
- **Transcoder API**: Video processing and transcoding

## Deployment Instructions

### Development Environment

```bash
cd terraform
terraform workspace select dev
terraform apply -var-file=dev.tfvars
```

### Production Environment

```bash
cd terraform
terraform workspace select prod
terraform apply -var-file=prod.tfvars
```

## Security Guidelines

- Follow the principle of least privilege for IAM roles
- Store secrets in Secret Manager, not in code
- Use service accounts with minimal permissions
- Enable audit logging for all services
- Set up monitoring and alerting for security events
