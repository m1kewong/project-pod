import { body, param, query, ValidationChain } from 'express-validator';

// User validation schemas
export const createUserValidation: ValidationChain[] = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Valid email is required'),
  body('displayName')
    .isLength({ min: 2, max: 50 })
    .trim()
    .withMessage('Display name must be between 2 and 50 characters'),
  body('username')
    .isLength({ min: 3, max: 30 })
    .matches(/^[a-zA-Z0-9_]+$/)
    .withMessage('Username must be 3-30 characters and contain only letters, numbers, and underscores'),
  body('bio')
    .optional()
    .isLength({ max: 500 })
    .withMessage('Bio must be less than 500 characters'),
];

export const updateUserValidation: ValidationChain[] = [
  param('userId')
    .isLength({ min: 1 })
    .withMessage('User ID is required'),
  body('displayName')
    .optional()
    .isLength({ min: 2, max: 50 })
    .trim()
    .withMessage('Display name must be between 2 and 50 characters'),
  body('bio')
    .optional()
    .isLength({ max: 500 })
    .withMessage('Bio must be less than 500 characters'),
  body('profilePicture')
    .optional()
    .isURL()
    .withMessage('Profile picture must be a valid URL'),
];

// Video validation schemas
export const createVideoValidation: ValidationChain[] = [
  body('title')
    .isLength({ min: 1, max: 100 })
    .trim()
    .withMessage('Title is required and must be less than 100 characters'),
  body('description')
    .optional()
    .isLength({ max: 1000 })
    .withMessage('Description must be less than 1000 characters'),
  body('tags')
    .optional()
    .isArray({ max: 10 })
    .withMessage('Tags must be an array with maximum 10 items'),
  body('tags.*')
    .optional()
    .isLength({ min: 1, max: 30 })
    .matches(/^[a-zA-Z0-9_]+$/)
    .withMessage('Each tag must be 1-30 characters and contain only letters, numbers, and underscores'),
  body('visibility')
    .isIn(['public', 'private', 'unlisted'])
    .withMessage('Visibility must be public, private, or unlisted'),
  body('thumbnailUrl')
    .optional()
    .isURL()
    .withMessage('Thumbnail URL must be a valid URL'),
];

export const updateVideoValidation: ValidationChain[] = [
  param('videoId')
    .isLength({ min: 1 })
    .withMessage('Video ID is required'),
  body('title')
    .optional()
    .isLength({ min: 1, max: 100 })
    .trim()
    .withMessage('Title must be less than 100 characters'),
  body('description')
    .optional()
    .isLength({ max: 1000 })
    .withMessage('Description must be less than 1000 characters'),
  body('tags')
    .optional()
    .isArray({ max: 10 })
    .withMessage('Tags must be an array with maximum 10 items'),
  body('visibility')
    .optional()
    .isIn(['public', 'private', 'unlisted'])
    .withMessage('Visibility must be public, private, or unlisted'),
];

// Comment validation schemas
export const createCommentValidation: ValidationChain[] = [
  param('videoId')
    .isLength({ min: 1 })
    .withMessage('Video ID is required'),
  body('content')
    .isLength({ min: 1, max: 1000 })
    .trim()
    .withMessage('Comment content is required and must be less than 1000 characters'),
  body('parentId')
    .optional()
    .isLength({ min: 1 })
    .withMessage('Parent comment ID must be valid'),
];

export const updateCommentValidation: ValidationChain[] = [
  param('commentId')
    .isLength({ min: 1 })
    .withMessage('Comment ID is required'),
  body('content')
    .isLength({ min: 1, max: 1000 })
    .trim()
    .withMessage('Comment content is required and must be less than 1000 characters'),
];

// Danmu validation schemas
export const createDanmuValidation: ValidationChain[] = [
  param('videoId')
    .isLength({ min: 1 })
    .withMessage('Video ID is required'),
  body('content')
    .isLength({ min: 1, max: 100 })
    .trim()
    .withMessage('Danmu content is required and must be less than 100 characters'),
  body('timestamp')
    .isNumeric({ no_symbols: true })
    .isFloat({ min: 0 })
    .withMessage('Timestamp must be a positive number'),
  body('color')
    .optional()
    .matches(/^#[0-9A-Fa-f]{6}$/)
    .withMessage('Color must be a valid hex color code'),
  body('size')
    .optional()
    .isIn(['small', 'medium', 'large'])
    .withMessage('Size must be small, medium, or large'),
  body('position')
    .optional()
    .isIn(['top', 'bottom', 'scroll'])
    .withMessage('Position must be top, bottom, or scroll'),
];

// Query validation schemas
export const paginationValidation: ValidationChain[] = [
  query('page')
    .optional()
    .isInt({ min: 1 })
    .toInt()
    .withMessage('Page must be a positive integer'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .toInt()
    .withMessage('Limit must be between 1 and 100'),
];

export const searchValidation: ValidationChain[] = [
  query('q')
    .optional()
    .isLength({ min: 1, max: 100 })
    .trim()
    .withMessage('Search query must be between 1 and 100 characters'),
  query('sort')
    .optional()
    .isIn(['relevance', 'date', 'views', 'likes'])
    .withMessage('Sort must be relevance, date, views, or likes'),
  query('order')
    .optional()
    .isIn(['asc', 'desc'])
    .withMessage('Order must be asc or desc'),
];

// Like/Unlike validation
export const likeValidation: ValidationChain[] = [
  param('videoId')
    .isLength({ min: 1 })
    .withMessage('Video ID is required'),
];

// Follow/Unfollow validation
export const followValidation: ValidationChain[] = [
  param('userId')
    .isLength({ min: 1 })
    .withMessage('User ID is required'),
];

// Upload validation
export const uploadValidation: ValidationChain[] = [
  body('filename')
    .isLength({ min: 1, max: 255 })
    .withMessage('Filename is required and must be less than 255 characters'),
  body('contentType')
    .isIn(['video/mp4', 'video/mov', 'video/avi', 'video/webm'])
    .withMessage('Content type must be a supported video format'),
  body('size')
    .isInt({ min: 1, max: 100 * 1024 * 1024 }) // 100MB max
    .withMessage('File size must be between 1 byte and 100MB'),
];
