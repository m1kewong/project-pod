# Firestore Database Setup

This directory contains the complete Firestore database configuration for the Gen Z Social Video Platform, including security rules, schema definitions, seed data, and deployment tools.

## 📁 Directory Structure

```
database/
├── firestore.rules          # Security rules for Firestore
├── firestore.indexes.json   # Index configurations for query optimization
├── schema.md               # Complete database schema documentation
├── package.json            # Node.js dependencies for database tools
├── deploy-firestore.sh     # Bash deployment script (Linux/macOS)
├── deploy-firestore.ps1    # PowerShell deployment script (Windows)
├── seed-data/              # Sample data for testing
│   ├── users.json
│   ├── videos.json
│   ├── danmu_comments.json
│   ├── notifications.json
│   ├── follows.json
│   └── activities.json
├── scripts/                # Database utility scripts
│   ├── upload-seed-data.js
│   └── test-security-rules.js
└── README.md              # This file
```

## 🚀 Quick Start

### Prerequisites

1. **GCP Project**: Ensure you have a GCP project with billing enabled
2. **gcloud CLI**: Install and authenticate with `gcloud auth login`
3. **Node.js**: Version 18+ required for database scripts
4. **Firebase Admin SDK**: Installed via npm (handled by package.json)

### 1. Install Dependencies

```bash
cd database
npm install
```

### 2. Deploy Firestore Database

#### Option A: Using Bash (Linux/macOS)
```bash
# Make script executable
chmod +x deploy-firestore.sh

# Deploy with default settings
./deploy-firestore.sh

# Or with custom project ID
PROJECT_ID=your-project-id ./deploy-firestore.sh
```

#### Option B: Using PowerShell (Windows)
```powershell
# Deploy with default settings
.\deploy-firestore.ps1

# Deploy with custom project ID
.\deploy-firestore.ps1 -ProjectId "your-project-id"

# Test-only mode (no changes)
.\deploy-firestore.ps1 -TestOnly

# Skip seed data upload
.\deploy-firestore.ps1 -SkipSeedData
```

### 3. Verify Deployment

The deployment script automatically runs tests, but you can also run them manually:

```bash
# Test security rules
npm run test-rules your-project-id

# Upload specific seed data
npm run upload-seed users seed-data/users.json your-project-id
```

## 📊 Database Schema

The database consists of 8 main collections:

### Core Collections
- **users**: User profiles and preferences
- **videos**: Video metadata and URLs
- **danmu_comments**: Real-time overlay comments
- **notifications**: User notifications

### Relationship Collections
- **follows**: User follow relationships
- **activities**: User activity feed

### System Collections
- **analytics**: Usage analytics (server-only)
- **admin**: Administrative data (server-only)

### Subcollections
- **videos/{videoId}/likes**: Video likes
- **videos/{videoId}/comments**: Traditional comments
- **users/{userId}/private**: Private user data

For detailed schema information, see [schema.md](./schema.md).

## 🔒 Security Model

### Access Control
- **Public Read**: Videos, users, and danmu comments can be read by anyone
- **Authenticated Write**: Only logged-in users can create/update content
- **Owner-Only**: Users can only modify their own content
- **Server-Only**: Analytics and admin collections require server authentication

### Data Validation
- All write operations validate data structure and types
- Required fields are enforced
- String length limits are applied
- Enum values are validated

### Key Security Features
- Authentication required for all write operations
- User ownership validation for personal data
- Rate limiting through Firestore quotas
- Data sanitization and validation functions

## 📈 Performance Optimization

### Indexes
The deployment automatically creates composite indexes for:
- Video feed queries (status + createdAt)
- User video queries (userId + status + createdAt)
- Hashtag searches (hashtags array + status + createdAt)
- Comment positioning (videoId + position)
- Notification queries (userId + read/type + createdAt)
- Follow relationship queries
- Activity feed queries

### Best Practices
- Pagination using cursor-based queries
- Denormalized data for faster reads
- Batch operations for multiple writes
- Efficient subcollection structure for likes/comments

## 🧪 Testing

### Automated Tests
The deployment script includes comprehensive tests:

1. **Connection Test**: Verify Firestore connectivity
2. **Security Rules Test**: Validate access controls
3. **Data Validation Test**: Check schema enforcement
4. **Index Test**: Verify query performance

### Manual Testing
You can also test using the Firebase Console:
- Navigate to https://console.firebase.google.com/project/YOUR_PROJECT_ID/firestore
- Verify collections and documents are created
- Test queries in the Firestore console
- Check security rules in the Rules tab

## 🔧 Configuration

### Environment Variables
- `PROJECT_ID`: GCP project ID (default: project-pod-dev)
- `FIRESTORE_REGION`: Firestore region (default: asia-southeast1)
- `GOOGLE_APPLICATION_CREDENTIALS`: Service account key path

### Firestore Settings
- **Database Type**: Native Firestore (not Datastore mode)
- **Location**: Asia-Southeast1 (Singapore) for APAC optimization
- **Security Rules**: Custom rules with authentication requirements
- **Indexes**: Composite indexes for common query patterns

## 🚨 Troubleshooting

### Common Issues

#### 1. Permission Denied
```
Error: Permission denied
```
**Solution**: Ensure you're authenticated with `gcloud auth login` and have Firestore Admin permissions.

#### 2. Database Already Exists
```
Error: Database already exists
```
**Solution**: This is normal if Firestore was previously initialized. The script will continue with rule deployment.

#### 3. Index Creation Failed
```
Error: Index already exists
```
**Solution**: Indexes may already exist. This warning can be safely ignored.

#### 4. Node.js Not Found
```
Error: node command not found
```
**Solution**: Install Node.js 18+ from https://nodejs.org/

#### 5. Service Account Issues
```
Error: Could not load the default credentials
```
**Solution**: 
- Run `gcloud auth application-default login`
- Or set `GOOGLE_APPLICATION_CREDENTIALS` to your service account key

### Debug Mode
Enable debug logging by setting environment variables:
```bash
export DEBUG=1
export VERBOSE=1
./deploy-firestore.sh
```

## 📚 Additional Resources

- [Firestore Documentation](https://firebase.google.com/docs/firestore)
- [Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)
- [Data Modeling Best Practices](https://firebase.google.com/docs/firestore/data-model)
- [Query Optimization](https://firebase.google.com/docs/firestore/query-data/queries)

## 🤝 Contributing

When making changes to the database:

1. Update schema documentation in `schema.md`
2. Modify security rules in `firestore.rules`
3. Add appropriate indexes to `firestore.indexes.json`
4. Update seed data if schema changes
5. Test changes with the deployment script
6. Document breaking changes in this README

## 📝 License

This database configuration is part of the Gen Z Social Video Platform project.
