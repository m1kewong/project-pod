# Video Transcoding Cloud Functions

This directory contains Google Cloud Functions for automatically transcoding videos uploaded to the platform. The transcoding pipeline converts uploaded videos into multiple formats optimized for web delivery.

## Overview

The transcoding pipeline includes:

- **Input**: Videos uploaded to `pod-uploads-bucket` (private bucket)
- **Processing**: Cloud Function triggered by new uploads
- **Transcoding**: GCP Transcoder API generates multiple outputs
- **Output**: Transcoded files stored in `pod-public-videos-bucket` (public bucket)
- **Metadata**: Video information and URLs stored in Firestore

## Features

### Video Outputs
- **HLS Streaming**: Adaptive bitrate streaming with HD (720p) and SD (480p) variants
- **MP4 Download**: High-quality MP4 file for direct download
- **Thumbnails**: Auto-generated thumbnail sprites for video previews

### Quality Variants
- **HD (720p)**: 1280x720, 2.5 Mbps, 30fps
- **SD (480p)**: 854x480, 1 Mbps, 30fps
- **Audio**: AAC, 128 kbps, 44.1 kHz stereo

### Metadata Management
- Automatic Firestore updates with transcoding status
- Output URLs for all generated files
- Error handling and failure notifications
- Processing timestamps and job tracking

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Flutter App   │───▶│  Firebase Storage │───▶│ GCS Uploads     │
│                 │    │                  │    │ (Private)       │
└─────────────────┘    └──────────────────┘    └─────────┬───────┘
                                                          │
                                                          ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Firestore     │◀───│  Cloud Function  │◀───│ Cloud Storage   │
│   (Metadata)    │    │  (Transcoding)   │    │ Trigger         │
└─────────────────┘    └─────────┬────────┘    └─────────────────┘
                                 │
                                 ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ GCS Public      │◀───│ Transcoder API   │    │ Video Processing │
│ (Outputs)       │    │                  │    │ • HLS           │
└─────────────────┘    └──────────────────┘    │ • MP4           │
                                                │ • Thumbnails    │
                                                └─────────────────┘
```

## Files

- `index.js` - Main Cloud Function code
- `package.json` - Node.js dependencies and scripts
- `deploy.sh` - Linux/macOS deployment script
- `deploy.ps1` - Windows PowerShell deployment script
- `test-transcoding.ps1` - End-to-end testing script

## Prerequisites

1. **Google Cloud Project** with billing enabled
2. **Enabled APIs**:
   - Cloud Functions API
   - Transcoder API
   - Cloud Storage API
   - Firestore API
3. **Authentication**: gcloud CLI authenticated
4. **Buckets**: 
   - `pod-uploads-bucket` (private, for raw uploads)
   - `pod-public-videos-bucket` (public, for transcoded outputs)

## Quick Start

### 1. Setup Environment

```powershell
# Set your project ID
$env:GOOGLE_CLOUD_PROJECT = "your-project-id"

# Navigate to functions directory
cd server/functions
```

### 2. Deploy Function

```powershell
# Windows
.\deploy.ps1

# Or Linux/macOS
chmod +x deploy.sh
./deploy.sh
```

### 3. Test Pipeline

```powershell
# Test with a sample video
.\test-transcoding.ps1 -TestVideoPath "path/to/test-video.mp4"

# Or let the script generate a test video (requires FFmpeg)
.\test-transcoding.ps1
```

## Configuration

### Environment Variables

The function uses these environment variables:

- `GOOGLE_CLOUD_PROJECT` - GCP project ID
- `GCLOUD_PROJECT` - Alternative project ID variable

### Bucket Configuration

Update these constants in `index.js` if using different bucket names:

```javascript
const UPLOADS_BUCKET = 'pod-uploads-bucket';
const PUBLIC_BUCKET = 'pod-public-videos-bucket';
```

### Transcoding Settings

The transcoding job creates multiple outputs:

```javascript
// Video qualities available
const qualities = {
  hd: { width: 1280, height: 720, bitrate: 2500000 },
  sd: { width: 854, height: 480, bitrate: 1000000 }
};

// Audio settings
const audio = {
  codec: 'aac',
  bitrate: 128000,
  channels: 2,
  sampleRate: 44100
};
```

## Monitoring

### View Function Logs

```powershell
# Real-time logs
gcloud functions logs read transcodeVideo --region asia-east1 --follow

# Recent logs
gcloud functions logs read transcodeVideo --region asia-east1 --limit 50
```

### Check Function Status

```powershell
# Function details
gcloud functions describe transcodeVideo --region asia-east1

# List all functions
gcloud functions list --region asia-east1
```

### Monitor Storage

```powershell
# Check uploads bucket
gsutil ls gs://pod-uploads-bucket

# Check public outputs
gsutil ls gs://pod-public-videos-bucket/transcoded/

# Get file details
gsutil ls -l gs://pod-public-videos-bucket/transcoded/**
```

## Troubleshooting

### Common Issues

1. **Function Not Triggering**
   - Verify bucket trigger is configured: `gcloud functions describe transcodeVideo --region asia-east1`
   - Check file is uploaded to correct bucket
   - Ensure file has video MIME type

2. **Transcoding Fails**
   - Check function logs for error details
   - Verify Transcoder API is enabled
   - Ensure service account has proper permissions

3. **Outputs Missing**
   - Check if transcoding job completed successfully
   - Verify public bucket exists and is accessible
   - Check Firestore for job status

### Debug Commands

```powershell
# Check enabled APIs
gcloud services list --enabled --filter="name:transcoder OR name:functions"

# Check IAM permissions
gcloud projects get-iam-policy $env:GOOGLE_CLOUD_PROJECT

# Test bucket access
gsutil ls gs://pod-uploads-bucket
gsutil ls gs://pod-public-videos-bucket
```

## Cost Optimization

### Transcoder API Pricing

- Processing is charged per minute of input video
- Multiple outputs from single input share processing cost
- Consider using presets for common transcoding patterns

### Cloud Function Optimization

- Function memory: 1024MB (can be reduced for smaller videos)
- Timeout: 540s (9 minutes max for transcoding jobs)
- Consider using Cloud Run for longer processing times

### Storage Costs

- Use lifecycle policies to delete old uploads
- Consider regional storage for frequently accessed content
- Use nearline/coldline storage for archival

## Security

### IAM Roles

The Cloud Function service account needs:

- `roles/transcoder.editor` - Create and manage transcoding jobs
- `roles/storage.objectAdmin` - Read from uploads, write to public bucket
- `roles/datastore.user` - Update Firestore documents

### Bucket Permissions

- **Uploads bucket**: Private, function-only access
- **Public bucket**: Public read access for video delivery
- Use signed URLs for temporary private access

## Performance

### Processing Times

Typical transcoding times (varies by video length and complexity):

- **Short videos** (< 1 min): 30-60 seconds
- **Medium videos** (1-5 min): 1-3 minutes  
- **Long videos** (5+ min): 3-10 minutes

### Scaling

- Cloud Functions auto-scale based on upload volume
- Transcoder API has regional quotas
- Consider using multiple regions for global scaling

## Next Steps

1. **Add webhook notifications** for transcoding completion
2. **Implement retry logic** for failed jobs
3. **Add video analytics** and quality metrics
4. **Optimize for mobile delivery** with additional formats
5. **Add content moderation** before transcoding

## Support

For issues and questions:

1. Check function logs: `gcloud functions logs read transcodeVideo --region asia-east1`
2. Review GCP documentation: [Transcoder API](https://cloud.google.com/transcoder/docs)
3. Monitor quotas and limits in Cloud Console
