# GCP Infrastructure Testing Script
# This script validates that all infrastructure components are properly configured
# Usage: .\test-infrastructure.ps1 <environment>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment
)

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TerraformDir = Join-Path $ScriptDir "terraform"

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

function Test-TerraformState {
    Write-Info "Testing Terraform state..."
    
    Set-Location $TerraformDir
    
    # Select workspace
    terraform workspace select $Environment
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to select Terraform workspace: $Environment"
        return $false
    }
    
    # Check Terraform state
    $state = terraform show -json | ConvertFrom-Json
    if (-not $state) {
        Write-Error "No Terraform state found for environment: $Environment"
        return $false
    }
    
    Write-Success "Terraform state is valid"
    return $true
}

function Test-EnabledApis {
    param([string]$ProjectId)
    
    Write-Info "Testing enabled APIs for project: $ProjectId"
    
    $requiredApis = @(
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
    
    gcloud config set project $ProjectId
    $enabledApis = gcloud services list --enabled --format="value(name)"
    
    $missingApis = @()
    foreach ($api in $requiredApis) {
        if ($enabledApis -notcontains $api) {
            $missingApis += $api
        }
    }
    
    if ($missingApis.Count -eq 0) {
        Write-Success "All required APIs are enabled"
        return $true
    } else {
        Write-Error "Missing APIs: $($missingApis -join ', ')"
        return $false
    }
}

function Test-ServiceAccounts {
    param([string]$ProjectId)
    
    Write-Info "Testing service accounts for project: $ProjectId"
    
    gcloud config set project $ProjectId
    
    $expectedServiceAccounts = @(
        "$Environment-cloudrun-sa@$ProjectId.iam.gserviceaccount.com",
        "$Environment-video-processor-sa@$ProjectId.iam.gserviceaccount.com",
        "$Environment-client-sa@$ProjectId.iam.gserviceaccount.com"
    )
    
    $serviceAccounts = gcloud iam service-accounts list --format="value(email)"
    
    $missingServiceAccounts = @()
    foreach ($sa in $expectedServiceAccounts) {
        if ($serviceAccounts -notcontains $sa) {
            $missingServiceAccounts += $sa
        }
    }
    
    if ($missingServiceAccounts.Count -eq 0) {
        Write-Success "All service accounts exist"
        return $true
    } else {
        Write-Error "Missing service accounts: $($missingServiceAccounts -join ', ')"
        return $false
    }
}

function Test-CloudStorage {
    param([string]$ProjectId)
    
    Write-Info "Testing Cloud Storage buckets for project: $ProjectId"
    
    gcloud config set project $ProjectId
    
    $expectedBuckets = @(
        "$ProjectId-$Environment-video-uploads",
        "$ProjectId-$Environment-video-processed"
    )
    
    $buckets = gsutil ls | ForEach-Object { $_.Trim('gs://').Trim('/') }
    
    $missingBuckets = @()
    foreach ($bucket in $expectedBuckets) {
        if ($buckets -notcontains $bucket) {
            $missingBuckets += $bucket
        }
    }
    
    if ($missingBuckets.Count -eq 0) {
        Write-Success "All storage buckets exist"
        return $true
    } else {
        Write-Error "Missing buckets: $($missingBuckets -join ', ')"
        return $false
    }
}

function Test-CloudSQL {
    param([string]$ProjectId)
    
    Write-Info "Testing Cloud SQL instance for project: $ProjectId"
    
    gcloud config set project $ProjectId
    
    $instanceName = "$ProjectId-$Environment-db"
    $instances = gcloud sql instances list --format="value(name)"
    
    if ($instances -contains $instanceName) {
        # Check instance status
        $status = gcloud sql instances describe $instanceName --format="value(state)"
        if ($status -eq "RUNNABLE") {
            Write-Success "Cloud SQL instance is running"
            return $true
        } else {
            Write-Warning "Cloud SQL instance exists but status is: $status"
            return $false
        }
    } else {
        Write-Error "Cloud SQL instance not found: $instanceName"
        return $false
    }
}

function Test-CloudRun {
    param([string]$ProjectId)
    
    Write-Info "Testing Cloud Run service for project: $ProjectId"
    
    gcloud config set project $ProjectId
    
    $serviceName = "$ProjectId-$Environment-backend"
    $services = gcloud run services list --region=asia-east1 --format="value(metadata.name)"
    
    if ($services -contains $serviceName) {
        # Check service status
        $url = gcloud run services describe $serviceName --region=asia-east1 --format="value(status.url)"
        if ($url) {
            Write-Success "Cloud Run service is deployed: $url"
            return $true
        } else {
            Write-Warning "Cloud Run service exists but no URL found"
            return $false
        }
    } else {
        Write-Warning "Cloud Run service not found: $serviceName (may not be deployed yet)"
        return $false
    }
}

function Test-SecretManager {
    param([string]$ProjectId)
    
    Write-Info "Testing Secret Manager for project: $ProjectId"
    
    gcloud config set project $ProjectId
    
    $expectedSecrets = @(
        "$Environment-db-password",
        "$Environment-jwt-secret"
    )
    
    $secrets = gcloud secrets list --format="value(name)"
    
    $missingSecrets = @()
    foreach ($secret in $expectedSecrets) {
        if ($secrets -notlike "*$secret*") {
            $missingSecrets += $secret
        }
    }
    
    if ($missingSecrets.Count -eq 0) {
        Write-Success "All secrets exist in Secret Manager"
        return $true
    } else {
        Write-Error "Missing secrets: $($missingSecrets -join ', ')"
        return $false
    }
}

function Test-IAMPermissions {
    param([string]$ProjectId)
    
    Write-Info "Testing IAM permissions for project: $ProjectId"
    
    gcloud config set project $ProjectId
    
    # Test if current user can access necessary services
    $tests = @(
        @{ Command = "gcloud projects describe $ProjectId"; Description = "Project access" },
        @{ Command = "gcloud iam service-accounts list"; Description = "Service account access" },
        @{ Command = "gcloud secrets list"; Description = "Secret Manager access" },
        @{ Command = "gsutil ls"; Description = "Storage access" }
    )
    
    $passed = 0
    foreach ($test in $tests) {
        try {
            Invoke-Expression $test.Command > $null 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✓ $($test.Description)"
                $passed++
            } else {
                Write-Error "✗ $($test.Description)"
            }
        } catch {
            Write-Error "✗ $($test.Description): $($_.Exception.Message)"
        }
    }
    
    return $passed -eq $tests.Count
}

function Show-TestResults {
    param([hashtable]$Results)
    
    Write-Host ""
    Write-Info "=== TEST RESULTS SUMMARY ==="
    
    $totalTests = $Results.Count
    $passedTests = ($Results.Values | Where-Object { $_ -eq $true }).Count
    $failedTests = $totalTests - $passedTests
    
    foreach ($test in $Results.Keys) {
        $status = if ($Results[$test]) { "PASS" } else { "FAIL" }
        $color = if ($Results[$test]) { "Green" } else { "Red" }
        Write-Host "  $test`: $status" -ForegroundColor $color
    }
    
    Write-Host ""
    if ($failedTests -eq 0) {
        Write-Success "All tests passed! Infrastructure is properly configured."
    } else {
        Write-Warning "$failedTests out of $totalTests tests failed. Please review the issues above."
    }
    
    return $failedTests -eq 0
}

# Main execution
function Main {
    Write-Info "Starting infrastructure testing for environment: $Environment"
    Write-Host ""
    
    # Get project ID from tfvars
    $tfvarsFile = Join-Path $TerraformDir "$Environment.tfvars"
    if (-not (Test-Path $tfvarsFile)) {
        Write-Error "Configuration file not found: $Environment.tfvars"
        exit 1
    }
    
    $projectId = (Get-Content $tfvarsFile | Where-Object { $_ -like "project_id*" } | ForEach-Object { ($_ -split '=')[1].Trim().Trim('"') })
    if (-not $projectId) {
        Write-Error "Could not determine project ID from $Environment.tfvars"
        exit 1
    }
    
    Write-Info "Testing project: $projectId"
    Write-Host ""
    
    # Run tests
    $testResults = @{
        "Terraform State" = Test-TerraformState
        "Enabled APIs" = Test-EnabledApis $projectId
        "Service Accounts" = Test-ServiceAccounts $projectId
        "Cloud Storage" = Test-CloudStorage $projectId
        "Cloud SQL" = Test-CloudSQL $projectId
        "Cloud Run" = Test-CloudRun $projectId
        "Secret Manager" = Test-SecretManager $projectId
        "IAM Permissions" = Test-IAMPermissions $projectId
    }
    
    $allPassed = Show-TestResults $testResults
    
    if ($allPassed) {
        Write-Success "Infrastructure testing completed successfully!"
        exit 0
    } else {
        Write-Error "Infrastructure testing failed. Please fix the issues and try again."
        exit 1
    }
}

# Run main function
try {
    Main
} catch {
    Write-Error "Testing failed: $($_.Exception.Message)"
    exit 1
}
