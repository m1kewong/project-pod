import 'dart:io';
import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;

class VideoUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  /// Upload a video file to Firebase Storage and create a video document in Firestore  Future<String> uploadVideo({
    required File videoFile,
    required String title,
    required String description,
    List<String> hashtags = const [],
    String? category,
    Map<String, double>? location,
    String privacy = 'public',
    Function(double)? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Validate file
    if (!videoFile.existsSync()) {
      throw Exception('Video file does not exist');
    }

    final fileSize = await videoFile.length();
    const maxSize = 100 * 1024 * 1024; // 100MB limit
    if (fileSize > maxSize) {
      throw Exception('Video file too large. Maximum size is 100MB.');
    }

    // Validate file extension
    final extension = path.extension(videoFile.path).toLowerCase();
    const allowedExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm'];
    if (!allowedExtensions.contains(extension)) {
      throw Exception('Unsupported video format. Allowed: ${allowedExtensions.join(', ')}');
    }

    try {      // Generate unique video ID and filename
      final videoId = _generateVideoId();
      final fileName = '$videoId$extension';
      final storageRef = _storage.ref().child('uploads/$fileName');      // Create upload task with metadata
      final metadata = SettableMetadata(
        contentType: _getContentType(extension),
        customMetadata: {
          'uploadedBy': user?.uid ?? 'test-user-upload', // Temporary for testing
          'originalName': path.basename(videoFile.path),
          'title': title,
        },
      );

      final uploadTask = storageRef.putFile(videoFile, metadata);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Get basic video metadata
      final videoMetadata = await _extractVideoMetadata(videoFile);      // Create video document in Firestore
      final videoDoc = await _createVideoDocument(
        videoId: videoId,
        userId: user?.uid ?? 'test-user-upload', // Temporary for testing
        title: title,
        description: description,
        hashtags: hashtags,
        category: category,
        location: location,
        privacy: privacy,
        originalUrl: downloadUrl,
        fileName: fileName,
        fileSize: fileSize,
        metadata: videoMetadata,
      );

      return videoId;
    } catch (e) {
      throw Exception('Failed to upload video: $e');
    }
  }

  /// Extract basic video metadata (this is a simplified version)
  Future<Map<String, dynamic>> _extractVideoMetadata(File videoFile) async {
    try {
      final fileSize = await videoFile.length();
      
      // In a real implementation, you would use a package like flutter_ffmpeg
      // to extract video metadata. For now, we'll return basic info.
      return {
        'width': 1080, // Default values - would be extracted from video
        'height': 1920,
        'frameRate': 30,
        'codec': 'h264',
        'bitrate': 2500000,
        'size': fileSize,
        'duration': 60, // Would be extracted from video
      };
    } catch (e) {
      // Return default metadata if extraction fails
      return {
        'width': 1080,
        'height': 1920,
        'frameRate': 30,
        'codec': 'unknown',
        'bitrate': 0,
        'size': await videoFile.length(),
        'duration': 0,
      };
    }
  }

  /// Create video document in Firestore
  Future<void> _createVideoDocument({
    required String videoId,
    required String userId,
    required String title,
    required String description,
    required List<String> hashtags,
    String? category,
    Map<String, double>? location,
    required String privacy,
    required String originalUrl,
    required String fileName,
    required int fileSize,
    required Map<String, dynamic> metadata,
  }) async {
    final now = DateTime.now();
    
    final videoData = {
      'userId': userId,
      'title': title,
      'description': description,
      'hashtags': hashtags,
      'category': category,
      'duration': metadata['duration'] ?? 0,
      'thumbnailUrl': '', // Will be generated during processing
      'videoUrls': {
        'original': originalUrl,
        'hls': '', // Will be populated after transcoding
        'mp4_720p': '',
        'mp4_480p': '',
      },
      'metadata': metadata,
      'privacy': privacy,
      'status': 'processing', // Will change to 'published' after transcoding
      'likeCount': 0,
      'commentCount': 0,
      'shareCount': 0,
      'viewCount': 0,
      'danmuCount': 0,
      'location': location,
      'createdAt': now,
      'updatedAt': now,
      'publishedAt': null, // Will be set when status changes to 'published'
    };

    await _firestore.collection('videos').doc(videoId).set(videoData);

    // Update user's video count
    await _firestore.collection('users').doc(userId).update({
      'videoCount': FieldValue.increment(1),
      'updatedAt': now,
    });

    // Add to user's activity feed
    await _firestore.collection('activities').add({
      'userId': userId,
      'type': 'video_upload',
      'data': {
        'videoId': videoId,
        'videoTitle': title,
      },
      'createdAt': now,
    });
  }

  /// Generate a unique video ID
  String _generateVideoId() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(16, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Get content type based on file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.avi':
        return 'video/x-msvideo';
      case '.mkv':
        return 'video/x-matroska';
      case '.webm':
        return 'video/webm';
      default:
        return 'video/mp4';
    }
  }

  /// Get upload progress for a specific task
  Stream<double> getUploadProgress(UploadTask task) {
    return task.snapshotEvents.map((snapshot) {
      return snapshot.bytesTransferred / snapshot.totalBytes;
    });
  }

  /// Cancel an ongoing upload
  Future<void> cancelUpload(UploadTask task) async {
    await task.cancel();
  }

  /// Delete a video (both from Storage and Firestore)
  Future<void> deleteVideo(String videoId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get video document to check ownership
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      if (!videoDoc.exists) {
        throw Exception('Video not found');
      }

      final videoData = videoDoc.data()!;
      if (videoData['userId'] != user.uid) {
        throw Exception('Not authorized to delete this video');
      }

      // Delete from Storage
      final videoUrls = videoData['videoUrls'] as Map<String, dynamic>;
      for (final url in videoUrls.values) {
        if (url is String && url.isNotEmpty) {
          try {
            final ref = _storage.refFromURL(url);
            await ref.delete();
          } catch (e) {
            // Continue even if some files fail to delete
            print('Failed to delete storage file: $e');
          }
        }
      }

      // Delete from Firestore
      await _firestore.collection('videos').doc(videoId).delete();

      // Update user's video count
      await _firestore.collection('users').doc(user.uid).update({
        'videoCount': FieldValue.increment(-1),
        'updatedAt': DateTime.now(),
      });

    } catch (e) {
      throw Exception('Failed to delete video: $e');
    }
  }

  /// Get user's uploaded videos
  Stream<List<Map<String, dynamic>>> getUserVideos(String userId) {
    return _firestore
        .collection('videos')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Update video metadata (title, description, etc.)
  Future<void> updateVideoMetadata({
    required String videoId,
    String? title,
    String? description,
    List<String>? hashtags,
    String? privacy,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Check ownership
    final videoDoc = await _firestore.collection('videos').doc(videoId).get();
    if (!videoDoc.exists) {
      throw Exception('Video not found');
    }

    final videoData = videoDoc.data()!;
    if (videoData['userId'] != user.uid) {
      throw Exception('Not authorized to edit this video');
    }

    // Update only provided fields
    final updates = <String, dynamic>{
      'updatedAt': DateTime.now(),
    };

    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (hashtags != null) updates['hashtags'] = hashtags;
    if (privacy != null) updates['privacy'] = privacy;

    await _firestore.collection('videos').doc(videoId).update(updates);
  }
}
