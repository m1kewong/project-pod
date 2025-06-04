# Firebase Configuration Guide
**Project Pod Development Environment**

## 🎯 **Firebase Console Setup**

### 1. Access Firebase Console
Navigate to: https://console.firebase.google.com/project/project-pod-dev

### 2. Authentication Setup
1. Go to **Authentication** → **Sign-in method**
2. Enable the following providers:
   - **Email/Password**: Enable
   - **Google**: Enable (configure OAuth consent screen)
   - **Apple**: Enable (requires Apple Developer account)
   - **Anonymous**: Enable (for browsing without login)

### 3. Firestore Security Rules
Navigate to **Firestore Database** → **Rules** and replace with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection - users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow create: if request.auth != null && request.auth.uid == userId
        && validateUserData(resource.data);
    }
    
    // Videos collection - public read, authenticated write
    match /videos/{videoId} {
      allow read: if true; // Public read
      allow write: if request.auth != null && validateVideoData(resource.data);
    }
    
    // Comments collection - public read, authenticated write
    match /danmu_comments/{commentId} {
      allow read: if true; // Public read
      allow write: if request.auth != null && validateCommentData(resource.data);
    }
    
    // Notifications collection - users can only access their own
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
    
    // Validation functions
    function validateUserData(data) {
      return data.keys().hasAll(['email', 'displayName', 'createdAt']) &&
        data.email is string &&
        data.displayName is string &&
        data.createdAt is timestamp;
    }
    
    function validateVideoData(data) {
      return data.keys().hasAll(['title', 'description', 'userId', 'createdAt']) &&
        data.title is string &&
        data.description is string &&
        data.userId is string &&
        data.createdAt is timestamp;
    }
    
    function validateCommentData(data) {
      return data.keys().hasAll(['text', 'userId', 'videoId', 'timestamp']) &&
        data.text is string &&
        data.userId is string &&
        data.videoId is string &&
        data.timestamp is timestamp;
    }
  }
}
```

### 4. Storage Rules
Navigate to **Storage** → **Rules** and configure:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to upload to uploads folder
    match /uploads/{allPaths=**} {
      allow write: if request.auth != null;
      allow read: if request.auth != null;
    }
    
    // Public read access to processed videos
    match /public-videos/{allPaths=**} {
      allow read: if true;
      allow write: if false; // Only backend can write here
    }
    
    // Public read access to thumbnails
    match /thumbnails/{allPaths=**} {
      allow read: if true;
      allow write: if false; // Only backend can write here
    }
  }
}
```

### 5. Generate Configuration Files

#### For Flutter App:
1. Go to **Project Settings** → **General**
2. Click **Add app** → **Flutter**
3. Follow the setup wizard to download:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
   - `lib/firebase_options.dart`

#### For Backend Services:
1. Go to **Project Settings** → **Service accounts**
2. Click **Generate new private key**
3. Save as `firebase-admin-key.json`
4. Update Secret Manager with the key content

### 6. Update Secret Manager
Run these commands to update secrets with actual values:

```powershell
# Generate a secure JWT secret
$jwtSecret = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((New-Guid).ToString() + (New-Guid).ToString()))
echo $jwtSecret | gcloud secrets versions add jwt-secret --data-file=- --project=project-pod-dev

# Update database URL
echo "projects/project-pod-dev/databases/(default)" | gcloud secrets versions add database-url --data-file=- --project=project-pod-dev

# Update firebase admin key (after downloading from console)
gcloud secrets versions add firebase-admin-key --data-file="path/to/firebase-admin-key.json" --project=project-pod-dev
```

### 7. Test Firebase Integration

#### Flutter App Test:
```dart
// In your Flutter app's main.dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}
```

#### Backend Test:
```javascript
// Test Firebase Admin SDK connection
const admin = require('firebase-admin');
const serviceAccount = require('./firebase-admin-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://project-pod-dev-default-rtdb.firebaseio.com'
});

// Test Firestore connection
const db = admin.firestore();
console.log('Firebase initialized successfully');
```

## 🔐 **Security Checklist**

- [ ] Authentication providers configured
- [ ] Firestore security rules deployed
- [ ] Storage rules configured
- [ ] Service account keys securely stored
- [ ] OAuth consent screen configured
- [ ] API keys restricted appropriately

## 📱 **Next Development Steps**

After Firebase configuration is complete:

1. **Video Upload Implementation** (Section 6)
   - Integrate video picker in Flutter
   - Implement upload to GCS via Firebase Storage
   - Test upload flow

2. **Transcoding Pipeline** (Section 7)
   - Deploy Cloud Function for video processing
   - Configure Transcoder API
   - Set up HLS/MP4 output

3. **Backend API** (Section 8)
   - Scaffold Node.js API
   - Deploy to Cloud Run
   - Implement core endpoints

**Firebase Console:** https://console.firebase.google.com/project/project-pod-dev  
**GCP Console:** https://console.cloud.google.com/home/dashboard?project=project-pod-dev
