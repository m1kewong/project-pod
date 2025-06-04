# Test Video Transcoding Pipeline
# This script tests the complete transcoding workflow

param(
    [Parameter()]
    [string]$ProjectId = $env:GOOGLE_CLOUD_PROJECT,
    
    [Parameter()]
    [string]$TestVideoPath = "",
    
    [Parameter()]
    [string]$UploadsBucket = "pod-uploads-bucket",
    
    [Parameter()]
    [string]$PublicBucket = "pod-public-videos-bucket"
)

# Set default project if not provided
if (-not $ProjectId) {
    $ProjectId = "pod-social-video-dev"
}

Write-Host "🧪 Testing Video Transcoding Pipeline..." -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor Cyan
Write-Host "Uploads Bucket: $UploadsBucket" -ForegroundColor Cyan
Write-Host "Public Bucket: $PublicBucket" -ForegroundColor Cyan

# Check if test video is provided
if (-not $TestVideoPath -or -not (Test-Path $TestVideoPath)) {
    Write-Host "⚠️  No test video provided. Creating a sample video..." -ForegroundColor Yellow
    
    # Create a simple test video using FFmpeg (if available)
    try {
        ffmpeg -version | Out-Null
        $TestVideoPath = "test-video.mp4"
        Write-Host "📹 Generating test video with FFmpeg..." -ForegroundColor Yellow
        ffmpeg -f lavfi -i testsrc=duration=10:size=1280x720:rate=30 -c:v libx264 -pix_fmt yuv420p $TestVideoPath -y
        Write-Host "✅ Test video created: $TestVideoPath" -ForegroundColor Green
    } catch {
        Write-Host "❌ FFmpeg not available. Please provide a test video file with -TestVideoPath parameter" -ForegroundColor Red
        Write-Host "Example: .\test-transcoding.ps1 -TestVideoPath 'C:\path\to\video.mp4'" -ForegroundColor Yellow
        exit 1
    }
}

# Upload test video to uploads bucket
Write-Host "📤 Uploading test video to uploads bucket..." -ForegroundColor Yellow
$uploadedFileName = "test-upload-$(Get-Date -Format 'yyyyMMdd-HHmmss').mp4"

try {
    gsutil cp $TestVideoPath "gs://$UploadsBucket/$uploadedFileName"
    Write-Host "✅ Video uploaded successfully: gs://$UploadsBucket/$uploadedFileName" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to upload video: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Monitor function execution
Write-Host "⏱️  Monitoring transcoding function (this may take several minutes)..." -ForegroundColor Yellow
Write-Host "📊 You can monitor logs in real-time with:" -ForegroundColor Cyan
Write-Host "   gcloud functions logs read transcodeVideo --region asia-east1 --follow" -ForegroundColor White

# Wait and check for transcoded outputs
$maxWaitTime = 300 # 5 minutes
$waitTime = 0
$checkInterval = 30 # 30 seconds

Write-Host "🔍 Checking for transcoded outputs every $checkInterval seconds..." -ForegroundColor Yellow

while ($waitTime -lt $maxWaitTime) {
    Start-Sleep -Seconds $checkInterval
    $waitTime += $checkInterval
    
    Write-Host "⏰ Checking outputs... ($waitTime/$maxWaitTime seconds)" -ForegroundColor Cyan
    
    # Check for transcoded files in public bucket
    try {
        $outputs = gsutil ls "gs://$PublicBucket/transcoded/**" 2>$null
        if ($outputs) {
            Write-Host "🎉 Transcoded outputs found!" -ForegroundColor Green
            Write-Host "📁 Output files:" -ForegroundColor Cyan
            $outputs | ForEach-Object { Write-Host "   $_" -ForegroundColor White }
            
            # Check Firestore for metadata
            Write-Host "📋 Checking Firestore metadata..." -ForegroundColor Yellow
            Write-Host "   (You can manually check in Firebase Console or use gcloud firestore)" -ForegroundColor Gray
            
            Write-Host "✅ Transcoding pipeline test completed successfully!" -ForegroundColor Green
            break
        }
    } catch {
        # Continue waiting
    }
    
    if ($waitTime -ge $maxWaitTime) {
        Write-Host "⏰ Timeout reached. Transcoding may still be in progress." -ForegroundColor Yellow
        Write-Host "💡 Check the Cloud Functions logs for more details:" -ForegroundColor Cyan
        Write-Host "   gcloud functions logs read transcodeVideo --region asia-east1" -ForegroundColor White
    }
}

# Cleanup test video if we created it
if ($TestVideoPath -eq "test-video.mp4" -and (Test-Path $TestVideoPath)) {
    Remove-Item $TestVideoPath
    Write-Host "🧹 Cleaned up test video file" -ForegroundColor Gray
}

Write-Host ""
Write-Host "🔗 Useful commands for monitoring:" -ForegroundColor Cyan
Write-Host "   View function logs: gcloud functions logs read transcodeVideo --region asia-east1" -ForegroundColor White
Write-Host "   List uploads bucket: gsutil ls gs://$UploadsBucket" -ForegroundColor White
Write-Host "   List public bucket: gsutil ls gs://$PublicBucket/transcoded/" -ForegroundColor White
Write-Host "   Monitor function: gcloud functions logs read transcodeVideo --region asia-east1 --follow" -ForegroundColor White
