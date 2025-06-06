#!/usr/bin/env powershell
# Setup monitoring and alerting for the Gen Z Video API
# This script configures basic monitoring for the Cloud Run service

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectId = "project-pod-dev",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "asia-east1",
    
    [Parameter(Mandatory=$false)]
    [string]$ServiceName = "genz-video-api"
)

$ErrorActionPreference = "Stop"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    $colorMap = @{
        "Red" = "Red"
        "Green" = "Green"
        "Yellow" = "Yellow"
        "Blue" = "Blue"
        "White" = "White"
        "Magenta" = "Magenta"
    }
    
    Write-Host $Message -ForegroundColor $colorMap[$Color]
}

Write-ColorOutput "📊 Setting up monitoring for Gen Z Video API" "Blue"
Write-ColorOutput "Project: $ProjectId" "White"
Write-ColorOutput "Service: $ServiceName" "White"
Write-ColorOutput "" "White"

# Set the project
gcloud config set project $ProjectId

# Enable required APIs
Write-ColorOutput "🔧 Enabling monitoring APIs..." "Yellow"
$apis = @(
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "clouderrorreporting.googleapis.com"
)

foreach ($api in $apis) {
    try {
        gcloud services enable $api --quiet
        Write-ColorOutput "✅ Enabled $api" "Green"
    } catch {
        Write-ColorOutput "⚠️  Warning: Could not enable $api" "Yellow"
    }
}

Write-ColorOutput "" "White"
Write-ColorOutput "📈 Monitoring Setup Complete!" "Green"
Write-ColorOutput "" "White"
Write-ColorOutput "🎯 Access your monitoring data:" "Blue"
Write-ColorOutput "   Cloud Monitoring: https://console.cloud.google.com/monitoring/overview?project=$ProjectId" "Magenta"
Write-ColorOutput "   Cloud Logging: https://console.cloud.google.com/logs/query?project=$ProjectId" "Magenta"
Write-ColorOutput "   Error Reporting: https://console.cloud.google.com/errors?project=$ProjectId" "Magenta"
Write-ColorOutput "   Cloud Run Metrics: https://console.cloud.google.com/run/detail/$Region/$ServiceName/metrics?project=$ProjectId" "Magenta"
Write-ColorOutput "" "White"
Write-ColorOutput "📋 Recommended next steps:" "Yellow"
Write-ColorOutput "1. Set up alerting policies for error rates and latency" "White"
Write-ColorOutput "2. Configure log-based metrics for business logic monitoring" "White"
Write-ColorOutput "3. Set up uptime checks for critical endpoints" "White"
Write-ColorOutput "4. Create a dashboard for key API metrics" "White"
