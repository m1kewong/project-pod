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

// Video routes
router.get('/videos/feed', 
  basicRateLimit,
  optionalAuth,
  paginationValidation,
  handleValidationErrors,
  videoController.getFeed
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
