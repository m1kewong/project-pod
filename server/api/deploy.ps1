# Gen Z Social Video Platform API - Cloud Run Deployment Script (PowerShell)
# This script builds and deploys the API to Google Cloud Run

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectId = "project-pod-dev",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "asia-east1",
    
    [Parameter(Mandatory=$false)]
    [string]$ServiceName = "genz-video-api",
    
    [Parameter(Mandatory=$false)]
    [string]$Repository = "main",
    
    [Parameter(Mandatory=$false)]
    [string]$ImageName = "genz-video-api"
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
    }
    
    Write-Host $Message -ForegroundColor $colorMap[$Color]
}

Write-ColorOutput "🚀 Starting deployment of Gen Z Video API to Cloud Run" "Blue"

# Check if gcloud is installed
try {
    $null = Get-Command gcloud -ErrorAction Stop
    Write-ColorOutput "✅ gcloud CLI found" "Green"
} catch {
    Write-ColorOutput "❌ gcloud CLI is not installed. Please install it first." "Red"
    exit 1
}

# Set the project
Write-ColorOutput "📋 Setting project to $ProjectId" "Yellow"
gcloud config set project $ProjectId

# Enable required APIs
Write-ColorOutput "🔧 Ensuring required APIs are enabled" "Yellow"
gcloud services enable cloudbuild.googleapis.com run.googleapis.com artifactregistry.googleapis.com firestore.googleapis.com storage.googleapis.com

# Create Artifact Registry repository if it doesn't exist
Write-ColorOutput "📦 Setting up Artifact Registry" "Yellow"
try {
    gcloud artifacts repositories create $Repository --repository-format=docker --location=$Region --description="Docker repository for Gen Z Video API" --quiet 2>$null
} catch {
    Write-ColorOutput "Repository already exists" "Yellow"
}

# Configure Docker to use gcloud as credential helper
Write-ColorOutput "🔐 Configuring Docker authentication" "Yellow"
gcloud auth configure-docker "$Region-docker.pkg.dev"

# Build the Docker image
Write-ColorOutput "🏗️  Building Docker image" "Yellow"
$imageTag = "$Region-docker.pkg.dev/$ProjectId/$Repository/$ImageName`:latest"
docker build -t $imageTag .

if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "❌ Docker build failed" "Red"
    exit 1
}

# Push the image to Artifact Registry
Write-ColorOutput "📤 Pushing image to Artifact Registry" "Yellow"
docker push $imageTag

if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "❌ Docker push failed" "Red"
    exit 1
}

# Create service account if it doesn't exist
Write-ColorOutput "👤 Setting up service account" "Yellow"
try {
    gcloud iam service-accounts create genz-video-api --display-name="Gen Z Video API Service Account" --description="Service account for the Gen Z Video API" --quiet 2>$null
} catch {
    Write-ColorOutput "Service account already exists" "Yellow"
}

# Grant necessary permissions to the service account
Write-ColorOutput "🔑 Granting IAM permissions" "Yellow"
$serviceAccount = "serviceAccount:genz-video-api@$ProjectId.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding $ProjectId --member=$serviceAccount --role="roles/datastore.user"
gcloud projects add-iam-policy-binding $ProjectId --member=$serviceAccount --role="roles/storage.objectViewer"
gcloud projects add-iam-policy-binding $ProjectId --member=$serviceAccount --role="roles/firebase.admin"

# Deploy to Cloud Run
Write-ColorOutput "🚀 Deploying to Cloud Run" "Yellow"
gcloud run deploy $ServiceName `
    --image=$imageTag `
    --platform=managed `
    --region=$Region `
    --service-account="genz-video-api@$ProjectId.iam.gserviceaccount.com" `
    --allow-unauthenticated `
    --memory=2Gi `
    --cpu=2 `
    --min-instances=1 `
    --max-instances=100 `
    --concurrency=100 `
    --timeout=300 `
    --port=8080 `
    --set-env-vars="NODE_ENV=production,GOOGLE_CLOUD_PROJECT=$ProjectId,FIREBASE_PROJECT_ID=$ProjectId" `
    --execution-environment=gen2

if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "❌ Cloud Run deployment failed" "Red"
    exit 1
}

# Get the service URL
$serviceUrl = gcloud run services describe $ServiceName --platform=managed --region=$Region --format="value(status.url)"

Write-ColorOutput "✅ Deployment completed successfully!" "Green"
Write-ColorOutput "📋 Service Details:" "Blue"
Write-ColorOutput "   🌍 URL: $serviceUrl" "White"
Write-ColorOutput "   📚 API Docs: $serviceUrl/api/docs" "White"
Write-ColorOutput "   🏥 Health Check: $serviceUrl/health" "White"
Write-ColorOutput "   📊 Metrics: $serviceUrl/metrics" "White"

# Test the deployment
Write-ColorOutput "🧪 Testing deployment" "Yellow"
try {
    $response = Invoke-WebRequest -Uri "$serviceUrl/health" -Method Get -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-ColorOutput "✅ Health check passed!" "Green"
    } else {
        Write-ColorOutput "❌ Health check failed with status: $($response.StatusCode)" "Red"
    }
} catch {
    Write-ColorOutput "❌ Health check failed: $($_.Exception.Message)" "Red"
}

Write-ColorOutput "🎉 Deployment process completed!" "Green"
