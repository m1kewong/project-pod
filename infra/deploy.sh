#!/bin/bash

# GCP Infrastructure Deployment Script
# Usage: ./deploy.sh <environment> [action]
# Example: ./deploy.sh dev apply

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    echo "Usage: $0 <environment> [action]"
    echo ""
    echo "Environments:"
    echo "  dev      - Development environment"
    echo "  staging  - Staging environment"
    echo "  prod     - Production environment"
    echo ""
    echo "Actions:"
    echo "  plan     - Show what Terraform will do (default)"
    echo "  apply    - Apply the Terraform configuration"
    echo "  destroy  - Destroy the infrastructure"
    echo "  init     - Initialize Terraform"
    echo "  validate - Validate Terraform configuration"
    echo "  output   - Show Terraform outputs"
    echo ""
    echo "Examples:"
    echo "  $0 dev plan     # Plan development deployment"
    echo "  $0 prod apply   # Deploy to production"
    echo "  $0 dev output   # Show development outputs"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if gcloud is installed and authenticated
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if user is authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_error "You are not authenticated with gcloud. Please run 'gcloud auth login'"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

setup_terraform() {
    local environment=$1
    
    log_info "Setting up Terraform for environment: ${environment}"
    
    cd "${TERRAFORM_DIR}"
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        log_info "Initializing Terraform..."
        terraform init
    fi
    
    # Create or select workspace
    if ! terraform workspace list | grep -q "${environment}"; then
        log_info "Creating Terraform workspace: ${environment}"
        terraform workspace new "${environment}"
    else
        log_info "Selecting Terraform workspace: ${environment}"
        terraform workspace select "${environment}"
    fi
    
    log_success "Terraform setup complete"
}

validate_environment() {
    local environment=$1
    
    if [[ ! "$environment" =~ ^(dev|staging|prod)$ ]]; then
        log_error "Invalid environment: $environment"
        usage
        exit 1
    fi
    
    # Check if tfvars file exists
    if [ ! -f "${TERRAFORM_DIR}/${environment}.tfvars" ]; then
        log_error "Configuration file not found: ${environment}.tfvars"
        exit 1
    fi
}

run_terraform() {
    local environment=$1
    local action=$2
    local tfvars_file="${environment}.tfvars"
    
    cd "${TERRAFORM_DIR}"
    
    case $action in
        "init")
            terraform init
            ;;
        "validate")
            terraform validate
            ;;
        "plan")
            terraform plan -var-file="$tfvars_file" -out="${environment}.tfplan"
            ;;
        "apply")
            if [ -f "${environment}.tfplan" ]; then
                terraform apply "${environment}.tfplan"
            else
                log_warning "No plan file found. Running plan first..."
                terraform plan -var-file="$tfvars_file" -out="${environment}.tfplan"
                terraform apply "${environment}.tfplan"
            fi
            ;;
        "destroy")
            log_warning "This will destroy all infrastructure in the ${environment} environment!"
            read -p "Are you sure? Type 'yes' to continue: " confirm
            if [ "$confirm" = "yes" ]; then
                terraform destroy -var-file="$tfvars_file"
            else
                log_info "Destroy cancelled"
                exit 0
            fi
            ;;
        "output")
            terraform output
            ;;
        *)
            log_error "Unknown action: $action"
            usage
            exit 1
            ;;
    esac
}

# Main script
main() {
    if [ $# -lt 1 ]; then
        usage
        exit 1
    fi
    
    local environment=$1
    local action=${2:-plan}
    
    log_info "Starting deployment for environment: ${environment}, action: ${action}"
    
    validate_environment "$environment"
    check_prerequisites
    setup_terraform "$environment"
    run_terraform "$environment" "$action"
    
    log_success "Deployment completed successfully!"
}

# Run main function with all arguments
main "$@"
