#!/bin/bash

# Gen Z Social Video Platform API - Cloud Run Deployment Script
# This script builds and deploys the API to Google Cloud Run

set -e

# Configuration
PROJECT_ID="project-pod-dev"
REGION="asia-east1"
SERVICE_NAME="genz-video-api"
REPOSITORY="main"
IMAGE_NAME="genz-video-api"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting deployment of Gen Z Video API to Cloud Run${NC}"

# Check if gcloud is installed and authenticated
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Set the project
echo -e "${YELLOW}📋 Setting project to ${PROJECT_ID}${NC}"
gcloud config set project $PROJECT_ID

# Enable required APIs
echo -e "${YELLOW}🔧 Ensuring required APIs are enabled${NC}"
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    artifactregistry.googleapis.com \
    firestore.googleapis.com \
    storage.googleapis.com

# Create Artifact Registry repository if it doesn't exist
echo -e "${YELLOW}📦 Setting up Artifact Registry${NC}"
gcloud artifacts repositories create $REPOSITORY \
    --repository-format=docker \
    --location=$REGION \
    --description="Docker repository for Gen Z Video API" \
    --quiet || echo "Repository already exists"

# Configure Docker to use gcloud as credential helper
echo -e "${YELLOW}🔐 Configuring Docker authentication${NC}"
gcloud auth configure-docker $REGION-docker.pkg.dev

# Build the Docker image
echo -e "${YELLOW}🏗️  Building Docker image${NC}"
docker build -t $REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY/$IMAGE_NAME:latest .

# Push the image to Artifact Registry
echo -e "${YELLOW}📤 Pushing image to Artifact Registry${NC}"
docker push $REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY/$IMAGE_NAME:latest

# Create service account if it doesn't exist
echo -e "${YELLOW}👤 Setting up service account${NC}"
gcloud iam service-accounts create genz-video-api \
    --display-name="Gen Z Video API Service Account" \
    --description="Service account for the Gen Z Video API" \
    --quiet || echo "Service account already exists"

# Grant necessary permissions to the service account
echo -e "${YELLOW}🔑 Granting IAM permissions${NC}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:genz-video-api@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/datastore.user"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:genz-video-api@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.objectViewer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:genz-video-api@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/firebase.admin"

# Deploy to Cloud Run
echo -e "${YELLOW}🚀 Deploying to Cloud Run${NC}"
gcloud run deploy $SERVICE_NAME \
    --image=$REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY/$IMAGE_NAME:latest \
    --platform=managed \
    --region=$REGION \
    --service-account=genz-video-api@$PROJECT_ID.iam.gserviceaccount.com \
    --allow-unauthenticated \
    --memory=2Gi \
    --cpu=2 \
    --min-instances=1 \
    --max-instances=100 \
    --concurrency=100 \
    --timeout=300 \
    --port=8080 \
    --set-env-vars="NODE_ENV=production,GOOGLE_CLOUD_PROJECT=$PROJECT_ID,FIREBASE_PROJECT_ID=$PROJECT_ID" \
    --execution-environment=gen2

# Get the service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --platform=managed --region=$REGION --format="value(status.url)")

echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo -e "${BLUE}📋 Service Details:${NC}"
echo -e "   🌍 URL: $SERVICE_URL"
echo -e "   📚 API Docs: $SERVICE_URL/api/docs"
echo -e "   🏥 Health Check: $SERVICE_URL/health"
echo -e "   📊 Metrics: $SERVICE_URL/metrics"

# Test the deployment
echo -e "${YELLOW}🧪 Testing deployment${NC}"
curl -f "$SERVICE_URL/health" && echo -e "${GREEN}✅ Health check passed!${NC}" || echo -e "${RED}❌ Health check failed${NC}"

echo -e "${GREEN}🎉 Deployment process completed!${NC}"
