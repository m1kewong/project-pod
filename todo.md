## 1. **Project Bootstrapping and Repository Setup**

**TODO List:**

* [x] Create a new git repository (e.g., `genz-social-video-app`)
* [x] Set up subfolders for `/client`, `/server`, `/infra`
* [x] Initialize `README.md` with architecture summary and setup guide
* [x] Create `.gitignore` for Dart, Node.js, Python, and secrets
* [x] Create an initial workflow file for CI/CD (GitHub Actions or Cloud Build)

**Prompt:**

```
Create a new monorepo for "Gen Z Social Video Platform" with subfolders /client, /server, /infra.
Add README.md summarizing project and setup instructions.
Initialize .gitignore for Dart, Node.js, and secrets.
Add a basic CI/CD workflow (e.g., YAML for GitHub Actions or cloudbuild.yaml for GCP Cloud Build).
```

---

## 2. **Flutter Mobile App Scaffolding**

**TODO List:**

* [x] Scaffold a new Flutter project in `/client`
* [x] Add required dependencies: `firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in`, `firebase_storage`, `video_player`, `http`
* [x] Set up base navigation: Home, Video Feed, Video Player, Profile, Upload, Login
* [x] Configure Firebase project and connect to mobile app
* [x] Test: App builds and connects to Firebase in emulator/device

**Prompt:**

```
Scaffold a new Flutter app in /client.
Add dependencies: firebase_core, firebase_auth, cloud_firestore, google_sign_in, firebase_storage, video_player, http.
Set up Firebase for dev environment and connect Flutter app.
Implement initial navigation: Home, Feed, Player, Profile, Upload, Login.
Test: Run app in emulator, verify Firebase initialization succeeds.
```

---

## 3. **Firebase Authentication Integration**

**TODO List:**

* [x] Implement email, Google, and Apple login (via Firebase Auth)
* [x] Support anonymous browsing, but require login for actions (like/comment/upload)
* [x] Sync basic profile data (UID, email, display name, avatar) to Firestore on signup
* [x] Test: Register/login/logout flow, error handling

**Prompt:**

```
Integrate Firebase Auth into Flutter app.
Implement login with email/password, Google, and Apple.
Allow browsing videos without login; require login for interactions.
Sync user profile to Firestore on signup.
Test: Register, login, logout, and error cases.
```

---

## 4. **GCP Infrastructure Bootstrap**

**TODO List:**

* [x] Create GCP project, enable billing
* [x] Enable required APIs: Cloud Run, Firestore, Cloud SQL, Cloud Storage, Cloud Functions, Transcoder API, Cloud CDN, Firebase
* [x] Create service accounts and configure IAM roles (least privilege)
* [x] Create initial dev and prod environments (e.g., separate projects or prefixes)
* [x] Set up Cloud Storage buckets (uploads, public-videos, thumbnails)
* [x] Configure Artifact Registry for Docker images
* [x] Initialize Secret Manager with required secrets
* [x] Test: List all enabled APIs and permissions

**STATUS: ✅ COMPLETED** - All infrastructure components provisioned and tested successfully.

**Prompt:**

```
Create a GCP project for the app.
Enable APIs: Cloud Run, Firestore, Cloud SQL, Cloud Storage, Cloud Functions, Transcoder API, Cloud CDN, Firebase.
Set up service accounts with least privilege for each component.
Configure dev and prod environments.
Test: Output enabled APIs, verify permissions.
```

---

## 5. **Cloud Firestore Database Initialization**

**TODO List:**

* [x] Define and create collections: `users`, `videos`, `danmu_comments`, `notifications`
* [x] Define sample documents and rules (read/write: allow public reads, restrict writes)
* [x] Add Firestore security rules (require login for write, validate data shape)
* [x] Initialize Firestore database in production mode
* [x] Test: Add/read documents from Flutter app, verify security rules block unauthorized writes

**STATUS: ✅ COMPLETED** - Firestore database created and configured in asia-east1 region.

**Prompt:**

```
In Firestore, create collections: users, videos, danmu_comments, notifications.
Set security rules: public read, authenticated write with schema validation.
Seed with sample documents for each collection.
Test: Add/read from Flutter app, ensure unauthorized writes are blocked.
```

---

## 6. **Video Upload & Storage with GCS**

**TODO List:**

* [x] Integrate video file picker and upload logic in Flutter app (client → GCS via Firebase Storage)
* [x] Create `uploads` and `public` buckets in GCS
* [x] Set appropriate bucket permissions (private for uploads, public for transcoded videos)
* [x] Test: Upload a video, confirm it appears in the correct bucket

**Prompt:**

```
In Flutter, implement video picker and upload to Firebase Storage.
On GCP, create GCS buckets: uploads (private), public (for transcoded).
Set IAM and bucket permissions accordingly.
Test: Upload from app, verify file appears in GCS bucket.
```

---

## 7. **Transcoding Pipeline with GCP Transcoder API**

**TODO List:**

* [x] Deploy a Cloud Function triggered by new video upload
* [x] Use Transcoder API to generate HLS and MP4 variants, thumbnails
* [x] Move output files to the `public` bucket and update Firestore/video metadata
* [x] Test: Upload a video, verify transcoding, output to public bucket, and metadata update

**STATUS: ✅ COMPLETED** - Transcoding pipeline deployed with Cloud Functions and Transcoder API.

**Prompt:**

```
Set up a Cloud Function triggered on new uploads in GCS 'uploads' bucket.
Use GCP Transcoder API to convert to HLS and MP4, generate thumbnails.
Move outputs to 'public' bucket, update video doc in Firestore with output URLs.
Test: Upload video, check outputs and metadata.
```

---

## 8. **Backend API (Cloud Run, Node.js/Go)**

**TODO List:**

* [x] Scaffold RESTful API using Node.js/TypeScript or Go
* [x] Implement endpoints: user profile, video metadata CRUD, danmu/comment posting, likes/shares, search
* [x] Integrate Firebase Auth JWT validation middleware
* [ ] Containerize and deploy to Cloud Run (with GCP service account)
* [ ] Test: Hit endpoints with Postman, check auth, CRUD flows

**STATUS: 🚧 IN PROGRESS** - Core API implementation completed, containerization and deployment pending.

**COMPLETED:**
- ✅ Full RESTful API scaffolded using Node.js/TypeScript with Express
- ✅ Comprehensive endpoint implementation:
  - **Video endpoints**: CRUD operations, feed, search, like/unlike functionality
  - **User endpoints**: Profile management, follow/unfollow, user videos, followers/following
  - **Comment endpoints**: Create, read, update, delete, like comments, nested replies
  - **Danmu endpoints**: Real-time overlay comments with timestamps, hide/show functionality
- ✅ Firebase Auth JWT validation middleware integrated
- ✅ Production-ready features:
  - Rate limiting (basic, strict, upload-specific)
  - Request validation with comprehensive schemas
  - Error handling and logging
  - Prometheus metrics collection
  - Swagger API documentation
  - Redis caching with fallback to memory cache
  - CORS, Helmet security, compression
- ✅ TypeScript compilation successful with zero errors
- ✅ Environment configuration with mock Firebase support for local development
- ✅ API server running successfully on port 8080 with health checks

**PENDING:**
- Docker containerization (Dockerfile exists, needs testing)
- Cloud Run deployment
- End-to-end API testing with authentication flows

**Prompt:**

```
Scaffold RESTful API (Node.js/TS or Go) for user, video, comment, and danmu endpoints.
Implement Firebase Auth JWT validation.
Containerize app (Docker), deploy to Cloud Run with secure service account.
Test endpoints with Postman for auth and CRUD.
```

---

## 9. **Overlay Danmu (彈幕) System**

**TODO List:**

* [ ] Design danmu document structure (timestamp, user, content, style)
* [ ] Flutter: Implement danmu input UI and overlay rendering
* [ ] Firestore: Store danmu for each video as sub-collections or flat collection with video ID
* [ ] Enable real-time sync with Firestore listeners
* [ ] Test: Multiple clients can add/view danmu in real time; overlay aligns with playback

**Prompt:**

```
Design Firestore schema for danmu overlay comments (timestamp, user, content).
In Flutter, build overlay renderer and danmu input UI for videos.
Sync via Firestore real-time listeners; render in correct position/time.
Test with multiple devices: add danmu, see real-time updates in sync with video.
```

---

## 10. **Video Feed & Discovery**

**TODO List:**

* [ ] Implement home feed: query videos from Firestore, order by upload time or simple popularity metric
* [ ] Support infinite scroll or swipe up/down navigation
* [ ] Add search UI (search by title/tags) with basic backend search (Firestore text search for MVP)
* [ ] Test: Feed loads, navigation is smooth, search returns results

**Prompt:**

```
Implement home video feed in Flutter using Firestore query (order by date or popularity).
Enable infinite scroll or swipe navigation.
Add search UI to filter videos by title/tag.
Test: Feed loads, search works, navigation is smooth.
```

---

## 11. **Likes, Shares, and Basic Comments**

**TODO List:**

* [ ] Add like button UI and backend logic to increment/decrement likes
* [ ] Add share button to copy/share video link (with branch tracking for future)
* [ ] Implement persistent comments section (Firestore subcollection or field)
* [ ] Test: Like/unlike, share, comment flows all update in real time and persist

**Prompt:**

```
Implement like and share functionality in Flutter and backend.
Likes should update count in Firestore; shares generate unique shareable link.
Implement a basic persistent comment section for each video.
Test: Like, unlike, share, and comment from multiple users, verify updates.
```

---

## 12. **Push Notifications**

**TODO List:**

* [ ] Integrate Firebase Cloud Messaging (FCM) into Flutter app
* [ ] Backend: Trigger FCM on likes, replies, etc.
* [ ] Configure notification permissions on both platforms
* [ ] Test: Send like/reply notification, verify delivery on device

**Prompt:**

```
Integrate Firebase Cloud Messaging in Flutter.
Configure backend to trigger push notifications for likes, comments, etc.
Set notification permissions for iOS/Android.
Test: Trigger notification, confirm device receives it.
```

---

## 13. **Moderation Pipeline**

**TODO List:**

* [ ] Set up Cloud Function to scan uploaded videos with Cloud Video Intelligence API
* [ ] Use Perspective API for text moderation (danmu/comments)
* [ ] Flag or auto-block content that fails moderation; notify admin for review
* [ ] Test: Upload NSFW/test video and comments, ensure moderation blocks or flags appropriately

**Prompt:**

```
Deploy Cloud Function to scan videos on upload using Video Intelligence API for unsafe content.
Use Perspective API to screen danmu and comments for profanity/toxicity.
Flag or auto-block any violating content, notify admin.
Test: Upload inappropriate content/comments, verify moderation flow.
```

---

## 14. **Profile System**

**TODO List:**

* [ ] Implement profile page UI (username, avatar, uploaded videos, stats)
* [ ] Allow editing of profile (avatar, display name)
* [ ] Show followers/following (MVP: optional, else just uploaded videos)
* [ ] Test: View/edit own and others’ profiles, data syncs correctly

**Prompt:**

```
Implement user profile pages in Flutter.
Display username, avatar, uploaded videos, stats.
Allow user to edit profile (avatar/name).
Test: Edit/view profile, verify data updates and is consistent.
```

---

## 15. **Logging, Analytics, and Error Monitoring**

**TODO List:**

* [ ] Integrate Firebase Analytics for user events, screen flows
* [ ] Set up Crashlytics for error/crash reporting in Flutter
* [ ] Configure Stackdriver (Cloud Logging) for backend logs/alerts
* [ ] Test: Log in/out, video actions, crash/exception, verify logs and analytics dashboard

**Prompt:**

```
Integrate Firebase Analytics and Crashlytics into Flutter.
Set up Stackdriver logging/alerts for backend.
Log major user events (login, video play, comment).
Test: Trigger events and exceptions, check data appears in dashboards.
```

---

## 16. **CI/CD Automation**

**TODO List:**

* [ ] Configure Cloud Build pipeline for backend (build, test, deploy to Cloud Run)
* [ ] Configure app build/test automation (optionally Codemagic or custom GitHub Actions for Flutter)
* [ ] Set up Artifact Registry for container images
* [ ] Test: Push code, verify build, test, and deployment automation

**Prompt:**

```
Set up Cloud Build YAML pipeline for backend: build, test, deploy to Cloud Run.
Set up automated build/test for Flutter app.
Use Artifact Registry for Docker images.
Test: Commit/push code, verify build, test, and deployment steps complete successfully.
```

---

## 17. **Final GCP Provisioning and App Store Prep**

**TODO List:**

* [ ] Review all IAM/service account roles and permissions (principle of least privilege)
* [ ] Set up billing alerts, monitoring dashboards
* [ ] Prepare app store assets (screenshots, descriptions, privacy policy)
* [ ] Complete final testing in staging environment
* [ ] Deploy to production environment
* [ ] Submit apps to Apple App Store and Google Play

**Prompt:**

```
Review and audit all GCP IAM/service account permissions.
Set billing and usage alerts, monitoring dashboards.
Prepare and upload app store assets (screenshots, descriptions, privacy policy).
Complete final app testing in production.
Deploy app and backend to production.
Submit iOS and Android apps to stores.
```

---

### **Usage Instructions**

* Assign each prompt to your AI coding agent, one at a time.
* After each section, run the corresponding tests and verify outputs before moving to the next.
* Log all progress in the repository (README, CHANGELOG).
* Adjust or add details as needed based on actual progress and app requirements.