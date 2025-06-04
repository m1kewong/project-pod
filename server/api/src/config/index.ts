import dotenv from 'dotenv';

// Load environment variables as early as possible
dotenv.config();

export const config = {
  // Server Configuration
  port: parseInt(process.env['PORT'] || '8080', 10),
  nodeEnv: process.env['NODE_ENV'] || 'development',
  apiVersion: process.env['API_VERSION'] || 'v1',
  apiUrl: process.env['API_URL'] || 'http://localhost:8080',
  environment: process.env['NODE_ENV'] || 'development',
  corsOrigins: process.env['CORS_ORIGINS']?.split(',') || ['http://localhost:3000'],

  // Firebase Configuration
  firebase: {
    projectId: process.env['FIREBASE_PROJECT_ID'] || '',
    serviceAccountPath: process.env['GOOGLE_APPLICATION_CREDENTIALS'] || '',
  },

  // Redis Configuration
  redis: {
    url: process.env['REDIS_URL'] || 'redis://localhost:6379',
    password: process.env['REDIS_PASSWORD'] || '',
    db: parseInt(process.env['REDIS_DB'] || '0', 10),
    retryDelayOnFailover: 100,
    maxRetriesPerRequest: 3,
    lazyConnect: true,
    keepAlive: 30000,
  },

  // Rate Limiting
  rateLimit: {
    windowMs: parseInt(process.env['RATE_LIMIT_WINDOW_MS'] || '900000', 10), // 15 minutes
    max: parseInt(process.env['RATE_LIMIT_MAX_REQUESTS'] || '100', 10),
    standardHeaders: true,
    legacyHeaders: false,
  },

  // CORS Configuration
  cors: {
    origin: process.env['CORS_ORIGIN']?.split(',') || ['http://localhost:3000'],
    credentials: process.env['CORS_CREDENTIALS'] === 'true',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'x-api-key'],
  },

  // Logging
  logging: {
    level: process.env['LOG_LEVEL'] || 'info',
    format: process.env['LOG_FORMAT'] || 'combined',
  },

  // Security
  security: {
    jwtSecret: process.env['JWT_SECRET'] || 'fallback-secret-change-in-production',
    apiKeyHeader: process.env['API_KEY_HEADER'] || 'x-api-key',
    apiKeys: process.env['API_KEYS']?.split(',') || [],
  },

  // Cache Configuration
  cache: {
    ttl: parseInt(process.env['CACHE_TTL'] || '300', 10), // 5 minutes
    maxKeys: parseInt(process.env['CACHE_MAX_KEYS'] || '1000', 10),
  },

  // File Upload
  upload: {
    maxFileSize: process.env['MAX_FILE_SIZE'] || '100MB',
    allowedTypes: process.env['ALLOWED_FILE_TYPES']?.split(',') || ['video/mp4', 'video/mov', 'video/avi'],
  },

  // Database Connection Pool
  database: {
    poolMin: parseInt(process.env['DB_POOL_MIN'] || '2', 10),
    poolMax: parseInt(process.env['DB_POOL_MAX'] || '20', 10),
    poolIdleTimeout: parseInt(process.env['DB_POOL_IDLE_TIMEOUT'] || '30000', 10),
  },

  // Monitoring
  monitoring: {
    metricsEnabled: process.env['METRICS_ENABLED'] === 'true',
    healthCheckEnabled: process.env['HEALTH_CHECK_ENABLED'] !== 'false',
  },
};

// Validate required configuration
const requiredEnvVars = ['FIREBASE_PROJECT_ID'];
const missingEnvVars = requiredEnvVars.filter(varName => !process.env[varName]);

if (missingEnvVars.length > 0) {
  throw new Error(`Missing required environment variables: ${missingEnvVars.join(', ')}`);
}
