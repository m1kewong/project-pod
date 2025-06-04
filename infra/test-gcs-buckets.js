// Test script to check GCS bucket access
// Run with: node test-gcs-buckets.js

const { Storage } = require('@google-cloud/storage');

async function testGCSBuckets() {
  try {
    console.log('Testing GCS bucket access...');
    
    // Initialize the storage client using default credentials
    const storage = new Storage();
    
    // Bucket names
    const uploadsBucketName = 'project-pod-dev-uploads';
    const publicBucketName = 'project-pod-dev-public';
    
    console.log(`Testing access to uploads bucket: ${uploadsBucketName}`);
    const [uploadsBucketExists] = await storage.bucket(uploadsBucketName).exists();
    console.log(`Uploads bucket exists: ${uploadsBucketExists}`);
    
    if (uploadsBucketExists) {
      console.log('Listing some files in uploads bucket:');
      const [files] = await storage.bucket(uploadsBucketName).getFiles({ maxResults: 5 });
      console.log(`Found ${files.length} files`);
      files.forEach(file => {
        console.log(`- ${file.name}`);
      });
    }
    
    console.log(`\nTesting access to public bucket: ${publicBucketName}`);
    const [publicBucketExists] = await storage.bucket(publicBucketName).exists();
    console.log(`Public bucket exists: ${publicBucketExists}`);
    
    if (publicBucketExists) {
      console.log('Listing some files in public bucket:');
      const [files] = await storage.bucket(publicBucketName).getFiles({ maxResults: 5 });
      console.log(`Found ${files.length} files`);
      files.forEach(file => {
        console.log(`- ${file.name}`);
      });
    }
    
    // Test writing a small test file to the uploads bucket
    if (uploadsBucketExists) {
      console.log('\nTesting upload to uploads bucket...');
      const testFileName = `test-file-${Date.now()}.txt`;
      const testFile = storage.bucket(uploadsBucketName).file(testFileName);
      
      await testFile.save('This is a test file to verify upload functionality', {
        contentType: 'text/plain',
        metadata: { 
          testFile: 'true',
          timestamp: Date.now().toString()
        }
      });
      
      console.log(`Successfully uploaded test file: ${testFileName}`);
      
      // Clean up test file
      console.log('Cleaning up test file...');
      await testFile.delete();
      console.log('Test file deleted');
    }
    
    console.log('\nGCS bucket test completed successfully!');
  } catch (error) {
    console.error('Error testing GCS buckets:', error);
  }
}

testGCSBuckets();
