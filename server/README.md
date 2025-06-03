# Server - Backend Services

This directory contains the backend services for the Gen Z Social Video Platform, built with Node.js/TypeScript and deployed on Google Cloud Run.

## Features

- RESTful API endpoints for the mobile app
- Authentication with Firebase Auth
- Business logic for user management, video processing, and comments
- Integration with Cloud SQL (PostgreSQL) and Firestore
- Video upload processing and transcoding

## Setup

1. Install Node.js and npm
2. Install dependencies:
```bash
npm install
```

3. Set up environment variables (create a `.env` file):
```
GCP_PROJECT_ID=your-project-id
DB_CONNECTION_STRING=your-db-connection
FIREBASE_CONFIG=path-to-firebase-config
```

4. Start the development server:
```bash
npm run dev
```

## Project Structure

- `src/` - TypeScript source code
  - `controllers/` - API endpoint controllers
  - `models/` - Data models and database schemas
  - `services/` - Business logic and external service integrations
  - `routes/` - API route definitions
  - `middleware/` - Express middleware
  - `utils/` - Utility functions
- `tests/` - Unit and integration tests
- `config/` - Configuration files

## API Endpoints

- `/api/auth` - Authentication endpoints
- `/api/users` - User management endpoints
- `/api/videos` - Video upload and management endpoints
- `/api/comments` - Comment and danmu endpoints

## Development Guidelines

- Follow RESTful API design principles
- Implement proper error handling and validation
- Write unit and integration tests
- Document API endpoints using Swagger/OpenAPI
