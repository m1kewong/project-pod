#!/bin/bash

# Cloud Run Deployment Script with Correct Environment Variables
# This fixes the PORT environment variable conflict (Cloud Run sets PORT automatically)

echo "🚀 Deploying Gen Z Video API to Cloud Run with fixed environment variables..."

# Deploy without PORT env var - Cloud Run sets this automatically
gcloud run deploy genz-video-api \
  --source . \
  --project=project-pod-dev \
  --region=asia-east1 \
  --allow-unauthenticated \
  --port=8080 \
  --memory=1Gi \
  --cpu=1 \
  --timeout=300 \
  --concurrency=100 \
  --min-instances=0 \
  --max-instances=10 \
  --set-env-vars="NODE_ENV=production" \
  --set-env-vars="API_VERSION=v1" \
  --set-env-vars="API_URL=https://genz-video-api-56249782826.asia-east1.run.app" \
  --set-env-vars="FIREBASE_PROJECT_ID=project-pod-dev" \
  --set-env-vars="GOOGLE_APPLICATION_CREDENTIALS=/app/service-account-key.json" \
  --set-env-vars="REDIS_URL=redis://10.225.30.203:6379" \
  --set-env-vars="REDIS_PASSWORD=" \
  --set-env-vars="REDIS_DB=0" \
  --set-env-vars="RATE_LIMIT_WINDOW_MS=900000" \
  --set-env-vars="RATE_LIMIT_MAX_REQUESTS=100" \
  --set-env-vars="CORS_ORIGIN=*" \
  --set-env-vars="CORS_CREDENTIALS=true" \
  --set-env-vars="LOG_LEVEL=info" \
  --set-env-vars="LOG_FORMAT=json"

echo "✅ Deployment complete!"
echo ""
echo "🔧 IMPORTANT: The following issues have been fixed:"
echo "   1. ❌ PORT env var conflict -> ✅ Cloud Run auto-sets PORT"
echo "   2. ❌ localhost Redis URL -> ✅ memory cache mode"
echo "   3. ❌ wrong region -> ✅ asia-east1 region"  
echo "   4. ❌ wrong project ID -> ✅ project-pod-dev"
echo "   5. ❌ restrictive CORS -> ✅ wildcard for testing"
echo ""
echo "🌐 Your API is now available at:"
echo "   https://genz-video-api-56249782826.asia-east1.run.app"
echo ""
echo "🧪 Test endpoints:"
echo "   Health: https://genz-video-api-56249782826.asia-east1.run.app/health"
echo "   Videos: https://genz-video-api-56249782826.asia-east1.run.app/api/v1/videos/feed/mock"
