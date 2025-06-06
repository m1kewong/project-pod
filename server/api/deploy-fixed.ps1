# Deploy the fixed version to Cloud Run with correct environment variables
# Location: Asia East 1 region

Write-Host "🚀 Deploying Fixed Gen Z Video API to Cloud Run (Asia East 1)" -ForegroundColor Green

# Set project
gcloud config set project project-pod-dev

# Build and deploy with all required environment variables
gcloud run deploy genz-video-api `
  --source . `
  --region asia-east1 `
  --platform managed `
  --port 8080 `
  --memory 512Mi `
  --cpu 1 `
  --min-instances 0 `
  --max-instances 10 `
  --timeout 300 `
  --service-account backend-service@project-pod-dev.iam.gserviceaccount.com `
  --set-env-vars "NODE_ENV=production,FIREBASE_PROJECT_ID=project-pod-dev,REDIS_URL=memory://localhost,API_VERSION=v1,LOG_LEVEL=info" `
  --set-secrets "FIREBASE_ADMIN_KEY=FIREBASE_ADMIN_KEY:latest,JWT_SECRET=JWT_SECRET:latest" `
  --allow-unauthenticated `
  --verbosity info

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Deployment successful!" -ForegroundColor Green
    Write-Host "🌐 Testing the deployment..." -ForegroundColor Yellow
    
    # Get the service URL
    $SERVICE_URL = gcloud run services describe genz-video-api --region asia-east1 --format "value(status.url)"
    
    Write-Host "📍 Service URL: $SERVICE_URL" -ForegroundColor Cyan
    Write-Host "🏥 Health Check: $SERVICE_URL/health" -ForegroundColor Cyan
    Write-Host "📚 API Docs: $SERVICE_URL/api/docs" -ForegroundColor Cyan
    
    # Test health endpoint
    Write-Host "Testing health endpoint..." -ForegroundColor Yellow
    try {
        $response = Invoke-RestMethod -Uri "$SERVICE_URL/health" -Method GET -TimeoutSec 30
        Write-Host "✅ Health check passed!" -ForegroundColor Green
        Write-Host "Response: $($response | ConvertTo-Json)" -ForegroundColor White
    } catch {
        Write-Host "❌ Health check failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Deployment failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit 1
}
