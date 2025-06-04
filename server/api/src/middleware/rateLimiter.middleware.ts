import rateLimit from 'express-rate-limit';
import { Request, Response } from 'express';
import { config } from '../config';
import { cacheService } from '../services/cache.service';
import { logger } from '../utils/logger';

// Create a rate limiter store using Redis/cache
const createCacheStore = () => {
  return {
    async incr(key: string): Promise<{ totalHits: number; resetTime?: Date }> {
      const current = await cacheService.get<number>(key) || 0;
      const newValue = current + 1;
      await cacheService.set(key, newValue, config.rateLimit.windowMs / 1000);
      
      return {
        totalHits: newValue,
        resetTime: new Date(Date.now() + config.rateLimit.windowMs),
      };
    },

    async decrement(key: string): Promise<void> {
      const current = await cacheService.get<number>(key) || 0;
      if (current > 0) {
        await cacheService.set(key, current - 1, config.rateLimit.windowMs / 1000);
      }
    },

    async resetKey(key: string): Promise<void> {
      await cacheService.del(key);
    },
  };
};

// Generate rate limit key based on IP and user
const generateKey = (req: Request): string => {
  const user = (req as any).user;
  if (user?.uid) {
    return `rate_limit:user:${user.uid}`;
  }
  return `rate_limit:ip:${req.ip}`;
};

// Basic rate limiter
export const basicRateLimit = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.max,
  standardHeaders: config.rateLimit.standardHeaders,
  legacyHeaders: config.rateLimit.legacyHeaders,
  keyGenerator: generateKey,
  store: createCacheStore(),
  handler: (req: Request, res: Response) => {
    logger.warn('Rate limit exceeded', {
      ip: req.ip,
      userId: (req as any).user?.uid,
      path: req.path,
      method: req.method,
    });

    res.status(429).json({
      success: false,
      error: 'Too many requests, please try again later',
      code: 'RATE_LIMIT_EXCEEDED',
      retryAfter: Math.ceil(config.rateLimit.windowMs / 1000),
    });
  },
});

// Strict rate limiter for sensitive operations
export const strictRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // 10 requests per window
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: generateKey,
  store: createCacheStore(),
  handler: (req: Request, res: Response) => {
    logger.warn('Strict rate limit exceeded', {
      ip: req.ip,
      userId: (req as any).user?.uid,
      path: req.path,
      method: req.method,
    });

    res.status(429).json({
      success: false,
      error: 'Too many sensitive operations, please try again later',
      code: 'STRICT_RATE_LIMIT_EXCEEDED',
      retryAfter: 15 * 60, // 15 minutes
    });
  },
});

// Upload rate limiter
export const uploadRateLimit = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 20, // 20 uploads per hour
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: generateKey,
  store: createCacheStore(),
  handler: (req: Request, res: Response) => {
    logger.warn('Upload rate limit exceeded', {
      ip: req.ip,
      userId: (req as any).user?.uid,
      path: req.path,
    });

    res.status(429).json({
      success: false,
      error: 'Upload quota exceeded, please try again later',
      code: 'UPLOAD_RATE_LIMIT_EXCEEDED',
      retryAfter: 60 * 60, // 1 hour
    });
  },
});

// API rate limiter for external integrations
export const apiRateLimit = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 60, // 60 requests per minute
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req: Request) => {
    const apiKey = req.headers['x-api-key'] as string;
    return apiKey ? `rate_limit:api:${apiKey}` : `rate_limit:ip:${req.ip}`;
  },
  store: createCacheStore(),
  handler: (req: Request, res: Response) => {
    logger.warn('API rate limit exceeded', {
      ip: req.ip,
      apiKey: req.headers['x-api-key'],
      path: req.path,
      method: req.method,
    });

    res.status(429).json({
      success: false,
      error: 'API rate limit exceeded',
      code: 'API_RATE_LIMIT_EXCEEDED',
      retryAfter: 60,
    });
  },
});

// Dynamic rate limiter based on user tier
export const dynamicRateLimit = (req: Request, res: Response, next: any) => {
  const user = (req as any).user;
  let maxRequests = config.rateLimit.max;

  // Adjust rate limit based on user tier
  if (user?.tier === 'premium') {
    maxRequests = maxRequests * 2;
  } else if (user?.tier === 'pro') {
    maxRequests = maxRequests * 5;
  }

  const dynamicLimiter = rateLimit({
    windowMs: config.rateLimit.windowMs,
    max: maxRequests,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: generateKey,
    store: createCacheStore(),
    handler: (_req: Request, res: Response) => {
      res.status(429).json({
        success: false,
        error: 'Rate limit exceeded for your tier',
        code: 'TIER_RATE_LIMIT_EXCEEDED',
        tier: user?.tier || 'free',
        retryAfter: Math.ceil(config.rateLimit.windowMs / 1000),
      });
    },
  });

  dynamicLimiter(req, res, next);
};
