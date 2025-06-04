const { Storage } = require('@google-cloud/storage');
const { TranscoderServiceClient } = require('@google-cloud/video-transcoder');
const { Firestore } = require('@google-cloud/firestore');
const admin = require('firebase-admin');
const { v4: uuidv4 } = require('uuid');
const functions = require('@google-cloud/functions-framework');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

// Initialize clients
const storage = new Storage();
const transcoder = new TranscoderServiceClient();
const firestore = new Firestore();

// Configuration
const PROJECT_ID = process.env.GOOGLE_CLOUD_PROJECT || 'project-pod-dev';
const LOCATION = 'asia-east1';
const UPLOADS_BUCKET = 'project-pod-dev-uploads';
const PUBLIC_BUCKET = 'project-pod-dev-public-videos';

/**
 * Cloud Function triggered by video upload to GCS
 * Handles video transcoding, thumbnail generation, and metadata updates
 */
functions.cloudEvent('transcodeVideo', async (cloudEvent) => {
  console.log('Transcoding function triggered:', JSON.stringify(cloudEvent, null, 2));
  
  try {
    const file = cloudEvent.data;
    const bucketName = file.bucket;
    const fileName = file.name;
    const contentType = file.contentType;
    
    // Only process video files from uploads bucket
    if (bucketName !== UPLOADS_BUCKET || !contentType?.startsWith('video/')) {
      console.log(`Skipping non-video file or wrong bucket: ${fileName} (${contentType})`);
      return;
    }
    
    console.log(`Processing video: ${fileName} from bucket: ${bucketName}`);
    
    // Generate unique job ID and output prefix
    const jobId = `transcode-${uuidv4()}`;
    const baseFileName = fileName.replace(/\.[^/.]+$/, ''); // Remove extension
    const outputPrefix = `transcoded/${baseFileName}`;
    
    // Create transcoding job
    const job = await createTranscodingJob(
      `gs://${bucketName}/${fileName}`,
      `gs://${PUBLIC_BUCKET}/${outputPrefix}`,
      jobId
    );
    
    console.log(`Transcoding job created: ${job.name}`);
    
    // Update Firestore with job status
    await updateVideoMetadata(fileName, {
      transcodingJobId: jobId,
      transcodingStatus: 'processing',
      outputPrefix: outputPrefix,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Monitor job completion (in a real scenario, you'd use Pub/Sub for this)
    await monitorTranscodingJob(job.name, fileName, outputPrefix);
    
  } catch (error) {
    console.error('Error in transcoding function:', error);
    throw error;
  }
});

/**
 * Create a transcoding job with multiple outputs
 */
async function createTranscodingJob(inputUri, outputUri, jobId) {
  const parent = `projects/${PROJECT_ID}/locations/${LOCATION}`;
  
  const job = {
    inputUri: inputUri,
    outputUri: outputUri,
    config: {
      elementaryStreams: [
        // Video streams
        {
          key: 'video-stream-hd',
          videoStream: {
            h264: {
              heightPixels: 720,
              widthPixels: 1280,
              bitrateBps: 2500000,
              frameRate: 30,
            },
          },
        },
        {
          key: 'video-stream-sd',
          videoStream: {
            h264: {
              heightPixels: 480,
              widthPixels: 854,
              bitrateBps: 1000000,
              frameRate: 30,
            },
          },
        },
        // Audio stream
        {
          key: 'audio-stream',
          audioStream: {
            codec: 'aac',
            bitrateBps: 128000,
            channelCount: 2,
            sampleRateHertz: 44100,
          },
        },
      ],
      muxStreams: [
        // HLS outputs
        {
          key: 'hls-hd',
          container: 'ts',
          elementaryStreams: ['video-stream-hd', 'audio-stream'],
        },
        {
          key: 'hls-sd',
          container: 'ts',
          elementaryStreams: ['video-stream-sd', 'audio-stream'],
        },
        // MP4 output
        {
          key: 'mp4-hd',
          container: 'mp4',
          elementaryStreams: ['video-stream-hd', 'audio-stream'],
        },
      ],
      manifests: [
        // HLS manifest
        {
          fileName: 'manifest.m3u8',
          type: 'HLS',
          muxStreams: ['hls-hd', 'hls-sd'],
        },
      ],
      // Generate thumbnails
      spriteSheets: [
        {
          fileName: 'thumbnails.jpg',
          filePrefix: 'thumbnail',
          spriteWidthPixels: 128,
          spriteHeightPixels: 72,
          columnCount: 4,
          rowCount: 4,
          interval: '10s',
        },
      ],
    },
  };
  
  const [operation] = await transcoder.createJob({
    parent: parent,
    job: job,
    jobId: jobId,
  });
  
  return operation;
}

/**
 * Monitor transcoding job completion
 */
async function monitorTranscodingJob(jobName, originalFileName, outputPrefix) {
  const maxAttempts = 60; // 10 minutes max
  let attempts = 0;
  
  while (attempts < maxAttempts) {
    try {
      const [job] = await transcoder.getJob({ name: jobName });
      console.log(`Job ${jobName} status: ${job.state}`);
      
      if (job.state === 'SUCCEEDED') {
        console.log('Transcoding completed successfully');
        await handleTranscodingSuccess(originalFileName, outputPrefix);
        return;
      } else if (job.state === 'FAILED') {
        console.error('Transcoding failed:', job.error);
        await handleTranscodingFailure(originalFileName, job.error);
        return;
      }
      
      // Wait 10 seconds before checking again
      await new Promise(resolve => setTimeout(resolve, 10000));
      attempts++;
      
    } catch (error) {
      console.error('Error monitoring job:', error);
      attempts++;
      await new Promise(resolve => setTimeout(resolve, 10000));
    }
  }
  
  console.error('Job monitoring timed out');
  await handleTranscodingFailure(originalFileName, 'Monitoring timeout');
}

/**
 * Handle successful transcoding
 */
async function handleTranscodingSuccess(originalFileName, outputPrefix) {
  try {
    // List all output files
    const [files] = await storage.bucket(PUBLIC_BUCKET).getFiles({
      prefix: outputPrefix,
    });
    
    const outputs = {
      hls: null,
      mp4: null,
      thumbnails: [],
    };
    
    files.forEach(file => {
      const fileName = file.name;
      if (fileName.endsWith('manifest.m3u8')) {
        outputs.hls = `gs://${PUBLIC_BUCKET}/${fileName}`;
      } else if (fileName.endsWith('.mp4')) {
        outputs.mp4 = `gs://${PUBLIC_BUCKET}/${fileName}`;
      } else if (fileName.includes('thumbnail')) {
        outputs.thumbnails.push(`gs://${PUBLIC_BUCKET}/${fileName}`);
      }
    });
    
    // Update Firestore with output URLs
    await updateVideoMetadata(originalFileName, {
      transcodingStatus: 'completed',
      outputs: outputs,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log('Video metadata updated successfully');
    
  } catch (error) {
    console.error('Error handling transcoding success:', error);
    await handleTranscodingFailure(originalFileName, error.message);
  }
}

/**
 * Handle transcoding failure
 */
async function handleTranscodingFailure(originalFileName, error) {
  try {
    await updateVideoMetadata(originalFileName, {
      transcodingStatus: 'failed',
      error: error.toString(),
      failedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (updateError) {
    console.error('Error updating failure status:', updateError);
  }
}

/**
 * Update video metadata in Firestore
 */
async function updateVideoMetadata(fileName, data) {
  const videoRef = firestore.collection('videos').doc(fileName);
  
  try {
    // Check if document exists
    const doc = await videoRef.get();
    
    if (doc.exists) {
      // Update existing document
      await videoRef.update(data);
    } else {
      // Create new document with basic info
      await videoRef.set({
        originalFileName: fileName,
        uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...data
      });
    }
    
    console.log(`Updated metadata for video: ${fileName}`);
  } catch (error) {
    console.error('Error updating video metadata:', error);
    throw error;
  }
}

// Export the function for deployment
// We don't need to export it again since it's already exported at the function definition
