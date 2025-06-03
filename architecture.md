## Tech Stack & Architecture Overview

| Layer                   | Technology/Service                                                                  | Purpose/Description                                                            |
| ----------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| **Client (Mobile App)** | **Flutter (Dart)**                                                                  | Cross-platform (iOS + Android) app, supporting video, overlays, sharing        |
| **API Gateway**         | **Google Cloud Endpoints / API Gateway**                                            | Secure RESTful API entry point, traffic management, monitoring                 |
| **App Server**          | **Cloud Run (Containerized Node.js/TypeScript or Go)**                              | Stateless microservices for business logic (user, video, comments)             |
| **Authentication**      | **Firebase Authentication**                                                         | Secure login (email/phone/social), JWT issuance, user/session management       |
| **Database**            | **Cloud SQL (PostgreSQL)**                                                          | Structured data: users, video metadata, comments, likes, shares                |
| **Realtime Data**       | **Firestore (Native mode)** or **Firebase Realtime DB**                             | Overlay comments (danmu), notifications, real-time updates                     |
| **Video Storage**       | **Cloud Storage (GCS)**                                                             | Raw and transcoded video file storage; public/private bucket separation        |
| **Media Processing**    | **Transcoder API (formerly Video Intelligence API)**                                | Transcode uploaded videos (resizing, format conversion)                        |
| **Content Delivery**    | **Cloud CDN (integrated with GCS)**                                                 | Fast, global video delivery, low-latency in APAC                               |
| **Overlay Rendering**   | **Client-side + Firestore**                                                         | Overlay/danmu fetched and rendered in real-time by client                      |
| **Search**              | **Firestore full-text for MVP; upgrade to Elastic (Elasticsearch on GCP) post-MVP** | Video/title search, user/discovery                                             |
| **Analytics**           | **Google Analytics for Firebase**                                                   | Usage/event analytics, retention/funnel tracking, crash/error reporting        |
| **Moderation**          | **Cloud Functions + Cloud Vision/Video AI + Perspective API**                       | Auto-moderation on uploads/comments (profanity, violence, nudity, hate speech) |
| **Notifications**       | **Firebase Cloud Messaging (FCM)**                                                  | Push notifications for likes, replies, shares, moderation alerts               |
| **Monitoring**          | **Cloud Logging & Monitoring (Stackdriver)**                                        | System health, error monitoring, alerts, performance                           |
| **CI/CD**               | **Cloud Build + Artifact Registry**                                                 | Automated build, test, deploy pipeline for app and backend                     |

---

### 1. **Client Layer (Flutter Mobile App)**

* Written in **Dart** using Flutter SDK.
* Handles video playback, overlay rendering, user actions, local caching.
* Communicates with backend via secure RESTful APIs (and listens to Firestore for real-time danmu/notifications).
* Handles JWT storage (from Firebase Auth).

---

### 2. **API & Business Logic Layer**

| Component          | Details                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **API Gateway**    | Google Cloud Endpoints or API Gateway secures and routes API requests. Handles JWT validation (from Firebase Auth).                                                                                                                                                                                                                                                                                                     |
| **App Server**     | Containerized app (Node.js/TypeScript or Go recommended) running on Cloud Run (auto-scaled, stateless). Deployed as microservices (e.g., user-service, video-service, comment-service). Handles: <ul><li>Business logic (auth checks, permissions, rate limiting)</li><li>Video metadata management</li><li>Comment persistence (with danmu stored in Firestore)</li><li>RESTful API endpoints for mobile app</li></ul> |
| **Authentication** | Firebase Auth supports email, phone, Google, Apple (quick integration, robust, battle-tested for mobile apps). Returns JWT to client for secured API access.                                                                                                                                                                                                                                                            |

---

### 3. **Data Storage Layer**

| Component          | Details                                                                                                                                                                                              |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Relational DB**  | Cloud SQL (PostgreSQL): user profiles, video metadata (ID, owner, titles, tags, status, links to GCS), relationships (likes, follows, shares), comment metadata, analytics logs.                     |
| **Realtime/NoSQL** | Firestore (Native mode): overlay comments (danmu), chat messages, notification feed. Enables low-latency sync to client; supports scalable fan-out (all viewers see new comments in near real-time). |
| **Video Storage**  | Google Cloud Storage (GCS): raw video uploads stored in “uploads” bucket, transcoded outputs in “public” bucket. Supports signed URLs for temporary access control.                                  |

---

### 4. **Media Processing & Delivery**

| Component            | Details                                                                                                                                           |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Transcoding**      | Transcoder API: On video upload, a Cloud Function is triggered to transcode (multi-resolution HLS/MP4 for mobile delivery). Generates thumbnails. |
| **Content Delivery** | Cloud CDN: Distributes video content globally (APAC PoPs for minimal latency). Cloud CDN fronts GCS for high-speed delivery.                      |

---

### 5. **Overlay Rendering and Realtime Features**

* Overlay comments (danmu) written to Firestore.
* Clients subscribe to a video’s danmu collection and render comments in real time.
* (Optional in later phases: For extremely high throughput, use Pub/Sub or custom WebSocket server with Firestore as source of truth.)

---

### 6. **Moderation & Safety**

* Video uploads and overlays run through:

  * **Cloud Video Intelligence**/Cloud Vision API for image/video moderation (nudity, violence).
  * **Perspective API** (by Jigsaw/Google) for toxicity/hate/profanity in comments.
* Cloud Functions for auto-blocking/flagging content pre-publication.
* Admin panel for manual review (optional: AppSheet or a basic React app on App Engine).

---

### 7. **Notifications & Messaging**

* **Firebase Cloud Messaging (FCM)** sends push notifications for:

  * Likes, replies, video shares, moderation alerts, etc.
* App subscribes to notification topics per user.

---

### 8. **Monitoring, Analytics, CI/CD**

* **Google Analytics for Firebase**: event tracking, funnel analysis, user cohorts, crashlytics.
* **Cloud Logging/Monitoring (Stackdriver):** logs, error tracking, alerting for backend services.
* **Cloud Build + Artifact Registry**: Automates test, build, deploy for all codebases (mobile and backend).
* (Optional for future): **BigQuery** for advanced analytics/dashboarding.

---

## Diagram (Text Representation)

```
[Flutter App]
    |
    |-- (REST API calls, JWT) --> [API Gateway (Cloud Endpoints)]
                                     |
                        [Cloud Run Microservices (Node.js/Go)]
                        |          |             |         |
             [Cloud SQL]    [Firestore]   [GCS Video Storage]  [Cloud Functions]
                 |               |             |                     |
      [User, Video, Comments]  [Realtime danmu, notif]  [raw & transcoded files]   [Triggers: transcode, moderate, notify]
                                     |
                              [Firebase Cloud Messaging]
                                     |
                                [User Devices]

              [Cloud Video Intelligence] & [Perspective API] <-- Moderation pipeline
              [Cloud CDN] <--- [GCS public bucket]  <-- fast global video delivery

[Google Analytics/Firebase, Cloud Monitoring] ---< observability
[Cloud Build + Artifact Registry] ---< CI/CD
```

---

## Why this stack?

* **GCP-native:** All core infra (storage, API, DB, transcoding, CDN, auth, analytics) are fully managed, minimizing DevOps and ops overhead.
* **MVP friendly:** Serverless and auto-scaling (Cloud Run, Firestore) keeps costs low and enables rapid pivot as user growth or feature set evolves.
* **Realtime ready:** Firestore’s real-time sync works seamlessly with Flutter, ideal for danmu overlay and notifications.
* **Compliance/Security:** Firebase Auth, Cloud SQL, and GCS all have strong security controls, access policies, and are regionally deployable to meet APAC data regulations.
* **Scalable:** Every service (Firestore, Cloud Run, Cloud Storage, Cloud CDN) scales to millions of users/content.

---

## Cost & Maintainability

* **Pay-as-you-go** model keeps MVP burn rate manageable.
* Managed services = minimal maintenance (no manual DB scaling, patching, etc.)
* Easily extensible: future desktop/web, richer analytics (BigQuery), more advanced moderation (custom ML), etc.

---

## Next Steps

* Set up GCP project with security policies.
* Scaffold Flutter app and connect to Firebase Auth, Firestore, GCS.
* Deploy first Cloud Run service for API/business logic.
* Set up Cloud SQL and initial schema.
* Build upload-processing pipeline (Cloud Functions + Transcoder API).
* Set up monitoring, logging, analytics from Day 1.

---

**References:**

* [Google Cloud: Scalable Mobile App Architecture](https://cloud.google.com/solutions/architecture/scalable-and-secure-mobile-backend)
* [Firebase: Real-time Collaboration with Firestore](https://firebase.google.com/docs/firestore)
* [Google Transcoder API](https://cloud.google.com/transcoder/docs/overview)
* [Cloud CDN](https://cloud.google.com/cdn/docs/overview)
* [Content Moderation (Perspective API)](https://www.perspectiveapi.com/)
* [Example: GCP Architecture for Social Video Apps](https://cloud.google.com/architecture/modern-apps)
