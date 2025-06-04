export class ApiError extends Error {
  public readonly statusCode: number;
  public readonly code: string;
  public readonly details?: any;

  constructor(statusCode: number, message: string, code?: string, details?: any) {
    super(message);
    this.statusCode = statusCode;
    this.code = code || 'GENERIC_ERROR';
    this.details = details;
    this.name = 'ApiError';

    // Maintain proper stack trace
    Error.captureStackTrace(this, this.constructor);
  }
}

export class ValidationError extends ApiError {
  constructor(message: string, details?: any) {
    super(400, message, 'VALIDATION_ERROR', details);
    this.name = 'ValidationError';
  }
}

export class NotFoundError extends ApiError {
  constructor(resource: string = 'Resource') {
    super(404, `${resource} not found`, 'NOT_FOUND');
    this.name = 'NotFoundError';
  }
}

export class UnauthorizedError extends ApiError {
  constructor(message: string = 'Unauthorized access') {
    super(401, message, 'UNAUTHORIZED');
    this.name = 'UnauthorizedError';
  }
}

export class ForbiddenError extends ApiError {
  constructor(message: string = 'Forbidden access') {
    super(403, message, 'FORBIDDEN');
    this.name = 'ForbiddenError';
  }
}

export class ConflictError extends ApiError {
  constructor(message: string = 'Resource conflict') {
    super(409, message, 'CONFLICT');
    this.name = 'ConflictError';
  }
}

export class TooManyRequestsError extends ApiError {
  constructor(retryAfter?: number) {
    super(429, 'Too many requests', 'TOO_MANY_REQUESTS', { retryAfter });
    this.name = 'TooManyRequestsError';
  }
}

export class InternalServerError extends ApiError {
  constructor(message: string = 'Internal server error') {
    super(500, message, 'INTERNAL_SERVER_ERROR');
    this.name = 'InternalServerError';
  }
}

export class ServiceUnavailableError extends ApiError {
  constructor(message: string = 'Service temporarily unavailable') {
    super(503, message, 'SERVICE_UNAVAILABLE');
    this.name = 'ServiceUnavailableError';
  }
}
