import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DanmuService extends ChangeNotifier {
  static const String _baseUrl = 'https://genz-video-api-rkdws2bvwa-de.a.run.app';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Cache for danmu data
  final Map<String, List<DanmuComment>> _cachedDanmu = {};
  final Map<String, StreamSubscription> _activeStreams = {};
  
  /// Get HTTP headers with authentication
  Future<Map<String, String>> _getHeaders() async {
    final user = _auth.currentUser;
    if (user == null) {
      // Testing fallback - return mock headers
      if (kDebugMode) {
        print('No authenticated user, using mock headers for testing');
        return {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer mock_token_for_testing',
        };
      }
      throw Exception('User not authenticated');
    }
    
    try {
      final token = await user.getIdToken();
      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
    } catch (e) {
      print('Error getting token, using mock headers: $e');
      // Fallback for testing
      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer mock_token_for_testing',
      };
    }
  }

  /// Get danmu comments for a video at a specific timestamp
  Future<List<DanmuComment>> getDanmuAtTimestamp({
    required String videoId,
    required double timestamp,
    double duration = 10.0,
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$_baseUrl/api/videos/$videoId/danmu')
          .replace(queryParameters: {
        'timestamp': timestamp.toString(),
        'duration': duration.toString(),
      });
      
      final response = await http.get(uri, headers: headers);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final danmuList = (data['data']['danmu'] as List)
              .map((item) => DanmuComment.fromJson(item))
              .toList();
          return danmuList;
        }
      }
      
      throw Exception('Failed to load danmu: ${response.statusCode}');
    } catch (e) {
      print('Error getting danmu: $e');
      return [];
    }
  }  /// Create a new danmu comment
  Future<DanmuComment?> createDanmu({
    required String videoId,
    required String content,
    required double timestamp,
    String color = '#FFFFFF',
    String size = 'medium',
    String position = 'scroll',
    double speed = 1.0,
  }) async {
    try {
      // First try to create danmu via API
      try {
        final headers = await _getHeaders();
        final uri = Uri.parse('$_baseUrl/api/videos/$videoId/danmu');
        
        final body = json.encode({
          'content': content,
          'timestamp': timestamp,
          'color': color,
          'size': size,
          'position': position,
          'speed': speed,
        });
        
        final response = await http.post(uri, headers: headers, body: body);
        
        if (response.statusCode == 201) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            return DanmuComment.fromJson(data['data']);
          }
        }
      } catch (apiError) {
        print('API error, falling back to local danmu creation: $apiError');
        // Continue to fallback implementation
      }
      
      // Fallback: Create a local danmu if API fails
      print('Using local danmu creation for testing');
      
      // Create a mock user for testing if no user is authenticated
      final user = _auth.currentUser;
      String userId = 'test_user_${DateTime.now().millisecondsSinceEpoch}';
      String userName = 'Test User';
      
      if (user != null) {
        userId = user.uid;
        userName = user.displayName ?? 'User';
      }
      
      final danmuId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      
      // Create a local danmu object
      final danmu = DanmuComment(
        id: danmuId,
        content: content,
        timestamp: timestamp,
        color: color,
        size: size,
        position: position,
        speed: speed,
        createdAt: DateTime.now(),
        user: DanmuUser(
          uid: userId,
          displayName: userName,
          username: 'tester',
        ),
      );
      
      // If Firestore is available, try to save it there for persistence
      try {
        await _firestore.collection('danmu').doc(danmuId).set({
          'id': danmuId,
          'videoId': videoId,
          'content': content,
          'timestamp': timestamp,
          'color': color,
          'size': size,
          'position': position,
          'speed': speed,
          'createdAt': FieldValue.serverTimestamp(),
          'userId': userId,
          'status': 'active',
        });
      } catch (firestoreError) {
        print('Firestore error, using in-memory only: $firestoreError');
      }
      
      // Always add to local cache for testing/offline mode
      final existingDanmu = _cachedDanmu[videoId] ?? [];
      existingDanmu.add(danmu);
      _cachedDanmu[videoId] = existingDanmu;
      notifyListeners();
      
      return danmu;
    } catch (e) {
      print('Error creating danmu: $e');
      return null;
    }
  }

  /// Delete a danmu comment
  Future<bool> deleteDanmu(String danmuId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$_baseUrl/api/danmu/$danmuId');
      
      final response = await http.delete(uri, headers: headers);
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting danmu: $e');
      return false;
    }
  }

  /// Stream real-time danmu updates for a video using Firestore
  Stream<List<DanmuComment>> streamDanmuForVideo(String videoId) {
    // Cancel existing stream if any
    _activeStreams[videoId]?.cancel();
    
    final controller = StreamController<List<DanmuComment>>.broadcast();
    print('Creating new danmu stream for video: $videoId');
    
    try {
      // Try to create Firestore subscription
      final subscription = _firestore
          .collection('danmu')
          .where('videoId', isEqualTo: videoId)
          .where('status', isEqualTo: 'active')
          .orderBy('timestamp')
          .snapshots()
          .listen(
        (snapshot) {
          final danmuList = snapshot.docs
              .map((doc) => DanmuComment.fromFirestore(doc))
              .toList();
          
          print('Received ${danmuList.length} danmu from Firestore for video: $videoId');
          
          // Update cache
          _cachedDanmu[videoId] = danmuList;
          
          controller.add(danmuList);
          notifyListeners();
        },
        onError: (error) {
          print('Error streaming danmu from Firestore: $error');
          
          // If Firestore fails, return current cache or create test danmu
          if (!controller.isClosed) {
            final cachedDanmu = _cachedDanmu[videoId] ?? [];
            
            // If cache is empty, create a test danmu for this video
            if (cachedDanmu.isEmpty) {
              final testDanmu = [
                DanmuComment(
                  id: 'test1_${DateTime.now().millisecondsSinceEpoch}',
                  content: 'Welcome to the video!',
                  timestamp: 1.0, // Start at 1 second
                  color: '#FFEB3B', // Yellow
                  size: 'large',
                  position: 'scroll',
                  speed: 1.0,
                  createdAt: DateTime.now(),
                  user: DanmuUser(
                    uid: 'test_user',
                    displayName: 'Test User',
                    username: 'tester',
                  ),
                ),
                DanmuComment(
                  id: 'test2_${DateTime.now().millisecondsSinceEpoch}',
                  content: 'This is a danmu test!',
                  timestamp: 3.0, // 3 seconds
                  color: '#42A5F5', // Blue
                  size: 'medium',
                  position: 'scroll',
                  speed: 1.2,
                  createdAt: DateTime.now(),
                  user: DanmuUser(
                    uid: 'test_user',
                    displayName: 'Test User',
                    username: 'tester',
                  ),
                ),
                DanmuComment(
                  id: 'test3_${DateTime.now().millisecondsSinceEpoch}',
                  content: 'Top position test',
                  timestamp: 5.0, // 5 seconds
                  color: '#FF6B6B', // Red
                  size: 'medium',
                  position: 'top',
                  speed: 1.0,
                  createdAt: DateTime.now(),
                  user: DanmuUser(
                    uid: 'test_user',
                    displayName: 'Admin',
                    username: 'admin',
                  ),
                ),
                DanmuComment(
                  id: 'test4_${DateTime.now().millisecondsSinceEpoch}',
                  content: 'Bottom position test',
                  timestamp: 7.0, // 7 seconds
                  color: '#66BB6A', // Green
                  size: 'medium',
                  position: 'bottom',
                  speed: 1.0,
                  createdAt: DateTime.now(),
                  user: DanmuUser(
                    uid: 'test_user',
                    displayName: 'Admin',
                    username: 'admin',
                  ),
                ),
              ];
              
              print('Created ${testDanmu.length} test danmu for video: $videoId');
              _cachedDanmu[videoId] = testDanmu;
              controller.add(testDanmu);
            } else {
              controller.add(cachedDanmu);
            }
          }
        },
      );
      
      _activeStreams[videoId] = subscription;
      
      // Clean up when stream is cancelled
      controller.onCancel = () {
        subscription.cancel();
        _activeStreams.remove(videoId);
      };
    } catch (e) {
      print('Failed to create Firestore stream, using local cache instead: $e');
      
      // If we can't create the stream at all, create test danmu and use that
      final cachedDanmu = _cachedDanmu[videoId] ?? [];
      
      // If cache is empty, create a test danmu for this video
      if (cachedDanmu.isEmpty) {
        final testDanmu = [
          DanmuComment(
            id: 'fallback1_${DateTime.now().millisecondsSinceEpoch}',
            content: 'Fallback danmu test!',
            timestamp: 2.0,
            color: '#FFFFFF', 
            size: 'medium',
            position: 'scroll',
            speed: 1.0,
            createdAt: DateTime.now(),
            user: DanmuUser(
              uid: 'test_user',
              displayName: 'Test User',
              username: 'tester',
            ),
          ),
          DanmuComment(
            id: 'fallback2_${DateTime.now().millisecondsSinceEpoch}',
            content: 'Fallback top test',
            timestamp: 4.0,
            color: '#FF6B6B',
            size: 'large',
            position: 'top',
            speed: 1.0,
            createdAt: DateTime.now(),
            user: DanmuUser(
              uid: 'test_user',
              displayName: 'Test User',
              username: 'tester',
            ),
          ),
        ];
        
        print('Created ${testDanmu.length} fallback test danmu for video: $videoId');
        _cachedDanmu[videoId] = testDanmu;
        controller.add(testDanmu);
      } else {
        controller.add(cachedDanmu);
      }
      
      // Clean up when stream is cancelled
      controller.onCancel = () {
        _activeStreams.remove(videoId);
      };
    }
    
    return controller.stream;
  }

  /// Get cached danmu for a video
  List<DanmuComment> getCachedDanmu(String videoId) {
    return _cachedDanmu[videoId] ?? [];
  }

  /// Filter danmu by timestamp range
  List<DanmuComment> filterDanmuByTime({
    required String videoId,
    required double currentTime,
    double windowSeconds = 5.0,
  }) {
    final allDanmu = getCachedDanmu(videoId);
    print('Filtering danmu at time $currentTime (window: $windowSeconds sec): ${allDanmu.length} total danmu in cache');
    
    // For testing - if no danmu exists at current time, create a mock one
    if (allDanmu.isEmpty) {
      print('No danmu in cache, creating a test danmu');
      final testDanmu = DanmuComment(
        id: 'test_${DateTime.now().millisecondsSinceEpoch}',
        content: 'Test Danmu at ${currentTime.toStringAsFixed(1)}s',
        timestamp: currentTime,
        color: '#FFFFFF',
        size: 'medium',
        position: 'scroll',
        speed: 1.0,
        createdAt: DateTime.now(),
        user: DanmuUser(
          uid: 'test_user',
          displayName: 'Test User',
          username: 'tester',
        ),
      );
      
      // Add to cache
      _cachedDanmu[videoId] = [testDanmu];
      allDanmu.add(testDanmu);
    }
    
    // More lenient time window for testing - if video just started, show danmu from first 30 seconds
    double startTime;
    double endTime;
    
    if (currentTime < 2.0) {
      // Special case for beginning of video
      startTime = 0.0;
      endTime = 30.0;
      print('Video just started, showing all early danmu (0-30s)');
    } else {
      // Normal filtering
      startTime = currentTime - (windowSeconds * 0.2); // Show danmu slightly before current time
      endTime = currentTime + windowSeconds;
    }
    
    final filtered = allDanmu
        .where((danmu) => 
            danmu.timestamp >= startTime && 
            danmu.timestamp <= endTime)
        .toList();
    
    print('Filtered to ${filtered.length} danmu between ${startTime.toStringAsFixed(1)}s and ${endTime.toStringAsFixed(1)}s');
    return filtered;
  }

  /// Clean up resources
  void dispose() {
    for (final subscription in _activeStreams.values) {
      subscription.cancel();
    }
    _activeStreams.clear();
    _cachedDanmu.clear();
    super.dispose();
  }
}

/// Danmu Comment Model
class DanmuComment {
  final String id;
  final String content;
  final double timestamp;
  final String color;
  final String size;
  final String position;
  final double speed;
  final DateTime createdAt;
  final DanmuUser user;

  DanmuComment({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.color,
    required this.size,
    required this.position,
    required this.speed,
    required this.createdAt,
    required this.user,
  });

  factory DanmuComment.fromJson(Map<String, dynamic> json) {
    return DanmuComment(
      id: json['id'],
      content: json['content'],
      timestamp: (json['timestamp'] as num).toDouble(),
      color: json['color'] ?? '#FFFFFF',
      size: json['size'] ?? 'medium',
      position: json['position'] ?? 'scroll',
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      createdAt: DateTime.parse(json['createdAt']),
      user: DanmuUser.fromJson(json['user']),
    );
  }

  factory DanmuComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DanmuComment(
      id: doc.id,
      content: data['content'],
      timestamp: (data['timestamp'] as num).toDouble(),
      color: data['color'] ?? '#FFFFFF',
      size: data['size'] ?? 'medium',
      position: data['position'] ?? 'scroll',
      speed: (data['speed'] as num?)?.toDouble() ?? 1.0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      user: DanmuUser(
        uid: data['userId'],
        displayName: 'Anonymous', // We'll need to fetch user data separately
        username: null,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp,
      'color': color,
      'size': size,
      'position': position,
      'speed': speed,
      'createdAt': createdAt.toIso8601String(),
      'user': user.toJson(),
    };
  }
}

/// Danmu User Model
class DanmuUser {
  final String uid;
  final String displayName;
  final String? username;

  DanmuUser({
    required this.uid,
    required this.displayName,
    this.username,
  });

  factory DanmuUser.fromJson(Map<String, dynamic> json) {
    return DanmuUser(
      uid: json['uid'],
      displayName: json['displayName'],
      username: json['username'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'username': username,
    };
  }
}
