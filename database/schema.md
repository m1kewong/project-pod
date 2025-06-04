# Firestore Database Schema
# Gen Z Social Video Platform
# Version: 1.0

## Collections Overview

This document defines the Firestore database schema for the Gen Z Social Video Platform. The database is designed to support a TikTok-like social video sharing experience with real-time features.

## Collection Structure

```
/users/{userId}
/videos/{videoId}
  /likes/{likeId}
  /comments/{commentId}
/danmu_comments/{commentId}
/notifications/{notificationId}
/follows/{followId}
/activities/{activityId}
/analytics/{document}
/admin/{document}
```

## Collection Definitions

### 1. Users Collection (`/users/{userId}`)

**Purpose:** Store user profile information and account data.

**Document ID:** Firebase Auth UID

**Schema:**
```typescript
interface User {
  // Required fields
  uid: string;                    // Firebase Auth UID (matches document ID)
  email: string;                  // User's email address
  displayName: string;            // User's display name (1-50 chars)
  createdAt: Timestamp;           // Account creation timestamp
  updatedAt: Timestamp;           // Last profile update timestamp

  // Optional profile fields
  bio?: string;                   // User bio (0-500 chars)
  website?: string;               // User's website URL
  location?: string;              // User's location (0-100 chars)
  avatarUrl?: string;             // Profile picture URL
  
  // Social metrics
  followerCount?: number;         // Number of followers (default: 0)
  followingCount?: number;        // Number of following (default: 0)
  videoCount?: number;            // Number of uploaded videos (default: 0)
  
  // Account status
  isVerified?: boolean;           // Verified account status (default: false)
  accountType?: 'personal' | 'creator' | 'business'; // Account type (default: 'personal')
  
  // Settings
  settings?: {
    privacy: 'public' | 'private'; // Profile privacy (default: 'public')
    allowComments: boolean;       // Allow comments on videos (default: true)
    allowDanmu: boolean;          // Allow danmu comments (default: true)
    notifications: {
      likes: boolean;             // Notify on video likes (default: true)
      comments: boolean;          // Notify on video comments (default: true)
      follows: boolean;           // Notify on new followers (default: true)
    };
  };
  
  // Platform metadata
  deviceToken?: string;           // FCM device token for push notifications
  lastLoginAt?: Timestamp;       // Last login timestamp
  isActive?: boolean;             // Account active status (default: true)
}
```

**Indexes:**
- `displayName` (ascending)
- `createdAt` (descending)
- `followerCount` (descending)
- `isVerified, followerCount` (compound)

---

### 2. Videos Collection (`/videos/{videoId}`)

**Purpose:** Store video metadata and content information.

**Document ID:** Auto-generated

**Schema:**
```typescript
interface Video {
  // Required fields
  userId: string;                 // Video owner's UID
  title: string;                  // Video title (1-200 chars)
  description: string;            // Video description (0-2000 chars)
  videoUrl: string;               // Video file URL (Cloud Storage)
  thumbnailUrl: string;           // Thumbnail image URL
  duration: number;               // Video duration in seconds
  createdAt: Timestamp;           // Upload timestamp
  updatedAt: Timestamp;           // Last update timestamp

  // Content metadata
  tags?: string[];                // Video tags (max 20)
  visibility: 'public' | 'unlisted' | 'private'; // Visibility setting (default: 'public')
  
  // Processing status
  status: 'processing' | 'ready' | 'failed'; // Processing status (default: 'processing')
  
  // Engagement metrics
  likeCount: number;              // Number of likes (default: 0)
  commentCount: number;           // Number of comments (default: 0)
  shareCount: number;             // Number of shares (default: 0)
  viewCount: number;              // Number of views (default: 0)
  
  // Video specifications
  resolution?: {
    width: number;
    height: number;
  };
  fileSize?: number;              // File size in bytes
  format?: string;                // Video format (mp4, etc.)
  
  // Platform metadata
  location?: {
    latitude: number;
    longitude: number;
    address?: string;
  };
  music?: {
    title: string;
    artist: string;
    url?: string;
  };
  effects?: string[];             // Applied video effects
  isOriginal?: boolean;           // Original content flag (default: true)
}
```

**Indexes:**
- `userId, createdAt` (compound, descending)
- `createdAt` (descending)
- `likeCount` (descending)
- `viewCount` (descending)
- `tags` (array-contains)
- `visibility, createdAt` (compound)

---

### 3. Video Likes Subcollection (`/videos/{videoId}/likes/{likeId}`)

**Purpose:** Track likes on videos.

**Document ID:** User's UID (ensures one like per user)

**Schema:**
```typescript
interface VideoLike {
  userId: string;                 // User who liked the video
  createdAt: Timestamp;           // When the like was created
}
```

**Indexes:**
- `createdAt` (descending)

---

### 4. Video Comments Subcollection (`/videos/{videoId}/comments/{commentId}`)

**Purpose:** Store comments on videos.

**Document ID:** Auto-generated

**Schema:**
```typescript
interface VideoComment {
  // Required fields
  userId: string;                 // Comment author's UID
  text: string;                   // Comment text (1-1000 chars)
  createdAt: Timestamp;           // Comment creation timestamp
  updatedAt: Timestamp;           // Last update timestamp

  // Optional fields
  likeCount?: number;             // Number of likes on comment (default: 0)
  replyCount?: number;            // Number of replies (default: 0)
  parentCommentId?: string;       // Parent comment ID for replies
  
  // Moderation
  isEdited?: boolean;             // Whether comment was edited (default: false)
  isPinned?: boolean;             // Whether comment is pinned (default: false)
}
```

**Indexes:**
- `createdAt` (descending)
- `parentCommentId, createdAt` (compound)
- `userId, createdAt` (compound)

---

### 5. Danmu Comments Collection (`/danmu_comments/{commentId}`)

**Purpose:** Store real-time overlay comments (danmu/bullet comments).

**Document ID:** Auto-generated

**Schema:**
```typescript
interface DanmuComment {
  // Required fields
  userId: string;                 // Comment author's UID
  videoId: string;                // Video this danmu belongs to
  text: string;                   // Danmu text (1-200 chars)
  timestamp: number;              // Video timestamp in seconds
  position: 'top' | 'bottom' | 'scroll'; // Display position
  color: string;                  // Text color (hex format)
  createdAt: Timestamp;           // Creation timestamp

  // Optional styling
  fontSize?: number;              // Font size (default: 14)
  speed?: number;                 // Scroll speed for 'scroll' type (default: 1)
  opacity?: number;               // Text opacity 0-1 (default: 1)
}
```

**Indexes:**
- `videoId, timestamp` (compound, ascending)
- `userId, createdAt` (compound, descending)
- `createdAt` (descending)

---

### 6. Notifications Collection (`/notifications/{notificationId}`)

**Purpose:** Store user notifications for engagement and activities.

**Document ID:** Auto-generated

**Schema:**
```typescript
interface Notification {
  // Required fields
  userId: string;                 // Notification recipient's UID
  type: 'like' | 'comment' | 'follow' | 'mention' | 'system'; // Notification type
  title: string;                  // Notification title
  body: string;                   // Notification body text
  createdAt: Timestamp;           // Creation timestamp

  // Status
  read: boolean;                  // Read status (default: false)
  updatedAt?: Timestamp;          // Last update timestamp

  // Related data
  relatedUserId?: string;         // User who triggered the notification
  relatedVideoId?: string;        // Related video ID
  relatedCommentId?: string;      // Related comment ID
  
  // Action data
  actionUrl?: string;             // Deep link URL for action
  imageUrl?: string;              // Notification image
  
  // Platform metadata
  sent: boolean;                  // Push notification sent status (default: false)
  sentAt?: Timestamp;             // Push notification sent timestamp
}
```

**Indexes:**
- `userId, createdAt` (compound, descending)
- `userId, read, createdAt` (compound)
- `type, createdAt` (compound)

---

### 7. Follows Collection (`/follows/{followId}`)

**Purpose:** Track user follow relationships.

**Document ID:** `{followerId}_{followingId}` (composite key)

**Schema:**
```typescript
interface Follow {
  followerId: string;             // User who is following
  followingId: string;            // User being followed
  createdAt: Timestamp;           // Follow creation timestamp
}
```

**Indexes:**
- `followerId, createdAt` (compound, descending)
- `followingId, createdAt` (compound, descending)

---

### 8. Activities Collection (`/activities/{activityId}`)

**Purpose:** Store user activities for feed generation (server-managed).

**Document ID:** Auto-generated

**Schema:**
```typescript
interface Activity {
  userId: string;                 // User who performed the activity
  type: 'video_upload' | 'video_like' | 'user_follow' | 'comment_post'; // Activity type
  createdAt: Timestamp;           // Activity timestamp
  
  // Related data
  videoId?: string;               // Related video ID
  targetUserId?: string;          // Target user ID (for follows)
  commentId?: string;             // Related comment ID
  
  // Feed visibility
  visibility: 'public' | 'followers' | 'private'; // Who can see this activity
  
  // Metadata
  metadata?: {
    [key: string]: any;           // Additional activity-specific data
  };
}
```

**Indexes:**
- `userId, createdAt` (compound, descending)
- `type, createdAt` (compound, descending)
- `visibility, createdAt` (compound, descending)

---

## Sample Documents

### Sample User Document
```json
{
  "uid": "user123",
  "email": "alice@example.com",
  "displayName": "Alice Chen",
  "bio": "Gen Z content creator from Taiwan 🇹🇼 Love dancing and music!",
  "avatarUrl": "https://storage.googleapis.com/bucket/avatars/user123.jpg",
  "followerCount": 1250,
  "followingCount": 89,
  "videoCount": 23,
  "isVerified": false,
  "accountType": "creator",
  "createdAt": "2025-06-01T00:00:00Z",
  "updatedAt": "2025-06-03T15:30:00Z",
  "settings": {
    "privacy": "public",
    "allowComments": true,
    "allowDanmu": true,
    "notifications": {
      "likes": true,
      "comments": true,
      "follows": true
    }
  },
  "lastLoginAt": "2025-06-03T15:30:00Z",
  "isActive": true
}
```

### Sample Video Document
```json
{
  "userId": "user123",
  "title": "Summer Dance Challenge 💃",
  "description": "Check out my take on the latest dance trend! #SummerVibes #DanceChallenge",
  "videoUrl": "https://storage.googleapis.com/bucket/videos/video456.mp4",
  "thumbnailUrl": "https://storage.googleapis.com/bucket/thumbnails/video456.jpg",
  "duration": 15.5,
  "tags": ["dance", "summer", "challenge", "trending"],
  "visibility": "public",
  "status": "ready",
  "likeCount": 342,
  "commentCount": 28,
  "shareCount": 15,
  "viewCount": 2890,
  "resolution": {
    "width": 1080,
    "height": 1920
  },
  "fileSize": 8450000,
  "format": "mp4",
  "music": {
    "title": "Summer Beats",
    "artist": "DJ Cool"
  },
  "isOriginal": true,
  "createdAt": "2025-06-03T10:00:00Z",
  "updatedAt": "2025-06-03T10:00:00Z"
}
```

### Sample Danmu Comment Document
```json
{
  "userId": "user789",
  "videoId": "video456",
  "text": "Amazing moves! 🔥",
  "timestamp": 8.5,
  "position": "scroll",
  "color": "#FF6B6B",
  "fontSize": 16,
  "speed": 1.2,
  "opacity": 0.9,
  "createdAt": "2025-06-03T12:15:00Z"
}
```

### Sample Notification Document
```json
{
  "userId": "user123",
  "type": "like",
  "title": "New Like!",
  "body": "Bob liked your video 'Summer Dance Challenge'",
  "read": false,
  "relatedUserId": "user456",
  "relatedVideoId": "video456",
  "actionUrl": "app://video/video456",
  "imageUrl": "https://storage.googleapis.com/bucket/thumbnails/video456.jpg",
  "sent": true,
  "sentAt": "2025-06-03T14:00:00Z",
  "createdAt": "2025-06-03T14:00:00Z"
}
```

## Security Rules Summary

1. **Public Read Access:** Users, videos, comments, danmu comments, follows, and activities can be read by anyone
2. **Authenticated Write:** Only authenticated users can create/update content
3. **Owner-Only Operations:** Users can only modify their own content
4. **Data Validation:** All writes are validated for correct data types and constraints
5. **Server-Only Collections:** Notifications, analytics, and admin collections are managed server-side only

## Performance Considerations

1. **Denormalized Data:** User display names and avatars may be duplicated for performance
2. **Counters:** Like counts, follower counts are maintained as fields (updated via Cloud Functions)
3. **Pagination:** All lists should be paginated using Firestore's limit() and startAfter()
4. **Caching:** Frequently accessed data should be cached client-side
5. **Batch Operations:** Use batch writes for related updates (like incrementing counters)

## Migration Strategy

1. **Initial Setup:** Deploy security rules and create indexes
2. **Seed Data:** Create sample users and videos for testing
3. **Progressive Rollout:** Start with core collections, add features incrementally
4. **Data Migration:** Plan for schema updates using versioned documents
5. **Monitoring:** Set up alerts for rule violations and performance issues
