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
      throw Exception('User not authenticated');
    }
    
    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
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
  }

  /// Create a new danmu comment
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
      
      throw Exception('Failed to create danmu: ${response.statusCode}');
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
        
        // Update cache
        _cachedDanmu[videoId] = danmuList;
        
        controller.add(danmuList);
        notifyListeners();
      },
      onError: (error) {
        print('Error streaming danmu: $error');
        controller.addError(error);
      },
    );
    
    _activeStreams[videoId] = subscription;
    
    // Clean up when stream is cancelled
    controller.onCancel = () {
      subscription.cancel();
      _activeStreams.remove(videoId);
    };
    
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
    final startTime = currentTime - windowSeconds;
    final endTime = currentTime + windowSeconds;
    
    return allDanmu
        .where((danmu) => 
            danmu.timestamp >= startTime && 
            danmu.timestamp <= endTime)
        .toList();
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
