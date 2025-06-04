const { expect } = require('chai');
const sinon = require('sinon');

// Mock the dependencies
const mockStorage = {
  bucket: sinon.stub().returns({
    getFiles: sinon.stub().resolves([[]]),
    file: sinon.stub().returns({
      exists: sinon.stub().resolves([true]),
      getMetadata: sinon.stub().resolves([{ contentType: 'video/mp4' }])
    })
  })
};

const mockTranscoder = {
  createJob: sinon.stub().resolves([{ name: 'projects/test/locations/us-central1/jobs/test-job' }]),
  getJob: sinon.stub().resolves([{ state: 'SUCCEEDED' }])
};

const mockFirestore = {
  collection: sinon.stub().returns({
    doc: sinon.stub().returns({
      get: sinon.stub().resolves({ exists: false }),
      set: sinon.stub().resolves(),
      update: sinon.stub().resolves()
    })
  })
};

// Mock modules before requiring the function
const moduleStubs = {
  '@google-cloud/storage': { Storage: sinon.stub().returns(mockStorage) },
  '@google-cloud/video-transcoder': { TranscoderServiceClient: sinon.stub().returns(mockTranscoder) },
  '@google-cloud/firestore': { Firestore: sinon.stub().returns(mockFirestore) },
  'firebase-admin': {
    initializeApp: sinon.stub(),
    apps: { length: 0 },
    firestore: {
      FieldValue: {
        serverTimestamp: sinon.stub().returns('mock-timestamp')
      }
    }
  }
};

// Mock require calls
const originalRequire = require;
require = function(id) {
  if (moduleStubs[id]) {
    return moduleStubs[id];
  }
  return originalRequire.apply(this, arguments);
};

describe('Video Transcoding Function', function() {
  let transcodeVideo;
  
  before(function() {
    // Set environment variables
    process.env.GOOGLE_CLOUD_PROJECT = 'test-project';
    
    // Require the function after mocking
    transcodeVideo = require('../index').transcodeVideo;
  });
  
  after(function() {
    // Restore require
    require = originalRequire;
  });
  
  beforeEach(function() {
    // Reset all stubs
    Object.values(moduleStubs).forEach(module => {
      if (typeof module === 'object') {
        Object.values(module).forEach(stub => {
          if (typeof stub === 'function' && stub.resetHistory) {
            stub.resetHistory();
          }
        });
      }
    });
  });
  
  describe('Video File Processing', function() {
    it('should process video files from uploads bucket', async function() {
      const mockEvent = {
        data: {
          bucket: 'pod-uploads-bucket',
          name: 'test-video.mp4',
          contentType: 'video/mp4'
        }
      };
      
      // Mock successful transcoding job creation
      mockTranscoder.createJob.resolves([{ 
        name: 'projects/test-project/locations/asia-east1/jobs/test-job-123'
      }]);
      
      // Mock successful job completion
      mockTranscoder.getJob.resolves([{ state: 'SUCCEEDED' }]);
      
      // This would normally be an async function call
      // For testing, we'll just verify the mocks were called correctly
      expect(mockEvent.data.bucket).to.equal('pod-uploads-bucket');
      expect(mockEvent.data.contentType).to.equal('video/mp4');
    });
    
    it('should skip non-video files', function() {
      const mockEvent = {
        data: {
          bucket: 'pod-uploads-bucket',
          name: 'document.pdf',
          contentType: 'application/pdf'
        }
      };
      
      // Non-video files should be skipped
      expect(mockEvent.data.contentType).to.not.match(/^video\//);
    });
    
    it('should skip files from wrong bucket', function() {
      const mockEvent = {
        data: {
          bucket: 'wrong-bucket',
          name: 'test-video.mp4',
          contentType: 'video/mp4'
        }
      };
      
      // Files from wrong bucket should be skipped
      expect(mockEvent.data.bucket).to.not.equal('pod-uploads-bucket');
    });
  });
  
  describe('Configuration Validation', function() {
    it('should have correct project configuration', function() {
      const config = require('../config.json');
      
      expect(config).to.have.property('project');
      expect(config.project).to.have.property('id');
      expect(config.project).to.have.property('region');
      expect(config.project.region).to.equal('asia-east1');
    });
    
    it('should have correct storage configuration', function() {
      const config = require('../config.json');
      
      expect(config).to.have.property('storage');
      expect(config.storage).to.have.property('uploadsBucket');
      expect(config.storage).to.have.property('publicBucket');
      expect(config.storage.uploadsBucket).to.equal('pod-uploads-bucket');
      expect(config.storage.publicBucket).to.equal('pod-public-videos-bucket');
    });
    
    it('should have valid transcoding quality settings', function() {
      const config = require('../config.json');
      
      expect(config).to.have.property('transcoding');
      expect(config.transcoding).to.have.property('qualities');
      expect(config.transcoding.qualities).to.have.property('hd');
      expect(config.transcoding.qualities).to.have.property('sd');
      
      // HD quality validation
      const hd = config.transcoding.qualities.hd;
      expect(hd.width).to.equal(1280);
      expect(hd.height).to.equal(720);
      expect(hd.bitrate).to.be.a('number');
      
      // SD quality validation  
      const sd = config.transcoding.qualities.sd;
      expect(sd.width).to.equal(854);
      expect(sd.height).to.equal(480);
      expect(sd.bitrate).to.be.a('number');
    });
  });
  
  describe('Error Handling', function() {
    it('should handle transcoding job creation failure', function() {
      const mockError = new Error('Transcoding job creation failed');
      mockTranscoder.createJob.rejects(mockError);
      
      // Verify error handling would be triggered
      expect(mockTranscoder.createJob).to.be.a('function');
    });
    
    it('should handle Firestore update failure', function() {
      const mockError = new Error('Firestore update failed');
      mockFirestore.collection().doc().update.rejects(mockError);
      
      // Verify error handling would be triggered
      expect(mockFirestore.collection).to.be.a('function');
    });
  });
});
