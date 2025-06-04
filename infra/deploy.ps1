# GCP Infrastructure Deployment Script (PowerShell)
# Usage: .\deploy.ps1 <environment> [action]
# Example: .\deploy.ps1 dev apply

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("init", "validate", "plan", "apply", "destroy", "output")]
    [string]$Action = "plan"
)

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TerraformDir = Join-Path $ScriptDir "terraform"

# Functions
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

function Show-Usage {
    Write-Host "Usage: .\deploy.ps1 <environment> [action]"
    Write-Host ""
    Write-Host "Environments:"
    Write-Host "  dev      - Development environment"
    Write-Host "  staging  - Staging environment"
    Write-Host "  prod     - Production environment"
    Write-Host ""
    Write-Host "Actions:"
    Write-Host "  plan     - Show what Terraform will do (default)"
    Write-Host "  apply    - Apply the Terraform configuration"
    Write-Host "  destroy  - Destroy the infrastructure"
    Write-Host "  init     - Initialize Terraform"
    Write-Host "  validate - Validate Terraform configuration"
    Write-Host "  output   - Show Terraform outputs"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\deploy.ps1 dev plan     # Plan development deployment"
    Write-Host "  .\deploy.ps1 prod apply   # Deploy to production"
    Write-Host "  .\deploy.ps1 dev output   # Show development outputs"
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
    
    # Check if terraform is installed
    try {
        $null = Get-Command terraform -ErrorAction Stop
    } catch {
        Write-Error "Terraform is not installed. Please install it first."
        exit 1
    }
    
    # Check if user is authenticated
    $authOutput = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
    if (-not $authOutput) {
        Write-Error "You are not authenticated with gcloud. Please run 'gcloud auth login'"
        exit 1
    }
    
    Write-Success "Prerequisites check passed"
}

function Initialize-Terraform {
    param([string]$Environment)
    
    Write-Info "Setting up Terraform for environment: $Environment"
    
    Set-Location $TerraformDir
    
    # Initialize Terraform if needed
    if (-not (Test-Path ".terraform")) {
        Write-Info "Initializing Terraform..."
        terraform init
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Terraform initialization failed"
            exit 1
        }
    }
    
    # Create or select workspace
    $workspaces = terraform workspace list
    if ($workspaces -notmatch $Environment) {
        Write-Info "Creating Terraform workspace: $Environment"
        terraform workspace new $Environment
    } else {
        Write-Info "Selecting Terraform workspace: $Environment"
        terraform workspace select $Environment
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform workspace setup failed"
        exit 1
    }
    
    Write-Success "Terraform setup complete"
}

function Test-Environment {
    param([string]$Environment)
    
    # Check if tfvars file exists
    $tfvarsFile = Join-Path $TerraformDir "$Environment.tfvars"
    if (-not (Test-Path $tfvarsFile)) {
        Write-Error "Configuration file not found: $Environment.tfvars"
        exit 1
    }
}

function Invoke-Terraform {
    param(
        [string]$Environment,
        [string]$Action
    )
    
    $tfvarsFile = "$Environment.tfvars"
    $planFile = "$Environment.tfplan"
    
    Set-Location $TerraformDir
    
    switch ($Action) {
        "init" {
            terraform init
        }
        "validate" {
            terraform validate
        }
        "plan" {
            terraform plan -var-file=$tfvarsFile -out=$planFile
        }
        "apply" {
            if (Test-Path $planFile) {
                terraform apply $planFile
            } else {
                Write-Warning "No plan file found. Running plan first..."
                terraform plan -var-file=$tfvarsFile -out=$planFile
                if ($LASTEXITCODE -eq 0) {
                    terraform apply $planFile
                }
            }
        }
        "destroy" {
            Write-Warning "This will destroy all infrastructure in the $Environment environment!"
            $confirm = Read-Host "Are you sure? Type 'yes' to continue"
            if ($confirm -eq "yes") {
                terraform destroy -var-file=$tfvarsFile
            } else {
                Write-Info "Destroy cancelled"
                return
            }
        }
        "output" {
            terraform output
        }
        default {
            Write-Error "Unknown action: $Action"
            Show-Usage
            exit 1
        }
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform command failed with exit code: $LASTEXITCODE"
        exit 1
    }
}

# Main execution
function Main {
    Write-Info "Starting deployment for environment: $Environment, action: $Action"
    
    Test-Environment $Environment
    Test-Prerequisites
    Initialize-Terraform $Environment
    Invoke-Terraform $Environment $Action
    
    Write-Success "Deployment completed successfully!"
}

# Run main function
try {
    Main
} catch {
    Write-Error "Deployment failed: $($_.Exception.Message)"
    exit 1
}
