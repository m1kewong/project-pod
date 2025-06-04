#!/usr/bin/env pwsh
# Project Pod GCP Infrastructure Provisioning Script
# This script provisions all required GCP infrastructure for the Project Pod video social platform

param(
    [string]$Environment = "dev",
    [string]$ProjectId = "",
    [switch]$EnableBilling = $false,
    [string]$BillingAccountId = "",
    [switch]$SkipFirebase = $false,
    [switch]$DryRun = $false
)

# Load configuration
$ConfigPath = Join-Path $PSScriptRoot "config.env"
if (Test-Path $ConfigPath) {
    Get-Content $ConfigPath | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            Set-Variable -Name $matches[1] -Value $matches[2] -Scope Script
        }
    }
}

# Set project based on environment
if ([string]::IsNullOrEmpty($ProjectId)) {
    if ($Environment -eq "prod") {
        $ProjectId = $PROD_PROJECT_ID
    } else {
        $ProjectId = $DEV_PROJECT_ID
    }
}

Write-Host "🚀 Starting Project Pod Infrastructure Provisioning" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host "Project ID: $ProjectId" -ForegroundColor Cyan
Write-Host "Region: $REGION" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "⚠️  DRY RUN MODE - No actual changes will be made" -ForegroundColor Yellow
}

# Function to run gcloud commands with error handling
function Invoke-GCloudCommand {
    param(
        [string]$Command,
        [string]$Description,
        [switch]$IgnoreError = $false
    )
    
    Write-Host "📋 $Description..." -ForegroundColor Blue
    
    if ($DryRun) {
        Write-Host "   [DRY RUN] Would execute: $Command" -ForegroundColor Yellow
        return $true
    }
    
    try {
        $result = Invoke-Expression $Command
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ Success" -ForegroundColor Green
            return $true
        } else {
            if ($IgnoreError) {
                Write-Host "   ⚠️  Warning: Command failed but continuing..." -ForegroundColor Yellow
                return $false
            } else {
                Write-Host "   ❌ Failed: $result" -ForegroundColor Red
                throw "Command failed: $Command"
            }
        }
    } catch {
        if ($IgnoreError) {
            Write-Host "   ⚠️  Warning: $($_.Exception.Message)" -ForegroundColor Yellow
            return $false
        } else {
            Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    }
}

# Step 1: Set the project
Write-Host "`n🎯 Step 1: Setting up project context" -ForegroundColor Magenta
Invoke-GCloudCommand "gcloud config set project $ProjectId" "Setting active project to $ProjectId"

# Step 2: Enable billing (if specified)
if ($EnableBilling -and -not [string]::IsNullOrEmpty($BillingAccountId)) {
    Write-Host "`n💳 Step 2: Enabling billing" -ForegroundColor Magenta
    Invoke-GCloudCommand "gcloud billing projects link $ProjectId --billing-account=$BillingAccountId" "Linking billing account"
} else {
    Write-Host "`n💳 Step 2: Skipping billing setup" -ForegroundColor Yellow
    Write-Host "   To enable billing later, run:" -ForegroundColor Gray
    Write-Host "   gcloud billing projects link $ProjectId --billing-account=YOUR-BILLING-ACCOUNT-ID" -ForegroundColor Gray
}

# Step 3: Enable required APIs
Write-Host "`n🔌 Step 3: Enabling required APIs" -ForegroundColor Magenta

$RequiredAPIs = @(
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "firestore.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "cloudfunctions.googleapis.com",
    "transcoder.googleapis.com",
    "cdn.googleapis.com",
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    "identitytoolkit.googleapis.com",
    "videointelligence.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iamcredentials.googleapis.com",
    "artifactregistry.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "secretmanager.googleapis.com"
)

foreach ($api in $RequiredAPIs) {
    Invoke-GCloudCommand "gcloud services enable $api --project=$ProjectId" "Enabling $api" -IgnoreError
}

# Step 4: Create service accounts
Write-Host "`n👤 Step 4: Creating service accounts" -ForegroundColor Magenta

$ServiceAccounts = @(
    @{
        Name = $SA_BACKEND
        DisplayName = "Backend API Service Account"
        Description = "Service account for Cloud Run backend API"
    },
    @{
        Name = $SA_FUNCTIONS
        DisplayName = "Cloud Functions Service Account"
        Description = "Service account for Cloud Functions"
    },
    @{
        Name = $SA_STORAGE
        DisplayName = "Storage Service Account"
        Description = "Service account for Cloud Storage operations"
    },
    @{
        Name = $SA_TRANSCODER
        DisplayName = "Transcoder Service Account"
        Description = "Service account for video transcoding operations"
    }
)

foreach ($sa in $ServiceAccounts) {
    Invoke-GCloudCommand "gcloud iam service-accounts create $($sa.Name) --display-name='$($sa.DisplayName)' --description='$($sa.Description)' --project=$ProjectId" "Creating service account: $($sa.Name)" -IgnoreError
}

# Step 5: Assign IAM roles
Write-Host "`n🔐 Step 5: Configuring IAM roles" -ForegroundColor Magenta

# Backend service account roles
$BackendRoles = @(
    "roles/firestore.user",
    "roles/storage.objectAdmin",
    "roles/cloudsql.client",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/cloudtrace.agent"
)

foreach ($role in $BackendRoles) {
    Invoke-GCloudCommand "gcloud projects add-iam-policy-binding $ProjectId --member='serviceAccount:$SA_BACKEND@$ProjectId.iam.gserviceaccount.com' --role='$role'" "Assigning $role to backend service account" -IgnoreError
}

# Functions service account roles
$FunctionRoles = @(
    "roles/storage.objectAdmin",
    "roles/firestore.user",
    "roles/transcoder.editor",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter"
)

foreach ($role in $FunctionRoles) {
    Invoke-GCloudCommand "gcloud projects add-iam-policy-binding $ProjectId --member='serviceAccount:$SA_FUNCTIONS@$ProjectId.iam.gserviceaccount.com' --role='$role'" "Assigning $role to functions service account" -IgnoreError
}

# Storage service account roles
$StorageRoles = @(
    "roles/storage.admin",
    "roles/firestore.user"
)

foreach ($role in $StorageRoles) {
    Invoke-GCloudCommand "gcloud projects add-iam-policy-binding $ProjectId --member='serviceAccount:$SA_STORAGE@$ProjectId.iam.gserviceaccount.com' --role='$role'" "Assigning $role to storage service account" -IgnoreError
}

# Transcoder service account roles
$TranscoderRoles = @(
    "roles/transcoder.admin",
    "roles/storage.objectAdmin",
    "roles/firestore.user"
)

foreach ($role in $TranscoderRoles) {
    Invoke-GCloudCommand "gcloud projects add-iam-policy-binding $ProjectId --member='serviceAccount:$SA_TRANSCODER@$ProjectId.iam.gserviceaccount.com' --role='$role'" "Assigning $role to transcoder service account" -IgnoreError
}

# Step 6: Create Cloud Storage buckets
Write-Host "`n🪣 Step 6: Creating Cloud Storage buckets" -ForegroundColor Magenta

$Buckets = @(
    @{
        Name = "$ProjectId-$BUCKET_UPLOADS"
        Location = $REGION
        StorageClass = "STANDARD"
        Public = $false
        Description = "Private bucket for video uploads"
    },
    @{
        Name = "$ProjectId-$BUCKET_PUBLIC"
        Location = $REGION
        StorageClass = "STANDARD"
        Public = $true
        Description = "Public bucket for transcoded videos"
    },
    @{
        Name = "$ProjectId-$BUCKET_THUMBNAILS"
        Location = $REGION
        StorageClass = "STANDARD"
        Public = $true
        Description = "Public bucket for video thumbnails"
    }
)

foreach ($bucket in $Buckets) {
    Invoke-GCloudCommand "gcloud storage buckets create gs://$($bucket.Name) --location=$($bucket.Location) --default-storage-class=$($bucket.StorageClass) --project=$ProjectId" "Creating bucket: $($bucket.Name)" -IgnoreError
    
    if ($bucket.Public) {
        Invoke-GCloudCommand "gcloud storage buckets add-iam-policy-binding gs://$($bucket.Name) --member=allUsers --role=roles/storage.objectViewer" "Making bucket public: $($bucket.Name)" -IgnoreError
    }
}

# Step 7: Setup Firestore
Write-Host "`n🔥 Step 7: Setting up Firestore" -ForegroundColor Magenta
Invoke-GCloudCommand "gcloud firestore databases create --location=$REGION --project=$ProjectId" "Creating Firestore database" -IgnoreError

# Step 8: Setup Artifact Registry
Write-Host "`n📦 Step 8: Setting up Artifact Registry" -ForegroundColor Magenta
Invoke-GCloudCommand "gcloud artifacts repositories create pod-docker-repo --repository-format=docker --location=$REGION --description='Docker repository for Project Pod' --project=$ProjectId" "Creating Docker repository" -IgnoreError

# Step 9: Setup Firebase (if not skipped)
if (-not $SkipFirebase) {
    Write-Host "`n🔥 Step 9: Setting up Firebase" -ForegroundColor Magenta
    Write-Host "   Note: Firebase setup requires manual configuration via Firebase Console" -ForegroundColor Yellow
    Write-Host "   Visit: https://console.firebase.google.com/project/$ProjectId" -ForegroundColor Cyan
    Write-Host "   Enable Authentication, Firestore, Storage, and Hosting" -ForegroundColor Cyan
} else {
    Write-Host "`n🔥 Step 9: Skipping Firebase setup" -ForegroundColor Yellow
}

# Step 10: Create initial secrets
Write-Host "`n🔒 Step 10: Creating Secret Manager secrets" -ForegroundColor Magenta

$Secrets = @(
    "jwt-secret",
    "database-url",
    "firebase-admin-key",
    "google-oauth-client-secret",
    "apple-auth-key"
)

foreach ($secret in $Secrets) {
    Invoke-GCloudCommand "echo 'CHANGE_ME' | gcloud secrets create $secret --data-file=- --project=$ProjectId" "Creating secret: $secret" -IgnoreError
}

# Step 11: Output summary
Write-Host "`n📋 Step 11: Infrastructure Summary" -ForegroundColor Magenta

if (-not $DryRun) {
    Write-Host "`n✅ Infrastructure provisioning completed!" -ForegroundColor Green
    Write-Host "`nProject Details:" -ForegroundColor Cyan
    Write-Host "  Project ID: $ProjectId" -ForegroundColor White
    Write-Host "  Environment: $Environment" -ForegroundColor White
    Write-Host "  Region: $REGION" -ForegroundColor White
    
    Write-Host "`nCreated Resources:" -ForegroundColor Cyan
    Write-Host "  ✓ Service Accounts: $($ServiceAccounts.Count)" -ForegroundColor Green
    Write-Host "  ✓ Storage Buckets: $($Buckets.Count)" -ForegroundColor Green
    Write-Host "  ✓ Secrets: $($Secrets.Count)" -ForegroundColor Green
    Write-Host "  ✓ APIs Enabled: $($RequiredAPIs.Count)" -ForegroundColor Green
    
    Write-Host "`nNext Steps:" -ForegroundColor Yellow
    Write-Host "  1. Configure Firebase via console: https://console.firebase.google.com/project/$ProjectId" -ForegroundColor Gray
    Write-Host "  2. Update secrets in Secret Manager with actual values" -ForegroundColor Gray
    Write-Host "  3. Deploy your backend API to Cloud Run" -ForegroundColor Gray
    Write-Host "  4. Deploy Cloud Functions for video processing" -ForegroundColor Gray
    Write-Host "  5. Configure Firestore security rules" -ForegroundColor Gray
    
    Write-Host "`nUseful Commands:" -ForegroundColor Cyan
    Write-Host "  gcloud config set project $ProjectId" -ForegroundColor Gray
    Write-Host "  gcloud auth application-default set-quota-project $ProjectId" -ForegroundColor Gray
    Write-Host "  ./test-infrastructure.ps1 -ProjectId $ProjectId" -ForegroundColor Gray
} else {
    Write-Host "`n🏁 Dry run completed - no changes were made" -ForegroundColor Yellow
}

Write-Host "`n🎉 Project Pod infrastructure provisioning script finished!" -ForegroundColor Green
