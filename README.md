# Gen Z Social Video Platform

A cutting-edge social video platform designed specifically for Gen Z users in the APAC region. This platform enables users to create, share, and engage with short-form video content featuring interactive overlay comments (danmu).

## Project Structure

- `/client` - Flutter mobile application (iOS/Android)
- `/server` - Backend services (Node.js/TypeScript on Cloud Run)
- `/infra` - Infrastructure as Code and deployment configurations

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Client** | Flutter (Dart) |
| **API Gateway** | Google Cloud Endpoints / API Gateway |
| **App Server** | Cloud Run (Node.js/TypeScript) |
| **Authentication** | Firebase Authentication |
| **Database** | Cloud SQL (PostgreSQL) & Firestore |
| **Video Storage** | Google Cloud Storage (GCS) |
| **Media Processing** | Transcoder API |
| **Content Delivery** | Cloud CDN |
| **Notifications** | Firebase Cloud Messaging |

## Setup Instructions

### Prerequisites
- Flutter SDK
- Node.js & npm
- Google Cloud SDK
- Firebase CLI
- Git

### Development Setup

1. **Clone the repository**
   ```
   git clone <repository-url>
   cd project-pod
   ```

2. **Backend Setup**
   ```
   cd server
   npm install
   npm run dev
   ```

3. **Flutter App Setup**
   ```
   cd client
   flutter pub get
   flutter run
   ```

4. **Infrastructure Setup**
   ```
   cd infra
   # Follow instructions in infra/README.md
   ```

### Environment Configuration

Create a `.env` file in the server directory with the following variables:
```
GCP_PROJECT_ID=your-project-id
DB_CONNECTION_STRING=your-db-connection
FIREBASE_CONFIG=path-to-firebase-config
```

For Flutter, update the Firebase configuration files as per the Firebase console instructions.

## Contributing

Please read our contributing guidelines before submitting pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
