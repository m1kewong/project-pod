import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import 'express-async-errors';

import { config } from './config';
import routes from './routes';
import { firebaseService } from './services/firebase.service';
import { cacheService } from './services/cache.service';
import { logger } from './utils/logger';
import { errorHandler, notFoundHandler } from './middleware/error.middleware';
import swaggerUi from 'swagger-ui-express';
import swaggerJsdoc from 'swagger-jsdoc';
import promMiddleware from 'express-prometheus-middleware';

class App {
  public app: express.Application;
  private port: number;

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
    // Health check (before API routes)
    this.app.get('/health', (_req, res) => {
      res.json({
        success: true,
        message: 'API is healthy',
        timestamp: new Date().toISOString(),
        version: process.env['npm_package_version'] || '1.0.0',
        environment: config.environment,
      });
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
  }

  public async start(): Promise<void> {
    try {
      // Initialize services
      await firebaseService.initialize();
      await cacheService.initialize();

      // Start server
      this.app.listen(this.port, () => {
        logger.info(`🚀 Server running on port ${this.port}`);
        logger.info(`📚 API Documentation: http://localhost:${this.port}/api/docs`);
        logger.info(`📊 Metrics: http://localhost:${this.port}/metrics`);
        logger.info(`🏥 Health Check: http://localhost:${this.port}/health`);
        logger.info(`🌍 Environment: ${config.environment}`);
      });
    } catch (error) {
      logger.error('Failed to start server:', error);
      process.exit(1);
    }
  }

  public getApp(): express.Application {
    return this.app;
  }
}

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});

// Start application
const app = new App();
app.start().catch((error) => {
  logger.error('Failed to start application:', error);
  process.exit(1);
});

export default app;
