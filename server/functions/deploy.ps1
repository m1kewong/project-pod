# Deploy Video Transcoding Cloud Function
# PowerShell script for Windows deployment

param(
    [Parameter()]
    [string]$ProjectId = $env:GOOGLE_CLOUD_PROJECT,
    
    [Parameter()]
    [string]$Region = "asia-east1",
      [Parameter()]
    [string]$FunctionName = "transcodeVideo",
    
    [Parameter()]
    [string]$TriggerBucket = "project-pod-dev-uploads"
)

# Set default project if not provided
if (-not $ProjectId) {
    $ProjectId = "project-pod-dev"
}

Write-Host "🚀 Deploying Video Transcoding Cloud Function..." -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host "Function: $FunctionName" -ForegroundColor Cyan
Write-Host "Trigger Bucket: $TriggerBucket" -ForegroundColor Cyan

# Check if gcloud is installed
try {
    $gcloudVersion = gcloud version 2>$null
    if (-not $gcloudVersion) {
        throw "gcloud not found"
    }
} catch {
    Write-Host "❌ Error: gcloud CLI not found. Please install the Google Cloud SDK." -ForegroundColor Red
    exit 1
}

# Check if authenticated
try {
    $activeAccount = gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>$null
    if (-not $activeAccount) {
        Write-Host "❌ Error: gcloud is not authenticated. Please run 'gcloud auth login'" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Authenticated as: $activeAccount" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: Failed to check authentication status" -ForegroundColor Red
    exit 1
}

# Set the project
Write-Host "📋 Setting project..." -ForegroundColor Yellow
gcloud config set project $ProjectId

# Enable required APIs
Write-Host "📋 Enabling required APIs..." -ForegroundColor Yellow
$apis = @(
    "cloudfunctions.googleapis.com",
    "transcoder.googleapis.com", 
    "storage.googleapis.com",
    "firestore.googleapis.com"
)

foreach ($api in $apis) {
    Write-Host "Enabling $api..." -ForegroundColor White
    gcloud services enable $api
}

# Install dependencies
Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
if (Test-Path "package.json") {
    npm install
} else {
    Write-Host "❌ Error: package.json not found. Make sure you're in the functions directory." -ForegroundColor Red
    exit 1
}

# Deploy the function
Write-Host "🏗️ Deploying Cloud Function..." -ForegroundColor Yellow
try {
    gcloud functions deploy $FunctionName `
        --runtime nodejs18 `
        --trigger-bucket $TriggerBucket `
        --memory 1024MB `
        --timeout 540s `
        --region $Region `
        --entry-point transcodeVideo `
        --set-env-vars "GOOGLE_CLOUD_PROJECT=$ProjectId" `
        --allow-unauthenticated
        
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Cloud Function deployed successfully!" -ForegroundColor Green
        
        Write-Host "📝 Function details:" -ForegroundColor Cyan
        gcloud functions describe $FunctionName --region $Region
        
        Write-Host ""
        Write-Host "🎬 To test the function, upload a video file to gs://$TriggerBucket" -ForegroundColor Yellow
        Write-Host "📊 Monitor function logs with: gcloud functions logs read $FunctionName --region $Region" -ForegroundColor Yellow
    } else {
        Write-Host "❌ Deployment failed!" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Error during deployment: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
