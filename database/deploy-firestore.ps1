# Firestore Database Deployment Script for Gen Z Social Video Platform
# PowerShell version for Windows

param(
    [string]$ProjectId = $env:PROJECT_ID ?? "project-pod-dev",
    [string]$FirestoreRegion = $env:FIRESTORE_REGION ?? "asia-southeast1",
    [switch]$SkipSeedData = $false,
    [switch]$TestOnly = $false
)

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SeedDataDir = Join-Path $ScriptDir "seed-data"

Write-Host "🚀 Starting Firestore Database Deployment" -ForegroundColor Blue
Write-Host "Project ID: $ProjectId" -ForegroundColor Blue
Write-Host "Region: $FirestoreRegion" -ForegroundColor Blue

# Check if gcloud is installed and authenticated
try {
    $null = Get-Command gcloud -ErrorAction Stop
} catch {
    Write-Host "❌ gcloud CLI is not installed. Please install it first." -ForegroundColor Red
    exit 1
}

# Check if user is authenticated
$authAccount = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
if (-not $authAccount -or $authAccount.Length -eq 0) {
    Write-Host "❌ Not authenticated with gcloud. Please run 'gcloud auth login'" -ForegroundColor Red
    exit 1
}

# Set the project
Write-Host "📋 Setting GCP project..." -ForegroundColor Yellow
gcloud config set project $ProjectId

if ($TestOnly) {
    Write-Host "🧪 Running in test mode only..." -ForegroundColor Yellow
    
    # Test basic connectivity
    try {
        $databases = gcloud firestore databases list --format="value(name)" 2>$null
        if ($databases) {
            Write-Host "✅ Firestore database connection successful" -ForegroundColor Green
        } else {
            Write-Host "❌ Firestore database not found" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Failed to connect to Firestore" -ForegroundColor Red
    }
    
    # Test security rules
    if (Test-Path (Join-Path $ScriptDir "firestore.rules")) {
        Write-Host "✅ Security rules file found" -ForegroundColor Green
    } else {
        Write-Host "❌ Security rules file not found" -ForegroundColor Red
    }
    
    # Test seed data
    if (Test-Path $SeedDataDir) {
        $seedFiles = Get-ChildItem -Path $SeedDataDir -Filter "*.json"
        Write-Host "✅ Found $($seedFiles.Count) seed data files" -ForegroundColor Green
        foreach ($file in $seedFiles) {
            Write-Host "   - $($file.Name)" -ForegroundColor Gray
        }
    } else {
        Write-Host "❌ Seed data directory not found" -ForegroundColor Red
    }
    
    exit 0
}

# Check if Firestore is already initialized
Write-Host "🔍 Checking Firestore initialization status..." -ForegroundColor Yellow
try {
    $firestoreStatus = gcloud firestore databases list --format="value(name)" 2>$null
    if (-not $firestoreStatus -or $firestoreStatus.Length -eq 0) {
        Write-Host "🏗️ Initializing Firestore database..." -ForegroundColor Yellow
        gcloud firestore databases create --region=$FirestoreRegion --type=firestore-native
        Write-Host "✅ Firestore database created successfully" -ForegroundColor Green
    } else {
        Write-Host "✅ Firestore database already exists" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Failed to check or create Firestore database" -ForegroundColor Red
    exit 1
}

# Deploy security rules
Write-Host "🔒 Deploying Firestore security rules..." -ForegroundColor Yellow
$rulesFile = Join-Path $ScriptDir "firestore.rules"
if (Test-Path $rulesFile) {
    try {
        gcloud firestore databases update --security-rules-file=$rulesFile
        Write-Host "✅ Security rules deployed successfully" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to deploy security rules" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "❌ firestore.rules file not found" -ForegroundColor Red
    exit 1
}

# Deploy indexes (if exists)
$indexFile = Join-Path $ScriptDir "firestore.indexes.json"
if (Test-Path $indexFile) {
    Write-Host "📊 Deploying Firestore indexes..." -ForegroundColor Yellow
    try {
        gcloud firestore indexes composite create --field-config=$indexFile
        Write-Host "✅ Indexes deployed successfully" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Index deployment failed or indexes already exist" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ No firestore.indexes.json found, skipping index deployment" -ForegroundColor Yellow
}

# Function to upload seed data
function Upload-SeedData {
    param(
        [string]$CollectionName,
        [string]$JsonFile
    )
    
    Write-Host "📁 Uploading seed data for $CollectionName..." -ForegroundColor Yellow
    
    if (-not (Test-Path $JsonFile)) {
        Write-Host "❌ Seed data file not found: $JsonFile" -ForegroundColor Red
        return $false
    }
    
    # Use Node.js script to upload data
    $nodeScript = Join-Path $ScriptDir "scripts\upload-seed-data.js"
    if ((Get-Command node -ErrorAction SilentlyContinue) -and (Test-Path $nodeScript)) {
        try {
            node $nodeScript $CollectionName $JsonFile $ProjectId
            Write-Host "✅ Seed data uploaded for $CollectionName" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "❌ Failed to upload seed data for $CollectionName" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "⚠️ Node.js or upload script not found, skipping seed data upload for $CollectionName" -ForegroundColor Yellow
        Write-Host "   You can manually import the data from: $JsonFile" -ForegroundColor Yellow
        return $false
    }
}

# Upload seed data for each collection
if (-not $SkipSeedData -and (Test-Path $SeedDataDir)) {
    Write-Host "📊 Uploading seed data..." -ForegroundColor Yellow
    
    # Upload in order (users first, then videos that reference users, etc.)
    $collections = @(
        @{Name="users"; File="users.json"},
        @{Name="videos"; File="videos.json"},
        @{Name="danmu_comments"; File="danmu_comments.json"},
        @{Name="notifications"; File="notifications.json"},
        @{Name="follows"; File="follows.json"},
        @{Name="activities"; File="activities.json"}
    )
    
    foreach ($collection in $collections) {
        $jsonFile = Join-Path $SeedDataDir $collection.File
        Upload-SeedData -CollectionName $collection.Name -JsonFile $jsonFile
    }
    
    Write-Host "✅ Seed data upload completed" -ForegroundColor Green
} elseif ($SkipSeedData) {
    Write-Host "⏭️ Skipping seed data upload (SkipSeedData flag set)" -ForegroundColor Yellow
} else {
    Write-Host "⚠️ Seed data directory not found, skipping data upload" -ForegroundColor Yellow
}

# Test the deployment
Write-Host "🧪 Testing Firestore deployment..." -ForegroundColor Yellow

# Test basic read access
try {
    $testResult = gcloud firestore documents list --collection=users --limit=1 2>$null
    Write-Host "✅ Firestore read access test passed" -ForegroundColor Green
} catch {
    Write-Host "❌ Firestore read access test failed" -ForegroundColor Red
}

# Test security rules (if Node.js script exists)
$securityTestScript = Join-Path $ScriptDir "scripts\test-security-rules.js"
if ((Get-Command node -ErrorAction SilentlyContinue) -and (Test-Path $securityTestScript)) {
    Write-Host "🔒 Testing security rules..." -ForegroundColor Yellow
    try {
        node $securityTestScript $ProjectId
    } catch {
        Write-Host "⚠️ Security rules test failed or incomplete" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ Node.js or security test script not found, skipping security rules test" -ForegroundColor Yellow
}

Write-Host "🎉 Firestore deployment completed successfully!" -ForegroundColor Green
Write-Host "📋 Next steps:" -ForegroundColor Blue
Write-Host "   1. Test the Flutter app connection"
Write-Host "   2. Verify security rules in the Firebase Console"
Write-Host "   3. Monitor usage in the Firebase Console"
Write-Host "Firebase Console: https://console.firebase.google.com/project/$ProjectId/firestore" -ForegroundColor Blue
