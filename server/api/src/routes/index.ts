import { Router } from 'express';
import { VideoController } from '../controllers/video.controller';
import { UserController } from '../controllers/user.controller';
import { CommentController } from '../controllers/comment.controller';
import { DanmuController } from '../controllers/danmu.controller';
import { authenticateToken, optionalAuth } from '../middleware/auth.middleware';
import { handleValidationErrors } from '../middleware/validation.middleware';
import { basicRateLimit, strictRateLimit, uploadRateLimit } from '../middleware/rateLimiter.middleware';
import {
  createVideoValidation,
  updateVideoValidation,
  updateUserValidation,
  createCommentValidation,
  updateCommentValidation,
  createDanmuValidation,
  paginationValidation,
  searchValidation,
  likeValidation,
} from '../validators';

const router = Router();

// Initialize controllers
const videoController = new VideoController();
const userController = new UserController();
const commentController = new CommentController();
const danmuController = new DanmuController();

// Health check endpoint
router.get('/health', (_req, res) => {
  res.json({
    success: true,
    message: 'API is healthy',
    timestamp: new Date().toISOString(),
    version: process.env['npm_package_version'] || '1.0.0',
  });
});

// Test endpoint without database access
router.get('/test', (_req, res) => {
  res.json({
    success: true,
    message: 'API test endpoint working',
    timestamp: new Date().toISOString(),
    environment: process.env['NODE_ENV'] || 'development',
  });
});

// Minimal endpoint without any middleware
router.get('/simple', (_req, res) => {
  res.json({ success: true, message: 'Simple endpoint working' });
});

// Mock video feed endpoint without middleware (for testing)
router.get('/videos/feed/simple', (_req: any, res: any) => {
  const mockVideos = [
    {
      id: 'simple-video-1',
      title: 'Simple Test Video',
      description: 'Testing without middleware',
      viewCount: 100,
      likeCount: 5,
      tags: ['test'],
      createdAt: new Date().toISOString(),
    },
  ];

  res.json({
    success: true,
    data: { videos: mockVideos, total: 1 },
  });
});

// Mock video feed endpoint (temporary - for testing deployment)
router.get('/videos/feed/mock', 
  basicRateLimit,
  paginationValidation,
  handleValidationErrors,
  (_req: any, res: any) => {
    const mockVideos = [
      {
        id: 'mock-video-1',
        title: 'Sample Gen Z Video 1',
        description: 'This is a sample video for testing the API',
        thumbnailUrl: 'https://example.com/thumb1.jpg',
        videoUrl: 'https://example.com/video1.mp4',
        duration: 60,
        viewCount: 1000,
        likeCount: 50,
        commentCount: 10,
        tags: ['genz', 'viral', 'trending'],
        createdAt: new Date().toISOString(),
        user: {
          uid: 'mock-user-1',
          displayName: 'Gen Z Creator',
          username: 'genzcreatr',
          profilePicture: 'https://example.com/profile1.jpg',
        },
      },
      {
        id: 'mock-video-2',
        title: 'Sample Gen Z Video 2',
        description: 'Another sample video for testing',
        thumbnailUrl: 'https://example.com/thumb2.jpg',
        videoUrl: 'https://example.com/video2.mp4',
        duration: 90,
        viewCount: 2500,
        likeCount: 120,
        commentCount: 25,
        tags: ['funny', 'viral', 'meme'],
        createdAt: new Date().toISOString(),
        user: {
          uid: 'mock-user-2',
          displayName: 'Viral Content Maker',
          username: 'viralmaker',
          profilePicture: 'https://example.com/profile2.jpg',
        },
      },
    ];

    const result = {
      videos: mockVideos,
      pagination: {
        page: 1,
        limit: 20,
        total: 2,
        hasMore: false,
      },
    };

    res.json({
      success: true,
      data: result,
    });
  }
);

// Video routes
router.get('/videos/feed', 
  basicRateLimit,
  optionalAuth,
  paginationValidation,
  handleValidationErrors,
  videoController.getFeed
);

// Mock feed endpoint for testing
router.get('/videos/mock-feed',
  basicRateLimit,
  paginationValidation,
  handleValidationErrors,
  videoController.getMockFeed
);

router.get('/videos/search',
  basicRateLimit,
  optionalAuth,
  [...searchValidation, ...paginationValidation],
  handleValidationErrors,
  videoController.searchVideos
);

router.get('/videos/:videoId',
  basicRateLimit,
  optionalAuth,
  videoController.getVideo
);

router.post('/videos',
  uploadRateLimit,
  authenticateToken,
  createVideoValidation,
  handleValidationErrors,
  videoController.createVideo
);

router.put('/videos/:videoId',
  strictRateLimit,
  authenticateToken,
  updateVideoValidation,
  handleValidationErrors,
  videoController.updateVideo
);

router.delete('/videos/:videoId',
  strictRateLimit,
  authenticateToken,
  videoController.deleteVideo
);

router.post('/videos/:videoId/like',
  basicRateLimit,
  authenticateToken,
  likeValidation,
  handleValidationErrors,
  videoController.toggleLike
);

// User routes
router.get('/users/:userId',
  basicRateLimit,
  optionalAuth,
  userController.getProfile
);

router.put('/users/:userId',
  strictRateLimit,
  authenticateToken,
  updateUserValidation,
  handleValidationErrors,
  userController.updateProfile
);

router.get('/users/:userId/videos',
  basicRateLimit,
  optionalAuth,
  paginationValidation,
  handleValidationErrors,
  userController.getUserVideos
);

router.post('/users/:userId/follow',
  basicRateLimit,
  authenticateToken,
  userController.toggleFollow
);

router.get('/users/:userId/followers',
  basicRateLimit,
  optionalAuth,
  paginationValidation,
  handleValidationErrors,
  userController.getFollowers
);

router.get('/users/:userId/following',
  basicRateLimit,
  optionalAuth,
  paginationValidation,
  handleValidationErrors,
  userController.getFollowing
);

// Comment routes
router.get('/videos/:videoId/comments',
  basicRateLimit,
  optionalAuth,
  paginationValidation,
  handleValidationErrors,
  commentController.getComments
);

router.get('/comments/:commentId/replies',
  basicRateLimit,
  optionalAuth,
  paginationValidation,
  handleValidationErrors,
  commentController.getReplies
);

router.post('/videos/:videoId/comments',
  basicRateLimit,
  authenticateToken,
  createCommentValidation,
  handleValidationErrors,
  commentController.createComment
);

router.put('/comments/:commentId',
  strictRateLimit,
  authenticateToken,
  updateCommentValidation,
  handleValidationErrors,
  commentController.updateComment
);

router.delete('/comments/:commentId',
  strictRateLimit,
  authenticateToken,
  commentController.deleteComment
);

router.post('/comments/:commentId/like',
  basicRateLimit,
  authenticateToken,
  commentController.toggleLike
);

// Danmu routes
router.get('/videos/:videoId/danmu',
  basicRateLimit,
  optionalAuth,
  danmuController.getDanmu
);

router.post('/videos/:videoId/danmu',
  basicRateLimit,
  authenticateToken,
  createDanmuValidation,
  handleValidationErrors,
  danmuController.createDanmu
);

router.delete('/danmu/:danmuId',
  strictRateLimit,
  authenticateToken,
  danmuController.deleteDanmu
);

router.post('/danmu/:danmuId/hide',
  strictRateLimit,
  authenticateToken,
  danmuController.hideDanmu
);

router.get('/videos/:videoId/danmu/stats',
  basicRateLimit,
  optionalAuth,
  danmuController.getDanmuStats
);

export default router;
