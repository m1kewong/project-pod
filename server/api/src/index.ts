import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import 'express-async-errors';
import { Server } from 'http';

import { config } from './config';
import routes from './routes';
import { firebaseService } from './services/firebase.service';
import { cacheService } from './services/cache.service';
import { logger } from './utils/logger';
import { errorHandler, notFoundHandler } from './middleware/error.middleware';
import swaggerUi from 'swagger-ui-express';
import swaggerJsdoc from 'swagger-jsdoc';
import promMiddleware from 'express-prometheus-middleware';

export class App {
  public app: express.Application;
  private port: number;
  private server: Server | null = null;

  constructor() {
    this.app = express();
    this.port = config.port || 8080;
    
    this.initializeSwagger();
    this.initializeMiddlewares();
    this.initializeRoutes();
    this.initializeErrorHandling();
    this.initializeMetrics();
  }

  private initializeSwagger(): void {
    const swaggerOptions = {
      definition: {
        openapi: '3.0.0',
        info: {
          title: 'Gen Z Social Video Platform API',
          version: '1.0.0',
          description: 'High-performance REST API for Gen Z Social Video Platform',
        },
        servers: [
          {
            url: config.apiUrl || 'http://localhost:8080',
            description: 'Development server',
          },
        ],
        components: {
          securitySchemes: {
            BearerAuth: {
              type: 'http',
              scheme: 'bearer',
              bearerFormat: 'JWT',
            },
          },
        },
        security: [
          {
            BearerAuth: [],
          },
        ],
      },
      apis: ['./src/routes/*.ts', './src/controllers/*.ts'],
    };

    const swaggerSpec = swaggerJsdoc(swaggerOptions);
    this.app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));
  }

  private initializeMiddlewares(): void {
    // Security and optimization middlewares
    this.app.use(helmet({
      crossOriginEmbedderPolicy: false,
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          scriptSrc: ["'self'"],
          imgSrc: ["'self'", "data:", "https:"],
        },
      },
    }));

    this.app.use(cors({
      origin: config.corsOrigins,
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    }));

    this.app.use(compression());
    
    // Logging
    this.app.use(morgan('combined', {
      stream: {
        write: (message: string) => logger.info(message.trim()),
      },
    }));

    // Body parsing
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true, limit: '10mb' }));

    // Trust proxy for Cloud Run
    this.app.set('trust proxy', true);
  }
  private initializeRoutes(): void {
    // Simple health check that responds immediately (critical for Cloud Run startup)
    this.app.get('/health', (_req, res) => {
      // Return basic health information without waiting for services
      res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        version: process.env['npm_package_version'] || '1.0.0',
        environment: config.environment,
        uptime: process.uptime(),
      });
    });

    // Detailed health check with service status (for monitoring)
    this.app.get('/health/detailed', async (_req, res) => {
      try {
        // Get detailed status of services
        const cacheStatus = await cacheService.getStats().catch(err => ({ error: err.message }));
        
        res.json({
          status: 'ok',
          timestamp: new Date().toISOString(),
          version: process.env['npm_package_version'] || '1.0.0',
          environment: config.environment,
          uptime: process.uptime(),
          services: {
            cache: {
              ...cacheStatus,
              initialized: cacheService.isInitialized()
            },
            firebase: {
              initialized: firebaseService.isInitialized()
            }
          }
        });
      } catch (error) {
        res.status(500).json({
          status: 'error',
          timestamp: new Date().toISOString(),
          error: error instanceof Error ? error.message : String(error)
        });
      }
    });

    // API routes
    this.app.use('/api/v1', routes);
  }
  private initializeMetrics(): void {
    // Prometheus metrics
    this.app.use(promMiddleware({
      metricsPath: '/metrics',
      collectDefaultMetrics: true,
      requestDurationBuckets: [0.1, 0.5, 1, 1.5, 2, 3, 5, 10],
    }));

    // Custom metrics (commented out as they're not used)
    // const httpRequestsTotal = new promClient.Counter({
    //   name: 'http_requests_total',
    //   help: 'Total number of HTTP requests',
    //   labelNames: ['method', 'route', 'status'],
    // });

    // Default metrics are already collected by the middleware above
  }

  private initializeErrorHandling(): void {
    // 404 handler
    this.app.use(notFoundHandler);
    
    // Global error handler
    this.app.use(errorHandler);
  }  public async start(): Promise<void> {
    try {
      logger.info('Starting server initialization...');
      
      // Start server first to ensure port binding happens immediately
      // This is critical for Cloud Run's health check
      return new Promise((resolve) => {
        this.server = this.app.listen(this.port, '0.0.0.0', () => {
          logger.info(`🚀 Server running on port ${this.port}`);
          logger.info(`📚 API Documentation: http://0.0.0.0:${this.port}/api/docs`);
          logger.info(`📊 Metrics: http://0.0.0.0:${this.port}/metrics`);
          logger.info(`🏥 Health Check: http://0.0.0.0:${this.port}/health`);
          logger.info(`🌍 Environment: ${config.environment}`);
          
          // After server is listening, initialize services in background
          // This prevents service initialization from blocking container startup
          this.initializeServices().catch(error => {
            logger.warn('Service initialization had some failures, but server will continue running:', error);
          });
          
          resolve();
        });
      });
    } catch (error) {
      logger.error('Failed to start server:', error);
      process.exit(1);
    }
  }
  private async initializeServices(): Promise<void> {
    logger.info('Initializing services in background...');
    try {
      // Initialize services with shorter timeout and error handling for Cloud Run
      await Promise.allSettled([
        this.initializeServiceWithTimeout('Firebase', () => firebaseService.initialize(), 5000),
        this.initializeServiceWithTimeout('Cache', () => cacheService.initialize(), 3000)
      ]);
      
      logger.info('Service initialization completed');
    } catch (error) {
      logger.warn('Service initialization had some failures, but server will continue running:', error);
    }
  }

  private async initializeServiceWithTimeout(serviceName: string, initFn: () => Promise<void>, timeoutMs: number): Promise<void> {
    try {
      logger.info(`Initializing ${serviceName}...`);
      await Promise.race([
        initFn(),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error(`${serviceName} initialization timeout`)), timeoutMs)
        )
      ]);
      logger.info(`${serviceName} initialized successfully`);
    } catch (error) {
      logger.warn(`${serviceName} initialization failed, continuing without it:`, error);
    }
  }

  public getApp(): express.Application {
    return this.app;
  }

  public shutdown(): void {
    if (this.server) {
      this.server.close(() => {
        logger.info('Server closed');
      });
    }
  }
}

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  app.shutdown();
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  app.shutdown();
  process.exit(0);
});

// Start application unless running in a test environment
const app = new App();
if (process.env.NODE_ENV !== 'test') {
  app.start().catch((error) => {
    logger.error('Failed to start application:', error);
    process.exit(1);
  });
}

export default app;
