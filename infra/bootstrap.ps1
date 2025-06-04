# GCP Project Bootstrap Script
# This script creates GCP projects, enables billing, and sets up basic configuration
# Usage: .\bootstrap.ps1

param(
    [Parameter(Mandatory=$false)]
    [string]$BillingAccountId,
    
    [Parameter(Mandatory=$false)]
    [string]$OrganizationId,
    
    [Parameter(Mandatory=$false)]
    [string]$FolderName = "GenZ Video Platform"
)

# Configuration
$ProjectConfigs = @(
    @{
        Id = "genz-video-app-dev"
        Name = "GenZ Video Platform - Development"
        Environment = "dev"
    },
    @{
        Id = "genz-video-app-staging"
        Name = "GenZ Video Platform - Staging"
        Environment = "staging"
    },
    @{
        Id = "genz-video-app-prod"
        Name = "GenZ Video Platform - Production"
        Environment = "prod"
    }
)

# Required APIs for all projects
$RequiredApis = @(
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "iam.googleapis.com",
    "cloudrun.googleapis.com",
    "firestore.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "cloudfunctions.googleapis.com",
    "transcoder.googleapis.com",
    "cloudbuild.googleapis.com",
    "firebase.googleapis.com",
    "compute.googleapis.com",
    "cloudcdn.googleapis.com",
    "secretmanager.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com"
)

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check if gcloud is installed
    try {
        $null = Get-Command gcloud -ErrorAction Stop
    } catch {
        Write-Error "gcloud CLI is not installed. Please install it first."
        exit 1
    }
    
    # Check if user is authenticated
    $authOutput = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
    if (-not $authOutput) {
        Write-Error "You are not authenticated with gcloud. Please run 'gcloud auth login'"
        exit 1
    }
    
    # Check if user has necessary permissions
    $currentUser = gcloud config get-value account
    Write-Info "Current user: $currentUser"
    
    Write-Success "Prerequisites check passed"
}

function Get-BillingAccount {
    if (-not $BillingAccountId) {
        Write-Info "Listing available billing accounts..."
        gcloud billing accounts list
        $BillingAccountId = Read-Host "Please enter your billing account ID"
    }
    
    # Verify billing account exists and is active
    $billingInfo = gcloud billing accounts describe $BillingAccountId --format="value(open)" 2>$null
    if (-not $billingInfo -or $billingInfo -ne "True") {
        Write-Error "Billing account $BillingAccountId is not found or not active"
        exit 1
    }
    
    Write-Success "Using billing account: $BillingAccountId"
    return $BillingAccountId
}

function New-GcpProject {
    param(
        [hashtable]$ProjectConfig,
        [string]$BillingAccountId,
        [string]$OrganizationId
    )
    
    $projectId = $ProjectConfig.Id
    $projectName = $ProjectConfig.Name
    
    Write-Info "Creating project: $projectName ($projectId)"
    
    # Check if project already exists
    $existingProject = gcloud projects describe $projectId 2>$null
    if ($existingProject) {
        Write-Warning "Project $projectId already exists. Skipping creation."
        return
    }
    
    # Create project
    $createCmd = "gcloud projects create $projectId --name=`"$projectName`""
    if ($OrganizationId) {
        $createCmd += " --organization=$OrganizationId"
    }
    
    Invoke-Expression $createCmd
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create project $projectId"
        return
    }
    
    # Link billing account
    Write-Info "Linking billing account to project $projectId"
    gcloud billing projects link $projectId --billing-account=$BillingAccountId
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to link billing account to project $projectId"
        return
    }
    
    Write-Success "Project $projectId created and billing linked"
}

function Enable-ProjectApis {
    param(
        [string]$ProjectId,
        [string[]]$Apis
    )
    
    Write-Info "Enabling APIs for project $ProjectId"
    
    # Set active project
    gcloud config set project $ProjectId
    
    foreach ($api in $Apis) {
        Write-Info "Enabling API: $api"
        gcloud services enable $api
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to enable API: $api"
        }
    }
    
    Write-Success "APIs enabled for project $ProjectId"
}

function Set-BasicIamPolicies {
    param([string]$ProjectId)
    
    Write-Info "Setting up basic IAM policies for project $ProjectId"
    
    # Set active project
    gcloud config set project $ProjectId
    
    # Get current user
    $currentUser = gcloud config get-value account
    
    # Grant necessary roles to current user
    $roles = @(
        "roles/editor",
        "roles/secretmanager.admin",
        "roles/iam.serviceAccountAdmin",
        "roles/cloudsql.admin"
    )
    
    foreach ($role in $roles) {
        Write-Info "Granting role $role to $currentUser"
        gcloud projects add-iam-policy-binding $ProjectId --member="user:$currentUser" --role=$role
    }
    
    Write-Success "Basic IAM policies set for project $ProjectId"
}

function New-ServiceAccountKeys {
    param([string]$ProjectId)
    
    Write-Info "Creating service account keys for project $ProjectId"
    
    # Set active project
    gcloud config set project $ProjectId
    
    # Create a deployment service account
    $saName = "terraform-deployment"
    $saEmail = "$saName@$ProjectId.iam.gserviceaccount.com"
    
    Write-Info "Creating service account: $saName"
    gcloud iam service-accounts create $saName --display-name="Terraform Deployment Service Account"
    
    # Grant necessary roles to service account
    $roles = @(
        "roles/editor",
        "roles/iam.serviceAccountAdmin",
        "roles/secretmanager.admin",
        "roles/cloudsql.admin"
    )
    
    foreach ($role in $roles) {
        gcloud projects add-iam-policy-binding $ProjectId --member="serviceAccount:$saEmail" --role=$role
    }
    
    # Create and download key
    $keyFile = "$ProjectId-terraform-key.json"
    gcloud iam service-accounts keys create $keyFile --iam-account=$saEmail
    
    Write-Success "Service account key created: $keyFile"
    Write-Warning "Store this key file securely and do not commit it to version control!"
}

function Test-Infrastructure {
    Write-Info "Testing infrastructure setup..."
    
    foreach ($config in $ProjectConfigs) {
        $projectId = $config.Id
        Write-Info "Testing project: $projectId"
        
        # Set active project
        gcloud config set project $projectId
        
        # List enabled services
        Write-Info "Enabled APIs:"
        gcloud services list --enabled --format="value(name)" | Select-Object -First 5
        
        # Check billing
        $billingInfo = gcloud billing projects describe $projectId --format="value(billingEnabled)"
        if ($billingInfo -eq "True") {
            Write-Success "Billing is enabled for $projectId"
        } else {
            Write-Warning "Billing may not be properly configured for $projectId"
        }
        
        Write-Host ""
    }
}

function Show-NextSteps {
    Write-Success "GCP Infrastructure Bootstrap Complete!"
    Write-Host ""
    Write-Info "Next steps:"
    Write-Host "1. Review the created service account keys and store them securely"
    Write-Host "2. Set up Terraform backend (optional):"
    Write-Host "   gsutil mb gs://YOUR-TERRAFORM-STATE-BUCKET"
    Write-Host "3. Run Terraform deployment:"
    Write-Host "   .\deploy.ps1 dev plan"
    Write-Host "   .\deploy.ps1 dev apply"
    Write-Host "4. Configure CI/CD with the service account keys"
    Write-Host "5. Set up monitoring and alerting"
    Write-Host ""
    Write-Warning "Remember to:"
    Write-Host "- Store service account keys securely"
    Write-Host "- Review and adjust IAM permissions as needed"
    Write-Host "- Set up proper backup and disaster recovery procedures"
    Write-Host "- Configure monitoring and alerting"
}

# Main execution
function Main {
    Write-Info "Starting GCP Infrastructure Bootstrap"
    Write-Host ""
    
    Test-Prerequisites
    $billingAccount = Get-BillingAccount
    
    Write-Info "Creating projects..."
    foreach ($config in $ProjectConfigs) {
        New-GcpProject $config $billingAccount $OrganizationId
        Enable-ProjectApis $config.Id $RequiredApis
        Set-BasicIamPolicies $config.Id
        New-ServiceAccountKeys $config.Id
        Write-Host ""
    }
    
    Test-Infrastructure
    Show-NextSteps
}

# Run main function
try {
    Main
} catch {
    Write-Error "Bootstrap failed: $($_.Exception.Message)"
    exit 1
}
