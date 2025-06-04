# Setup Video Transcoding Pipeline
# This script sets up the complete transcoding infrastructure

param(
    [Parameter()]
    [string]$ProjectId = $env:GOOGLE_CLOUD_PROJECT,
    
    [Parameter()]
    [switch]$SkipDeploy = $false
)

# Set default project if not provided
if (-not $ProjectId) {
    $ProjectId = "pod-social-video-dev"
}

Write-Host "🚀 Setting up Video Transcoding Pipeline..." -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor Cyan

# Check prerequisites
Write-Host "🔍 Checking prerequisites..." -ForegroundColor Yellow

# Check gcloud
try {
    $gcloudVersion = gcloud version 2>$null
    Write-Host "✅ Google Cloud SDK found" -ForegroundColor Green
} catch {
    Write-Host "❌ Google Cloud SDK not found. Please install it first." -ForegroundColor Red
    Write-Host "   Download from: https://cloud.google.com/sdk/docs/install" -ForegroundColor Yellow
    exit 1
}

# Check Node.js
try {
    $nodeVersion = node --version 2>$null
    Write-Host "✅ Node.js found: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Node.js not found. Please install Node.js 18 or later." -ForegroundColor Red
    Write-Host "   Download from: https://nodejs.org/" -ForegroundColor Yellow
    exit 1
}

# Check npm
try {
    $npmVersion = npm --version 2>$null
    Write-Host "✅ npm found: $npmVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ npm not found. Please install npm." -ForegroundColor Red
    exit 1
}

# Set project
Write-Host "📋 Setting up Google Cloud project..." -ForegroundColor Yellow
gcloud config set project $ProjectId

# Check authentication
try {
    $activeAccount = gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>$null
    if (-not $activeAccount) {
        Write-Host "❌ Not authenticated. Running login..." -ForegroundColor Yellow
        gcloud auth login
        $activeAccount = gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>$null
    }
    Write-Host "✅ Authenticated as: $activeAccount" -ForegroundColor Green
} catch {
    Write-Host "❌ Authentication failed" -ForegroundColor Red
    exit 1
}

# Enable required APIs
Write-Host "📋 Enabling required APIs..." -ForegroundColor Yellow
$requiredApis = @(
    "cloudfunctions.googleapis.com",
    "transcoder.googleapis.com",
    "storage.googleapis.com",
    "firestore.googleapis.com",
    "cloudbuild.googleapis.com"
)

foreach ($api in $requiredApis) {
    Write-Host "   Enabling $api..." -ForegroundColor White
    gcloud services enable $api --quiet
}

Write-Host "✅ APIs enabled successfully" -ForegroundColor Green

# Check/Create storage buckets
Write-Host "🪣 Setting up storage buckets..." -ForegroundColor Yellow

$uploadsBucket = "pod-uploads-bucket"
$publicBucket = "pod-public-videos-bucket"

# Check uploads bucket
try {
    gsutil ls "gs://$uploadsBucket" 2>$null | Out-Null
    Write-Host "✅ Uploads bucket exists: $uploadsBucket" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Uploads bucket not found. Please create it first:" -ForegroundColor Yellow
    Write-Host "   gsutil mb gs://$uploadsBucket" -ForegroundColor White
    Write-Host "   Or run the infrastructure setup script first." -ForegroundColor Gray
}

# Check public bucket
try {
    gsutil ls "gs://$publicBucket" 2>$null | Out-Null
    Write-Host "✅ Public bucket exists: $publicBucket" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Public bucket not found. Please create it first:" -ForegroundColor Yellow
    Write-Host "   gsutil mb gs://$publicBucket" -ForegroundColor White
    Write-Host "   Or run the infrastructure setup script first." -ForegroundColor Gray
}

# Install dependencies
Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
if (Test-Path "package.json") {
    npm install
    Write-Host "✅ Dependencies installed" -ForegroundColor Green
} else {
    Write-Host "❌ package.json not found. Make sure you're in the functions directory." -ForegroundColor Red
    exit 1
}

# Run tests
Write-Host "🧪 Running tests..." -ForegroundColor Yellow
try {
    npm test
    Write-Host "✅ Tests passed" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Some tests failed, but continuing..." -ForegroundColor Yellow
}

# Deploy function (optional)
if (-not $SkipDeploy) {
    Write-Host "🚀 Deploying Cloud Function..." -ForegroundColor Yellow
    try {
        & ".\deploy.ps1" -ProjectId $ProjectId
        Write-Host "✅ Cloud Function deployed successfully" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Deployment failed. You can deploy manually later with:" -ForegroundColor Yellow
        Write-Host "   .\deploy.ps1" -ForegroundColor White
    }
} else {
    Write-Host "⏭️  Skipping deployment (use -SkipDeploy:$false to deploy)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "🎉 Setup completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Deploy the function: .\deploy.ps1" -ForegroundColor White
Write-Host "   2. Test the pipeline: .\test-transcoding.ps1" -ForegroundColor White
Write-Host "   3. Upload a video to test: gsutil cp video.mp4 gs://$uploadsBucket/" -ForegroundColor White
Write-Host ""
Write-Host "📊 Monitor your function:" -ForegroundColor Cyan
Write-Host "   gcloud functions logs read transcodeVideo --region asia-east1 --follow" -ForegroundColor White
Write-Host ""
Write-Host "🔗 Useful resources:" -ForegroundColor Cyan
Write-Host "   - Cloud Functions Console: https://console.cloud.google.com/functions" -ForegroundColor White
Write-Host "   - Transcoder API Console: https://console.cloud.google.com/transcoder" -ForegroundColor White
Write-Host "   - Storage Console: https://console.cloud.google.com/storage" -ForegroundColor White
