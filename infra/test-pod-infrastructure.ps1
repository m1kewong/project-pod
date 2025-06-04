#!/usr/bin/env pwsh
# Project Pod Infrastructure Test Script
# Tests all provisioned infrastructure components

param(
    [string]$ProjectId = "",
    [string]$Environment = "dev"
)

# Load configuration
$ConfigPath = Join-Path $PSScriptRoot "config.env"
if (Test-Path $ConfigPath) {
    Get-Content $ConfigPath | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            Set-Variable -Name $matches[1] -Value $matches[2] -Scope Script
        }
    }
}

# Set project based on environment
if ([string]::IsNullOrEmpty($ProjectId)) {
    if ($Environment -eq "prod") {
        $ProjectId = $PROD_PROJECT_ID
    } else {
        $ProjectId = $DEV_PROJECT_ID
    }
}

Write-Host "🧪 Testing Project Pod Infrastructure" -ForegroundColor Green
Write-Host "Project ID: $ProjectId" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Cyan

# Set project context
gcloud config set project $ProjectId | Out-Null

$TestResults = @()

# Function to run test and capture result
function Test-Component {
    param(
        [string]$Name,
        [scriptblock]$TestScript
    )
    
    Write-Host "`n🔍 Testing: $Name" -ForegroundColor Blue
    
    try {
        $result = & $TestScript
        if ($result) {
            Write-Host "   ✅ PASS" -ForegroundColor Green
            $script:TestResults += @{ Name = $Name; Status = "PASS"; Details = "" }
        } else {
            Write-Host "   ❌ FAIL" -ForegroundColor Red
            $script:TestResults += @{ Name = $Name; Status = "FAIL"; Details = "Test returned false" }
        }
    } catch {
        Write-Host "   ❌ FAIL: $($_.Exception.Message)" -ForegroundColor Red
        $script:TestResults += @{ Name = $Name; Status = "FAIL"; Details = $_.Exception.Message }
    }
}

# Test 1: Project exists and is accessible
Test-Component "Project Access" {
    $project = gcloud projects describe $ProjectId --format="value(projectId)" 2>$null
    return $project -eq $ProjectId
}

# Test 2: Required APIs are enabled
Test-Component "Required APIs" {
    $enabledAPIs = gcloud services list --enabled --format="value(config.name)" --project=$ProjectId
    $requiredAPIs = @(
        "cloudbuild.googleapis.com",
        "run.googleapis.com",
        "firestore.googleapis.com",
        "storage.googleapis.com",
        "cloudfunctions.googleapis.com",
        "transcoder.googleapis.com"
    )
    
    $missingAPIs = $requiredAPIs | Where-Object { $_ -notin $enabledAPIs }
    if ($missingAPIs.Count -eq 0) {
        return $true
    } else {
        Write-Host "   Missing APIs: $($missingAPIs -join ', ')" -ForegroundColor Yellow
        return $false
    }
}

# Test 3: Service accounts exist
Test-Component "Service Accounts" {
    $serviceAccounts = gcloud iam service-accounts list --format="value(email)" --project=$ProjectId
    $requiredSAs = @(
        "$SA_BACKEND@$ProjectId.iam.gserviceaccount.com",
        "$SA_FUNCTIONS@$ProjectId.iam.gserviceaccount.com",
        "$SA_STORAGE@$ProjectId.iam.gserviceaccount.com",
        "$SA_TRANSCODER@$ProjectId.iam.gserviceaccount.com"
    )
    
    $missingSAs = $requiredSAs | Where-Object { $_ -notin $serviceAccounts }
    if ($missingSAs.Count -eq 0) {
        return $true
    } else {
        Write-Host "   Missing Service Accounts: $($missingSAs -join ', ')" -ForegroundColor Yellow
        return $false
    }
}

# Test 4: Storage buckets exist
Test-Component "Storage Buckets" {
    $buckets = gcloud storage buckets list --format="value(name)" --project=$ProjectId
    $requiredBuckets = @(
        "$ProjectId-$BUCKET_UPLOADS",
        "$ProjectId-$BUCKET_PUBLIC",
        "$ProjectId-$BUCKET_THUMBNAILS"
    )
    
    $missingBuckets = $requiredBuckets | Where-Object { "gs://$_" -notin $buckets }
    if ($missingBuckets.Count -eq 0) {
        return $true
    } else {
        Write-Host "   Missing Buckets: $($missingBuckets -join ', ')" -ForegroundColor Yellow
        return $false
    }
}

# Test 5: Firestore database exists
Test-Component "Firestore Database" {
    try {
        $databases = gcloud firestore databases list --format="value(name)" --project=$ProjectId 2>$null
        return $databases.Count -gt 0
    } catch {
        return $false
    }
}

# Test 6: Artifact Registry repository exists
Test-Component "Artifact Registry" {
    $repos = gcloud artifacts repositories list --location=$REGION --format="value(name)" --project=$ProjectId 2>$null
    return $repos -match "pod-docker-repo"
}

# Test 7: Secrets exist
Test-Component "Secret Manager" {
    $secrets = gcloud secrets list --format="value(name)" --project=$ProjectId 2>$null
    $requiredSecrets = @(
        "jwt-secret",
        "database-url",
        "firebase-admin-key"
    )
    
    $missingSecrets = $requiredSecrets | Where-Object { $_ -notin $secrets }
    if ($missingSecrets.Count -eq 0) {
        return $true
    } else {
        Write-Host "   Missing Secrets: $($missingSecrets -join ', ')" -ForegroundColor Yellow
        return $false
    }
}

# Test 8: IAM permissions (basic check)
Test-Component "IAM Permissions" {
    try {
        $bindings = gcloud projects get-iam-policy $ProjectId --format="value(bindings.members)" 2>$null
        $backendSA = "$SA_BACKEND@$ProjectId.iam.gserviceaccount.com"
        return $bindings -match $backendSA
    } catch {
        return $false
    }
}

# Summary
Write-Host "`n📊 Test Summary" -ForegroundColor Magenta
Write-Host "=" * 50

$passCount = ($TestResults | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($TestResults | Where-Object { $_.Status -eq "FAIL" }).Count

foreach ($result in $TestResults) {
    $color = if ($result.Status -eq "PASS") { "Green" } else { "Red" }
    $icon = if ($result.Status -eq "PASS") { "✅" } else { "❌" }
    Write-Host "$icon $($result.Name): $($result.Status)" -ForegroundColor $color
    
    if ($result.Status -eq "FAIL" -and $result.Details) {
        Write-Host "   Details: $($result.Details)" -ForegroundColor Gray
    }
}

Write-Host "`nOverall Results:" -ForegroundColor Cyan
Write-Host "  Passed: $passCount" -ForegroundColor Green
Write-Host "  Failed: $failCount" -ForegroundColor Red
Write-Host "  Total:  $($TestResults.Count)" -ForegroundColor White

if ($failCount -eq 0) {
    Write-Host "`n🎉 All tests passed! Infrastructure is ready." -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n⚠️  Some tests failed. Please review and fix issues." -ForegroundColor Yellow
    exit 1
}
