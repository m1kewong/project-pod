import { Request, Response, NextFunction } from 'express';
import { ApiError } from '../utils/errors';
import { logger } from '../utils/logger';

export const errorHandler = (
  error: Error,
  req: Request,
  res: Response,
  _next: NextFunction
): void => {
  // Log the error
  logger.error('Error occurred', {
    error: error.message,
    stack: error.stack,
    path: req.path,
    method: req.method,
    ip: req.ip,
    userId: (req as any).user?.uid,
  });

  // Handle known API errors
  if (error instanceof ApiError) {
    res.status(error.statusCode).json({
      success: false,
      error: error.message,
      code: error.code,
      ...(error.details && { details: error.details }),
    });
    return;
  }

  // Handle validation errors from express-validator
  if (error.name === 'ValidationError') {
    res.status(400).json({
      success: false,
      error: 'Validation failed',
      code: 'VALIDATION_ERROR',
      details: error.message,
    });
    return;
  }

  // Handle Firebase errors
  if (error.message?.includes('Firebase')) {
    res.status(500).json({
      success: false,
      error: 'Firebase service error',
      code: 'FIREBASE_ERROR',
    });
    return;
  }

  // Handle database errors
  if (error.message?.includes('Firestore') || error.message?.includes('database')) {
    res.status(500).json({
      success: false,
      error: 'Database service error',
      code: 'DATABASE_ERROR',
    });
    return;
  }

  // Handle syntax errors
  if (error instanceof SyntaxError && 'body' in error) {
    res.status(400).json({
      success: false,
      error: 'Invalid JSON in request body',
      code: 'INVALID_JSON',
    });
    return;
  }

  // Handle CORS errors
  if (error.message?.includes('CORS')) {
    res.status(403).json({
      success: false,
      error: 'CORS policy violation',
      code: 'CORS_ERROR',
    });
    return;
  }

  // Default error response
  res.status(500).json({
    success: false,
    error: 'Internal server error',
    code: 'INTERNAL_SERVER_ERROR',
  });
};

export const notFoundHandler = (req: Request, res: Response): void => {
  logger.warn('Route not found', {
    path: req.path,
    method: req.method,
    ip: req.ip,
  });

  res.status(404).json({
    success: false,
    error: 'Route not found',
    code: 'ROUTE_NOT_FOUND',
    path: req.path,
    method: req.method,
  });
};

export const asyncHandler = (fn: Function) => {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};
