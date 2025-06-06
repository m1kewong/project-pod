#!/usr/bin/env powershell
# Cloud Build Deployment Script for Gen Z Video API
# This script uses Cloud Build to containerize and deploy the API to Cloud Run

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectId = "project-pod-dev",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "asia-east1"
)

$ErrorActionPreference = "Stop"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    $colorMap = @{
        "Red" = "Red"
        "Green" = "Green"
        "Yellow" = "Yellow"
        "Blue" = "Blue"
        "White" = "White"
        "Magenta" = "Magenta"
    }
    
    Write-Host $Message -ForegroundColor $colorMap[$Color]
}

Write-ColorOutput "🚀 Starting Cloud Build deployment of Gen Z Video API" "Blue"
Write-ColorOutput "Project: $ProjectId" "White"
Write-ColorOutput "Region: $Region" "White"
Write-ColorOutput "" "White"

# Check if gcloud is installed
try {
    $null = Get-Command gcloud -ErrorAction Stop
    Write-ColorOutput "✅ gcloud CLI found" "Green"
} catch {
    Write-ColorOutput "❌ gcloud CLI is not installed. Please install it first." "Red"
    exit 1
}

# Set the project
Write-ColorOutput "📋 Setting up Google Cloud project..." "Yellow"
try {
    gcloud config set project $ProjectId
    Write-ColorOutput "✅ Project set to $ProjectId" "Green"
} catch {
    Write-ColorOutput "❌ Failed to set project. Please check project ID and permissions." "Red"
    exit 1
}

# Check authentication
try {
    $activeAccount = gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>$null
    if (-not $activeAccount) {
        Write-ColorOutput "❌ No active authentication found. Please run 'gcloud auth login'" "Red"
        exit 1
    }
    Write-ColorOutput "✅ Authenticated as: $activeAccount" "Green"
} catch {
    Write-ColorOutput "❌ Authentication check failed" "Red"
    exit 1
}

# Enable required APIs
Write-ColorOutput "🔧 Ensuring required APIs are enabled..." "Yellow"
$apis = @(
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com"
)

foreach ($api in $apis) {
    try {
        gcloud services enable $api --quiet
        Write-ColorOutput "✅ Enabled $api" "Green"
    } catch {
        Write-ColorOutput "⚠️  Warning: Could not enable $api" "Yellow"
    }
}

# Build TypeScript code locally first
Write-ColorOutput "🔨 Building TypeScript code..." "Yellow"
try {
    npm run build
    Write-ColorOutput "✅ TypeScript build completed" "Green"
} catch {
    Write-ColorOutput "❌ TypeScript build failed" "Red"
    exit 1
}

# Submit build to Cloud Build
Write-ColorOutput "☁️  Submitting build to Cloud Build..." "Yellow"
Write-ColorOutput "This will build the Docker container and deploy to Cloud Run..." "White"
Write-ColorOutput "" "White"

try {
    $buildResult = gcloud builds submit --config=cloudbuild.yaml . --substitutions=_PROJECT_ID=$ProjectId 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Cloud Build completed successfully!" "Green"
    } else {
        Write-ColorOutput "❌ Cloud Build failed" "Red"
        Write-ColorOutput $buildResult "Red"
        exit 1
    }
} catch {
    Write-ColorOutput "❌ Failed to submit Cloud Build" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# Get Cloud Run service URL
Write-ColorOutput "🌐 Getting service URL..." "Yellow"
try {
    $serviceUrl = gcloud run services describe genz-video-api --region=$Region --format="value(status.url)" 2>$null
    if ($serviceUrl) {
        Write-ColorOutput "✅ Service deployed successfully!" "Green"
        Write-ColorOutput "🌍 Service URL: $serviceUrl" "Magenta"
        Write-ColorOutput "📚 API Documentation: $serviceUrl/api/docs" "Magenta"
        Write-ColorOutput "🏥 Health Check: $serviceUrl/health" "Magenta"
        Write-ColorOutput "📊 Metrics: $serviceUrl/metrics" "Magenta"
    } else {
        Write-ColorOutput "⚠️  Service deployed but URL not available yet" "Yellow"
    }
} catch {
    Write-ColorOutput "⚠️  Could not retrieve service URL" "Yellow"
}

Write-ColorOutput "" "White"
Write-ColorOutput "🎉 Deployment completed!" "Green"
Write-ColorOutput "" "White"
Write-ColorOutput "Next Steps:" "Yellow"
Write-ColorOutput "1. Test the API endpoints using the service URL above" "White"
Write-ColorOutput "2. Configure your Flutter app to use the new API URL" "White"
Write-ColorOutput "3. Set up monitoring and logging in Google Cloud Console" "White"
Write-ColorOutput "4. Configure custom domain (optional)" "White"
