# Project Pod Infrastructure Quick Start Guide

This guide will help you provision the GCP infrastructure for the Project Pod video social platform.

## Prerequisites

1. **Google Cloud SDK installed and authenticated**
   ```powershell
   gcloud auth login
   gcloud auth application-default login
   ```

2. **Projects created** (already done):
   - Development: `project-pod-dev`
   - Production: `project-pod-prod-321482774`

## Quick Start

### 1. Navigate to the infra directory
```powershell
cd C:\Users\m1ke\OneDrive\Documents\Repo\project-pod\infra
```

### 2. Run the provisioning script

**For Development Environment:**
```powershell
.\provision-infrastructure.ps1 -Environment dev
```

**For Production Environment:**
```powershell
.\provision-infrastructure.ps1 -Environment prod
```

**With Billing (if you have a billing account):**
```powershell
.\provision-infrastructure.ps1 -Environment dev -EnableBilling -BillingAccountId "YOUR-BILLING-ACCOUNT-ID"
```

**Dry Run (to see what would be created):**
```powershell
.\provision-infrastructure.ps1 -Environment dev -DryRun
```

### 3. Test the infrastructure
```powershell
.\test-pod-infrastructure.ps1 -Environment dev
```

## Configuration

The `config.env` file contains all the configuration variables:

```bash
# Development Environment
DEV_PROJECT_ID=project-pod-dev
DEV_PROJECT_NUMBER=56249782826

# Production Environment  
PROD_PROJECT_ID=project-pod-prod-321482774
PROD_PROJECT_NUMBER=814348847069

# Common Configuration
REGION=asia-east1
ZONE=asia-east1-a
```

## What Gets Provisioned

### APIs Enabled
- Cloud Build
- Cloud Run
- Firestore
- Cloud Storage
- Cloud Functions
- Transcoder API
- Firebase
- Secret Manager
- Artifact Registry

### Service Accounts Created
- `backend-service` - For Cloud Run backend API
- `functions-service` - For Cloud Functions
- `storage-service` - For Cloud Storage operations
- `transcoder-service` - For video transcoding

### Storage Buckets Created
- `{project-id}-uploads` - Private bucket for video uploads
- `{project-id}-public-videos` - Public bucket for transcoded videos
- `{project-id}-thumbnails` - Public bucket for video thumbnails

### Other Resources
- Firestore database
- Artifact Registry repository
- Secret Manager secrets (with placeholder values)

## Next Steps After Provisioning

1. **Setup Firebase Console**
   - Visit: https://console.firebase.google.com/project/project-pod-dev
   - Enable Authentication, Firestore, Storage, and Hosting

2. **Update Secrets**
   ```powershell
   # Update with actual values
   echo "your-actual-jwt-secret" | gcloud secrets versions add jwt-secret --data-file=-
   echo "your-firebase-database-url" | gcloud secrets versions add database-url --data-file=-
   ```

3. **Deploy Backend API** (when ready)
   ```powershell
   cd ../server
   # Build and deploy your Node.js/TypeScript API to Cloud Run
   ```

4. **Deploy Cloud Functions** (when ready)
   ```powershell
   # Deploy video transcoding functions
   ```

5. **Configure Firestore Security Rules**
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // Add your security rules here
     }
   }
   ```

## Troubleshooting

### Common Issues

1. **Billing not enabled**
   - Some APIs require billing to be enabled
   - Add `-EnableBilling -BillingAccountId "YOUR-ID"` to the provision script

2. **Permission denied**
   - Make sure you're authenticated: `gcloud auth login`
   - Check you have the necessary IAM roles in your GCP organization

3. **API not enabled**
   - Run the provision script again, it will attempt to enable missing APIs

4. **Resource already exists**
   - The scripts handle existing resources gracefully
   - Check the test script output to see current status

### Getting Help

- Check the test script output: `.\test-pod-infrastructure.ps1`
- View GCP Console: https://console.cloud.google.com/
- Check logs: `gcloud logging read "resource.type=global"`

## Project Structure

```
project-pod/
├── infra/
│   ├── config.env                    # Configuration variables
│   ├── provision-infrastructure.ps1  # Main provisioning script
│   ├── test-pod-infrastructure.ps1   # Infrastructure testing
│   └── QUICKSTART.md                 # This guide
├── client/                           # Flutter mobile app
├── server/                           # Backend API
└── functions/                        # Cloud Functions
```
