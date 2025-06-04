#!/bin/bash
# Firestore Database Deployment Script for Gen Z Social Video Platform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID=${PROJECT_ID:-"project-pod-dev"}
FIRESTORE_REGION=${FIRESTORE_REGION:-"asia-southeast1"}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEED_DATA_DIR="${SCRIPT_DIR}/seed-data"

echo -e "${BLUE}🚀 Starting Firestore Database Deployment${NC}"
echo -e "${BLUE}Project ID: ${PROJECT_ID}${NC}"
echo -e "${BLUE}Region: ${FIRESTORE_REGION}${NC}"

# Check if gcloud is installed and authenticated
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo -e "${RED}❌ Not authenticated with gcloud. Please run 'gcloud auth login'${NC}"
    exit 1
fi

# Set the project
echo -e "${YELLOW}📋 Setting GCP project...${NC}"
gcloud config set project "${PROJECT_ID}"

# Check if Firestore is already initialized
echo -e "${YELLOW}🔍 Checking Firestore initialization status...${NC}"
FIRESTORE_STATUS=$(gcloud firestore databases list --format="value(name)" 2>/dev/null || echo "")

if [[ -z "${FIRESTORE_STATUS}" ]]; then
    echo -e "${YELLOW}🏗️ Initializing Firestore database...${NC}"
    gcloud firestore databases create --region="${FIRESTORE_REGION}" --type=firestore-native
    echo -e "${GREEN}✅ Firestore database created successfully${NC}"
else
    echo -e "${GREEN}✅ Firestore database already exists${NC}"
fi

# Deploy security rules
echo -e "${YELLOW}🔒 Deploying Firestore security rules...${NC}"
if [[ -f "${SCRIPT_DIR}/firestore.rules" ]]; then
    gcloud firestore databases update --security-rules-file="${SCRIPT_DIR}/firestore.rules"
    echo -e "${GREEN}✅ Security rules deployed successfully${NC}"
else
    echo -e "${RED}❌ firestore.rules file not found${NC}"
    exit 1
fi

# Deploy indexes (if exists)
if [[ -f "${SCRIPT_DIR}/firestore.indexes.json" ]]; then
    echo -e "${YELLOW}📊 Deploying Firestore indexes...${NC}"
    gcloud firestore indexes composite create --field-config=firestore.indexes.json
    echo -e "${GREEN}✅ Indexes deployed successfully${NC}"
else
    echo -e "${YELLOW}⚠️ No firestore.indexes.json found, skipping index deployment${NC}"
fi

# Function to upload seed data
upload_seed_data() {
    local collection_name=$1
    local json_file=$2
    
    echo -e "${YELLOW}📁 Uploading seed data for ${collection_name}...${NC}"
    
    if [[ ! -f "${json_file}" ]]; then
        echo -e "${RED}❌ Seed data file not found: ${json_file}${NC}"
        return 1
    fi
    
    # Use Node.js script to upload data (we'll create this next)
    if command -v node &> /dev/null; then
        node "${SCRIPT_DIR}/scripts/upload-seed-data.js" "${collection_name}" "${json_file}" "${PROJECT_ID}"
    else
        echo -e "${YELLOW}⚠️ Node.js not found, skipping seed data upload for ${collection_name}${NC}"
        echo -e "${YELLOW}   You can manually import the data from: ${json_file}${NC}"
    fi
}

# Upload seed data for each collection
if [[ -d "${SEED_DATA_DIR}" ]]; then
    echo -e "${YELLOW}📊 Uploading seed data...${NC}"
    
    # Upload in order (users first, then videos that reference users, etc.)
    upload_seed_data "users" "${SEED_DATA_DIR}/users.json"
    upload_seed_data "videos" "${SEED_DATA_DIR}/videos.json"
    upload_seed_data "danmu_comments" "${SEED_DATA_DIR}/danmu_comments.json"
    upload_seed_data "notifications" "${SEED_DATA_DIR}/notifications.json"
    upload_seed_data "follows" "${SEED_DATA_DIR}/follows.json"
    upload_seed_data "activities" "${SEED_DATA_DIR}/activities.json"
    
    echo -e "${GREEN}✅ Seed data upload completed${NC}"
else
    echo -e "${YELLOW}⚠️ Seed data directory not found, skipping data upload${NC}"
fi

# Test the deployment
echo -e "${YELLOW}🧪 Testing Firestore deployment...${NC}"

# Test basic read access
if gcloud firestore documents list --collection=users --limit=1 &>/dev/null; then
    echo -e "${GREEN}✅ Firestore read access test passed${NC}"
else
    echo -e "${RED}❌ Firestore read access test failed${NC}"
fi

# Test security rules (attempt unauthorized write)
echo -e "${YELLOW}🔒 Testing security rules...${NC}"
if command -v node &> /dev/null; then
    node "${SCRIPT_DIR}/scripts/test-security-rules.js" "${PROJECT_ID}"
else
    echo -e "${YELLOW}⚠️ Node.js not found, skipping security rules test${NC}"
fi

echo -e "${GREEN}🎉 Firestore deployment completed successfully!${NC}"
echo -e "${BLUE}📋 Next steps:${NC}"
echo -e "   1. Test the Flutter app connection"
echo -e "   2. Verify security rules in the Firebase Console"
echo -e "   3. Monitor usage in the Firebase Console"
echo -e "${BLUE}Firebase Console: https://console.firebase.google.com/project/${PROJECT_ID}/firestore${NC}"
