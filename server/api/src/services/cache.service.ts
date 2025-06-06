import Redis from 'ioredis';
import NodeCache from 'node-cache';
import { config } from '../config';
import { logger } from '../utils/logger';

class CacheService {
  private static instance: CacheService;
  private redisClient: Redis | null = null;
  private memoryCache: NodeCache;
  private isRedisConnected = false;  private constructor() {
    // Initialize in-memory cache as fallback
    this.memoryCache = new NodeCache({
      stdTTL: config.cache.ttl,
      maxKeys: config.cache.maxKeys,
      useClones: false,
    });

    // Only try Redis if not using memory-only mode
    if (config.redis.url !== 'memory://localhost') {
      // Initialize Redis asynchronously (don't await in constructor)
      this.initializeRedis().catch(error => {
        logger.warn('Redis initialization failed, using memory cache only:', error);
      });
    } else {
      logger.info('Using memory-only cache mode');
    }
  }

  public static getInstance(): CacheService {
    if (!CacheService.instance) {
      CacheService.instance = new CacheService();
    }
    return CacheService.instance;
  }  public async initialize(): Promise<void> {
    // This method allows external initialization
    // The actual Redis initialization happens in the constructor
    if (this.redisClient && config.redis.lazyConnect && !this.isRedisConnected) {
      try {
        await this.redisClient.connect();
        this.isRedisConnected = true;
      } catch (error) {
        logger.warn('Failed to connect to Redis, falling back to memory cache:', error);
        this.redisClient = null;
      }
    }
  }

  public isInitialized(): boolean {
    // Cache service is always initialized since we have memory fallback
    return true;
  }
  private async initializeRedis(): Promise<void> {
    try {
      // Skip Redis if using default localhost URL (for local development)
      if (config.redis.url === 'redis://localhost:6379') {
        logger.info('Skipping Redis connection for local development, using memory cache only');
        return;
      }

      // Parse Redis URL or use individual options
      if (config.redis.url && config.redis.url !== 'redis://localhost:6379') {
        this.redisClient = new Redis(config.redis.url, {
          password: config.redis.password,
          db: config.redis.db,
          maxRetriesPerRequest: config.redis.maxRetriesPerRequest,
          lazyConnect: config.redis.lazyConnect,
        });
      } else {
        this.redisClient = new Redis({
          host: 'localhost',
          port: 6379,
          password: config.redis.password,
          db: config.redis.db,
          maxRetriesPerRequest: config.redis.maxRetriesPerRequest,
          lazyConnect: config.redis.lazyConnect,
        });
      }

      this.redisClient.on('connect', () => {
        this.isRedisConnected = true;
        logger.info('Redis connected successfully');
      });

      this.redisClient.on('error', (error) => {
        this.isRedisConnected = false;
        logger.error('Redis connection error', error);
      });

      this.redisClient.on('close', () => {
        this.isRedisConnected = false;
        logger.warn('Redis connection closed');
      });

      // Test connection only if not using lazy connect
      if (!config.redis.lazyConnect) {
        await this.redisClient.ping();
      }
    } catch (error) {
      logger.error('Failed to initialize Redis, falling back to memory cache', error);
      this.redisClient = null;
      this.isRedisConnected = false;
    }
  }

  public async get<T>(key: string): Promise<T | null> {
    try {
      // Try Redis first if available
      if (this.redisClient && this.isRedisConnected) {
        const value = await this.redisClient.get(key);
        return value ? JSON.parse(value) : null;
      }

      // Fallback to memory cache
      return this.memoryCache.get<T>(key) || null;
    } catch (error) {
      logger.error(`Cache get error for key: ${key}`, error);
      return null;
    }
  }

  public async set(key: string, value: any, ttl?: number): Promise<boolean> {
    try {
      const serializedValue = JSON.stringify(value);
      const expiration = ttl || config.cache.ttl;

      // Try Redis first if available
      if (this.redisClient && this.isRedisConnected) {
        await this.redisClient.setex(key, expiration, serializedValue);
        return true;
      }

      // Fallback to memory cache
      return this.memoryCache.set(key, value, expiration);
    } catch (error) {
      logger.error(`Cache set error for key: ${key}`, error);
      return false;
    }
  }

  public async del(key: string): Promise<boolean> {
    try {
      // Try Redis first if available
      if (this.redisClient && this.isRedisConnected) {
        const result = await this.redisClient.del(key);
        return result > 0;
      }

      // Fallback to memory cache
      return this.memoryCache.del(key) > 0;
    } catch (error) {
      logger.error(`Cache delete error for key: ${key}`, error);
      return false;
    }
  }

  public async exists(key: string): Promise<boolean> {
    try {
      // Try Redis first if available
      if (this.redisClient && this.isRedisConnected) {
        const result = await this.redisClient.exists(key);
        return result > 0;
      }

      // Fallback to memory cache
      return this.memoryCache.has(key);
    } catch (error) {
      logger.error(`Cache exists error for key: ${key}`, error);
      return false;
    }
  }

  public async flush(): Promise<boolean> {
    try {
      // Try Redis first if available
      if (this.redisClient && this.isRedisConnected) {
        await this.redisClient.flushdb();
      }

      // Clear memory cache
      this.memoryCache.flushAll();
      return true;
    } catch (error) {
      logger.error('Cache flush error', error);
      return false;
    }
  }

  public async getStats() {
    const stats = {
      redis: {
        connected: this.isRedisConnected,
        info: null as any,
      },
      memory: {
        keys: this.memoryCache.keys().length,
        stats: this.memoryCache.getStats(),
      },
    };

    if (this.redisClient && this.isRedisConnected) {
      try {
        const info = await this.redisClient.info('memory');
        stats.redis.info = info;
      } catch (error) {
        logger.error('Failed to get Redis stats', error);
      }
    }

    return stats;
  }

  public async disconnect(): Promise<void> {
    if (this.redisClient) {
      await this.redisClient.quit();
    }
    this.memoryCache.close();
  }
}

export const cacheService = CacheService.getInstance();
