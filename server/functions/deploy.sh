#!/bin/bash

# Deploy Video Transcoding Cloud Function
# This script deploys the transcoding function to GCP

set -e

# Configuration
PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-pod-social-video-dev}"
REGION="asia-east1"
FUNCTION_NAME="transcodeVideo"
TRIGGER_BUCKET="pod-uploads-bucket"
MEMORY="1024MB"
TIMEOUT="540s"
RUNTIME="nodejs18"

echo "🚀 Deploying Video Transcoding Cloud Function..."
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Function: $FUNCTION_NAME"
echo "Trigger Bucket: $TRIGGER_BUCKET"

# Check if gcloud is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "❌ Error: gcloud is not authenticated. Please run 'gcloud auth login'"
    exit 1
fi

# Set the project
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "📋 Enabling required APIs..."
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable transcoder.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable firestore.googleapis.com

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Deploy the function
echo "🏗️ Deploying Cloud Function..."
gcloud functions deploy $FUNCTION_NAME \
    --runtime $RUNTIME \
    --trigger-bucket $TRIGGER_BUCKET \
    --memory $MEMORY \
    --timeout $TIMEOUT \
    --region $REGION \
    --entry-point transcodeVideo \
    --set-env-vars "GOOGLE_CLOUD_PROJECT=$PROJECT_ID" \
    --allow-unauthenticated

echo "✅ Cloud Function deployed successfully!"
echo "📝 Function details:"
gcloud functions describe $FUNCTION_NAME --region $REGION

echo ""
echo "🎬 To test the function, upload a video file to gs://$TRIGGER_BUCKET"
echo "📊 Monitor function logs with: gcloud functions logs read $FUNCTION_NAME --region $REGION"
