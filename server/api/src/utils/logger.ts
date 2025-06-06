import winston from 'winston';
import { config } from '../config';

// Custom format for structured logging
const logFormat = winston.format.combine(
  winston.format.timestamp(),
  winston.format.errors({ stack: true }),
  winston.format.json(),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    return JSON.stringify({
      timestamp,
      level,
      message,
      ...meta,
    });
  })
);

// Create logger instance
export const logger = winston.createLogger({  level: config.logging.level,
  format: logFormat,
  defaultMeta: {
    service: 'genz-video-api',
    version: process.env['npm_package_version'] || '1.0.0',
  },
  transports: [
    // Console transport for development
    new winston.transports.Console({
      format: config.nodeEnv === 'development'
        ? winston.format.combine(
            winston.format.colorize(),
            winston.format.simple()
          )
        : logFormat,
    }),
  ],
});

// Add file transports for production (but not in containerized environments)
if (config.nodeEnv === 'production' && !process.env['PORT']) {
  logger.add(new winston.transports.File({
    filename: 'logs/error.log',
    level: 'error',
    maxsize: 10485760, // 10MB
    maxFiles: 5,
  }));

  logger.add(new winston.transports.File({
    filename: 'logs/combined.log',
    maxsize: 10485760, // 10MB
    maxFiles: 5,
  }));
}

// Create a stream for Morgan HTTP logging
export const morganStream = {
  write: (message: string) => {
    logger.info(message.trim(), { type: 'http' });
  },
};

// Request logger middleware
export const requestLogger = (req: any, res: any, next: any) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration,
      userAgent: req.get('User-Agent'),
      ip: req.ip,
      userId: req.user?.uid,
    });
  });

  next();
};

export default logger;
