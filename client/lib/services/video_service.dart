import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VideoService {
  static const String _baseUrl = 'https://genz-video-api-56249782826.asia-east1.run.app/api/v1';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get authorization headers
  Future<Map<String, String>> _getHeaders() async {
    final user = _auth.currentUser;
    final headers = {
      'Content-Type': 'application/json',
    };

    if (user != null) {
      try {
        final token = await user.getIdToken();
        headers['Authorization'] = 'Bearer $token';
      } catch (e) {
        print('Error getting auth token: $e');
      }
    }

    return headers;
  }

  // Get video feed with pagination and sorting
  Future<VideoFeedResponse> getVideoFeed({
    int page = 1,
    int limit = 20,
    String sort = 'date', // date, popular, views
    String order = 'desc',
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$_baseUrl/videos/feed/mock').replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
        'sort': sort,
        'order': order,
      });

      print('Fetching video feed from: $uri');
      
      final response = await http.get(uri, headers: headers);
      
      print('Video feed response status: ${response.statusCode}');
      print('Video feed response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return VideoFeedResponse.fromJson(data['data']);
        } else {
          throw Exception('API returned error: ${data['error'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('Failed to load video feed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getVideoFeed: $e');
      // Fallback to mock data if API fails
      return _getMockVideoFeed(page: page, limit: limit);
    }
  }

  // Search videos
  Future<VideoSearchResponse> searchVideos({
    required String query,
    int page = 1,
    int limit = 20,
    String? tags,
    String sort = 'relevance', // relevance, date, views, likes
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = {
        'q': query,
        'page': page.toString(),
        'limit': limit.toString(),
        'sort': sort,
      };
      
      if (tags != null && tags.isNotEmpty) {
        queryParams['tags'] = tags;
      }

      final uri = Uri.parse('$_baseUrl/videos/search').replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return VideoSearchResponse.fromJson(data['data']);
        } else {
          throw Exception('API returned error: ${data['error'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('Failed to search videos: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in searchVideos: $e');
      // Return empty results on error
      return VideoSearchResponse(
        videos: [],
        query: query,
        pagination: PaginationInfo(
          page: page,
          limit: limit,
          total: 0,
          hasMore: false,
        ),
      );
    }
  }

  // Get single video details
  Future<VideoModel?> getVideo(String videoId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$_baseUrl/videos/$videoId');

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return VideoModel.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error in getVideo: $e');
      return null;
    }
  }

  // Like/unlike video
  Future<bool> toggleVideoLike(String videoId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$_baseUrl/videos/$videoId/like');

      final response = await http.post(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data']['isLiked'] ?? false;
        }
      }
      return false;
    } catch (e) {
      print('Error in toggleVideoLike: $e');
      return false;
    }
  }

  // Mock data fallback
  VideoFeedResponse _getMockVideoFeed({int page = 1, int limit = 20}) {
    final mockVideos = [
      VideoModel(
        id: 'mock-1',
        title: 'Amazing Sunset Timelapse',
        description: 'Beautiful sunset captured over the city skyline',
        thumbnailUrl: 'https://picsum.photos/id/1001/400/600',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        duration: 120,
        viewCount: 15420,
        likeCount: 1254,
        commentCount: 87,
        tags: ['sunset', 'timelapse', 'nature'],
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        user: UserInfo(
          uid: 'user1',
          displayName: 'Nature Lover',
          username: 'nature_shots',
          profilePicture: 'https://picsum.photos/id/91/200/200',
        ),
      ),
      VideoModel(
        id: 'mock-2',
        title: 'Epic Dance Battle',
        description: 'Street dancers showcase their incredible moves',
        thumbnailUrl: 'https://picsum.photos/id/1002/400/600',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        duration: 180,
        viewCount: 28750,
        likeCount: 2548,
        commentCount: 154,
        tags: ['dance', 'street', 'battle'],
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        user: UserInfo(
          uid: 'user2',
          displayName: 'Dance King',
          username: 'dance_master',
          profilePicture: 'https://picsum.photos/id/92/200/200',
        ),
      ),
      VideoModel(
        id: 'mock-3',
        title: 'Cute Cat Compilation',
        description: 'The most adorable cats doing silly things',
        thumbnailUrl: 'https://picsum.photos/id/1003/400/600',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        duration: 90,
        viewCount: 45870,
        likeCount: 4587,
        commentCount: 245,
        tags: ['cats', 'cute', 'funny'],
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        user: UserInfo(
          uid: 'user3',
          displayName: 'Cat Lady',
          username: 'cat_lover',
          profilePicture: 'https://picsum.photos/id/93/200/200',
        ),
      ),
      VideoModel(
        id: 'mock-4',
        title: 'Coffee Art Tutorial',
        description: 'Learn how to create beautiful latte art',
        thumbnailUrl: 'https://picsum.photos/id/1004/400/600',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
        duration: 240,
        viewCount: 12450,
        likeCount: 987,
        commentCount: 65,
        tags: ['coffee', 'tutorial', 'art'],
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        user: UserInfo(
          uid: 'user4',
          displayName: 'Barista Pro',
          username: 'coffee_art',
          profilePicture: 'https://picsum.photos/id/94/200/200',
        ),
      ),
      VideoModel(
        id: 'mock-5',
        title: 'Mountain Hiking Adventure',
        description: 'Epic journey to the summit with breathtaking views',
        thumbnailUrl: 'https://picsum.photos/id/1005/400/600',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
        duration: 300,
        viewCount: 34560,
        likeCount: 3254,
        commentCount: 134,
        tags: ['hiking', 'mountain', 'adventure'],
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        user: UserInfo(
          uid: 'user5',
          displayName: 'Adventure Time',
          username: 'mountain_hiker',
          profilePicture: 'https://picsum.photos/id/95/200/200',
        ),
      ),
    ];

    final startIndex = (page - 1) * limit;
    final endIndex = startIndex + limit;
    final paginatedVideos = mockVideos.length > startIndex 
        ? mockVideos.sublist(startIndex, endIndex.clamp(0, mockVideos.length))
        : <VideoModel>[];

    return VideoFeedResponse(
      videos: paginatedVideos,
      pagination: PaginationInfo(
        page: page,
        limit: limit,
        total: mockVideos.length,
        hasMore: endIndex < mockVideos.length,
      ),
    );
  }
}

// Data models
class VideoFeedResponse {
  final List<VideoModel> videos;
  final PaginationInfo pagination;

  VideoFeedResponse({
    required this.videos,
    required this.pagination,
  });

  factory VideoFeedResponse.fromJson(Map<String, dynamic> json) {
    return VideoFeedResponse(
      videos: (json['videos'] as List<dynamic>)
          .map((v) => VideoModel.fromJson(v as Map<String, dynamic>))
          .toList(),
      pagination: PaginationInfo.fromJson(json['pagination'] as Map<String, dynamic>),
    );
  }
}

class VideoSearchResponse {
  final List<VideoModel> videos;
  final String query;
  final PaginationInfo pagination;

  VideoSearchResponse({
    required this.videos,
    required this.query,
    required this.pagination,
  });

  factory VideoSearchResponse.fromJson(Map<String, dynamic> json) {
    return VideoSearchResponse(
      videos: (json['videos'] as List<dynamic>)
          .map((v) => VideoModel.fromJson(v as Map<String, dynamic>))
          .toList(),
      query: json['query'] as String,
      pagination: PaginationInfo.fromJson(json['pagination'] as Map<String, dynamic>),
    );
  }
}

class VideoModel {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String videoUrl;
  final int duration;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final List<String> tags;
  final DateTime createdAt;
  final UserInfo? user;

  VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.duration,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.tags,
    required this.createdAt,
    this.user,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      videoUrl: json['videoUrl'] as String? ?? '',
      duration: json['duration'] as int? ?? 0,
      viewCount: json['viewCount'] as int? ?? 0,
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
      user: json['user'] != null ? UserInfo.fromJson(json['user'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'videoUrl': videoUrl,
      'duration': duration,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'user': user?.toJson(),
    };
  }
}

class UserInfo {
  final String uid;
  final String displayName;
  final String username;
  final String? profilePicture;

  UserInfo({
    required this.uid,
    required this.displayName,
    required this.username,
    this.profilePicture,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String? ?? '',
      username: json['username'] as String? ?? '',
      profilePicture: json['profilePicture'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'username': username,
      'profilePicture': profilePicture,
    };
  }
}

class PaginationInfo {
  final int page;
  final int limit;
  final int total;
  final bool hasMore;

  PaginationInfo({
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: json['page'] as int,
      limit: json['limit'] as int,
      total: json['total'] as int,
      hasMore: json['hasMore'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'limit': limit,
      'total': total,
      'hasMore': hasMore,
    };
  }
}
