import { Request, Response, NextFunction } from 'express';
import { firebaseService } from '../services/firebase.service';
import { logger } from '../utils/logger';
import { ApiError } from '../utils/errors';

export interface AuthenticatedRequest extends Request {
  user?: {
    uid: string;
    email?: string | undefined;
    name?: string | undefined;
    picture?: string | undefined;
    emailVerified?: boolean | undefined;
    provider?: string | undefined;
    roles?: string[] | undefined;
    [key: string]: any;
  };
}

export const authenticateToken = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;

    if (!token) {
      throw new ApiError(401, 'Authentication token required');
    }

    // Verify the Firebase ID token
    const decodedToken = await firebaseService.verifyIdToken(token);
      // Extract user information
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      name: decodedToken['name'],
      picture: decodedToken.picture,
      emailVerified: decodedToken.email_verified,
      provider: decodedToken.firebase.sign_in_provider,
      roles: ['user'], // Default role
    };

    logger.debug('User authenticated successfully', {
      uid: req.user.uid,
      email: req.user.email || 'unknown',
    });

    next();
  } catch (error) {
    logger.error('Authentication failed', error);
    
    if (error instanceof ApiError) {
      res.status(error.statusCode).json({
        success: false,
        error: error.message,
        code: 'AUTH_FAILED',
      });
    } else {
      res.status(401).json({
        success: false,
        error: 'Invalid or expired token',
        code: 'AUTH_FAILED',
      });
    }
  }
};

export const optionalAuth = async (
  req: AuthenticatedRequest,
  _res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;

    if (token) {
      try {
        const decodedToken = await firebaseService.verifyIdToken(token);        req.user = {
          uid: decodedToken.uid,
          email: decodedToken.email,
          name: decodedToken['name'],
          picture: decodedToken.picture,
          emailVerified: decodedToken.email_verified,
          provider: decodedToken.firebase.sign_in_provider,
          roles: ['user'], // Default role
        };
      } catch (tokenError) {
        logger.warn('Optional auth token invalid', tokenError);
        // Continue without user context
      }
    }

    next();
  } catch (error) {
    logger.error('Optional authentication middleware error', error);
    next(); // Continue without user context
  }
};

export const requireRole = (requiredRoles: string[]) => {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction): void => {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
      });
      return;
    }    const userRoles = req.user?.['roles'] || ['user'];
    const hasRequiredRole = requiredRoles.some(role => userRoles.includes(role));

    if (!hasRequiredRole) {
      res.status(403).json({
        success: false,
        error: 'Insufficient permissions',
        code: 'INSUFFICIENT_PERMISSIONS',
        required: requiredRoles,
        current: userRoles,
      });
      return;
    }

    next();
  };
};

export const requireAdmin = requireRole(['admin']);
export const requireModerator = requireRole(['admin', 'moderator']);

// Remove duplicate export declaration
