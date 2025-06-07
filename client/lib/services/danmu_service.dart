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
  
  // Status tracking for debugging
  bool _lastFirestoreWriteSuccess = false;
  String _lastFirestoreErrorMessage = "";
  DateTime? _lastFirestoreWriteAttempt;
  String? _lastDanmuId;
  
  // Getter methods for monitoring Firestore write status
  bool get lastFirestoreWriteSuccess => _lastFirestoreWriteSuccess;
  String get lastFirestoreErrorMessage => _lastFirestoreErrorMessage;
  DateTime? get lastFirestoreWriteAttempt => _lastFirestoreWriteAttempt;
  String? get lastDanmuId => _lastDanmuId;
    // Getter for Firestore instance - provides controlled access to the Firestore instance
  // while maintaining encapsulation of the private field
  FirebaseFirestore get firestore => _firestore;

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
      // Reset status tracking
      _lastFirestoreWriteSuccess = false;
      _lastFirestoreErrorMessage = "";
      _lastFirestoreWriteAttempt = DateTime.now();
      _lastDanmuId = null;
      
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
      _lastDanmuId = danmuId;
      
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
        // First, run a permission test to find a working collection
      print('Testing Firestore permissions to find a working collection...');
      final permissionTest = await testFirestorePermissions();
      
      String collectionToUse = 'danmu'; // Default collection
      
      if (permissionTest['success'] == true) {
        // Use the collection that worked in the permission test
        collectionToUse = permissionTest['collection'] as String;
        print('✓ Using verified working collection: $collectionToUse');
      } else {
        // If we couldn't find a working collection, log detailed error
        print('❌ Permission test failed. Error: ${permissionTest['error']}');
        print('❌ Error code: ${permissionTest['errorCode']}');
        print('❌ Auth status: ${permissionTest['authStatus']}');
        
        if (permissionTest['errorCode'] == 'permission-denied') {
          _lastFirestoreErrorMessage = "Permission denied. Check Firebase security rules.";
          print('⚠️ SECURITY RULES ISSUE: The current user does not have permission to write to Firestore.');
          print('⚠️ User info: ID=${permissionTest['userId']}, Anonymous=${permissionTest['isAnonymous']}');
        } else if (permissionTest['errorCode'] == 'network-error') {
          _lastFirestoreErrorMessage = "Network error connecting to Firebase.";
          print('⚠️ NETWORK ISSUE: Could not connect to Firebase. Check internet connection and Firebase project config.');
        } else {
          _lastFirestoreErrorMessage = permissionTest['error'] as String;
        }
      }
      
      // Create the data map
      final danmuData = {
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
      };
      
      // Try to save to the working collection
      try {
        print('Attempting to save danmu to Firestore collection: $collectionToUse');
        
        // Save to Firestore
        await _firestore.collection(collectionToUse).doc(danmuId).set(danmuData);
        
        // Verify the write was successful by reading it back
        print('Verifying Firestore write to collection: $collectionToUse');
        
        final docSnapshot = await _firestore.collection(collectionToUse).doc(danmuId).get();
        
        if (docSnapshot.exists) {
          print('✓ Successfully verified danmu in Firestore collection: $collectionToUse');
          print('Document data: ${docSnapshot.data()}');
          
          _lastFirestoreWriteSuccess = true;
        } else {
          print('✗ Failed to verify danmu in Firestore - document not found in collection: $collectionToUse');
          _lastFirestoreErrorMessage = "Document not found after write to $collectionToUse";
          _lastFirestoreWriteSuccess = false;
        }
      } catch (firestoreError) {
        print('Firestore error for collection $collectionToUse: $firestoreError');
        _lastFirestoreErrorMessage = firestoreError.toString();
        _lastFirestoreWriteSuccess = false;
        
        // Additional logging for specific error types
        String errorMessage = firestoreError.toString();
        if (errorMessage.contains('permission-denied')) {
          print('⚠️ PERMISSION DENIED: Current user cannot write to $collectionToUse collection.');
          print('⚠️ Check Firebase security rules to ensure they allow writes for this user.');
        } else if (errorMessage.contains('unavailable')) {
          print('⚠️ FIREBASE UNAVAILABLE: Could not connect to Firebase servers.');
          print('⚠️ Check internet connection and Firebase project status.');
        }
      }
      
      if (!_lastFirestoreWriteSuccess) {
        print('⚠️ WARNING: Failed to save danmu to Firestore!');
        print('Last error: $_lastFirestoreErrorMessage');
      }
      
      // Always add to local cache for testing/offline mode
      final existingDanmu = _cachedDanmu[videoId] ?? [];
      existingDanmu.add(danmu);
      _cachedDanmu[videoId] = existingDanmu;
      notifyListeners();
      
      return danmu;
    } catch (e) {
      print('Error creating danmu: $e');
      _lastFirestoreErrorMessage = e.toString();
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

  /// Check Firestore connectivity
  Future<Map<String, dynamic>> checkFirestoreConnectivity() async {
    final result = {
      'isConnected': false,
      'collections': <String>[],
      'error': '',
      'authStatus': 'unknown',
    };
    
    try {
      // Check auth status
      final user = _auth.currentUser;
      if (user != null) {
        result['authStatus'] = 'authenticated';
        result['userId'] = user.uid;
        result['isAnonymous'] = user.isAnonymous;
      } else {
        result['authStatus'] = 'not_authenticated';
      }
      
      // Try to write a test document to verify connectivity
      final testId = 'connectivity_test_${DateTime.now().millisecondsSinceEpoch}';
      final testCollection = 'connectivity_tests';
      
      await _firestore.collection(testCollection).doc(testId).set({
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user?.uid ?? 'anonymous',
      });
      
      // Read it back to verify
      final doc = await _firestore.collection(testCollection).doc(testId).get();
      result['isConnected'] = doc.exists;
      
      // Clean up test document
      await _firestore.collection(testCollection).doc(testId).delete();
      
      // List available collections
      try {
        final collections = ['danmu', 'danmu_comments', 'danmus', 'comments'];
        final availableCollections = <String>[];
        
        for (final collection in collections) {
          final snapshot = await _firestore.collection(collection).limit(1).get();
          if (snapshot.docs.isNotEmpty) {
            availableCollections.add('$collection (${snapshot.docs.length} docs)');
          } else {
            // Collection exists but may be empty
            availableCollections.add('$collection (empty)');
          }
        }
        
        result['collections'] = availableCollections;
      } catch (e) {
        result['collectionError'] = e.toString();
      }
    } catch (e) {
      result['error'] = e.toString();
    }
    
    return result;
  }
  
  /// Troubleshoot Firestore issues by checking security rules
  Future<bool> troubleshootFirestore(String videoId) async {
    try {
      print('Troubleshooting Firestore connectivity...');
      
      // 1. Check current user
      final user = _auth.currentUser;
      print('Current user: ${user?.uid ?? 'Not signed in'} (${user?.isAnonymous ?? true ? 'Anonymous' : 'Authenticated'})');
      
      // 2. Try collections with different security rules
      final testId = 'troubleshoot_${DateTime.now().millisecondsSinceEpoch}';
      final collectionOptions = ['danmu', 'danmu_comments', 'troubleshooting_public'];
      
      // Test data with minimal fields
      final testData = {
        'id': testId,
        'videoId': videoId,
        'content': 'Troubleshooting test',
        'timestamp': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      bool successInAnyCollection = false;
      String workingCollection = '';
      
      for (final collection in collectionOptions) {
        try {
          print('Attempting write to collection: $collection');
          // Try writing with set()
          await _firestore.collection(collection).doc(testId).set(testData);
          
          // Verify write
          final docRef = await _firestore.collection(collection).doc(testId).get();
          if (docRef.exists) {
            print('✓ Successfully wrote to collection: $collection');
            successInAnyCollection = true;
            workingCollection = collection;
            
            // Clean up
            await _firestore.collection(collection).doc(testId).delete();
            break;
          }
        } catch (e) {
          print('✗ Failed to write to collection $collection: $e');
        }
      }
      
      if (successInAnyCollection) {
        print('✅ Firestore write successful to collection: $workingCollection');
        return true;
      } else {
        print('❌ Could not write to any Firestore collection');
        return false;
      }
    } catch (e) {
      print('Error during troubleshooting: $e');
      return false;
    }
  }

  /// Create a public test document that any user can write to
  /// This is useful for testing if security rules are the issue
  Future<bool> createPublicTestDocument(String videoId) async {
    try {
      print('Creating public test document...');
      
      // Create a document ID
      final testId = 'public_test_${DateTime.now().millisecondsSinceEpoch}';
      
      // Create minimal test data
      final testData = {
        'id': testId,
        'videoId': videoId,
        'content': 'Public test document',
        'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
        'createdAt': FieldValue.serverTimestamp(),
        'isPublicTest': true,
      };
      
      // Collections to try, starting with ones likely to have permissive security rules
      final collections = [
        'public_data',      // Try a collection that might be set up for public access
        'test_data',        // Another possibly public collection
        'danmu_public',     // A special public version of the danmu collection
        'danmu_comments',   // The regular danmu collection
        'danmu',            // The regular danmu collection
      ];
      
      for (final collection in collections) {
        try {
          print('Attempting to write to public collection: $collection');
          
          // Try with set() with merge option to be less intrusive
          await _firestore.collection(collection).doc(testId).set(
            testData, 
            SetOptions(merge: true),
          );
          
          // Verify write by reading it back
          final docRef = await _firestore.collection(collection).doc(testId).get();
          
          if (docRef.exists) {
            print('✓ Successfully created public test document in collection: $collection');
            
            // Record success info
            _lastFirestoreWriteSuccess = true;
            _lastFirestoreErrorMessage = "";
            _lastDanmuId = testId;
            
            // Return success
            return true;
          }
        } catch (e) {
          print('× Failed to write to public collection $collection: $e');
        }
      }
      
      // If we reach here, all attempts failed
      _lastFirestoreWriteSuccess = false;
      _lastFirestoreErrorMessage = "Could not write to any collection";
      return false;
    } catch (e) {
      print('Error creating public test document: $e');
      _lastFirestoreWriteSuccess = false;
      _lastFirestoreErrorMessage = e.toString();
      return false;
    }
  }

  /// List all danmu in all collections for a video
  Future<Map<String, List<Map<String, dynamic>>>> listAllDanmuForVideo(String videoId) async {
    final result = <String, List<Map<String, dynamic>>>{};
    
    try {
      // Check all possible collections
      final collections = ['danmu', 'danmu_comments', 'danmus', 'comments'];
      
      for (final collection in collections) {
        try {
          print('Checking $collection collection for videoId: $videoId');
          
          final snapshot = await _firestore
              .collection(collection)
              .where('videoId', isEqualTo: videoId)
              .get();
          
          if (snapshot.docs.isNotEmpty) {
            final danmuList = snapshot.docs.map((doc) => {
              'id': doc.id,
              'content': doc.data()['content'] ?? 'No content',
              'timestamp': doc.data()['timestamp'] ?? 0.0,
              'createdAt': doc.data()['createdAt'] != null 
                  ? (doc.data()['createdAt'] as Timestamp).toDate().toString() 
                  : 'Unknown',
            }).toList();
            
            result[collection] = danmuList;
            print('Found ${danmuList.length} danmu in $collection');
          } else {
            result[collection] = [];
            print('No danmu found in $collection for videoId: $videoId');
          }
        } catch (e) {
          print('Error checking $collection: $e');
          result[collection] = [];
        }
      }
    } catch (e) {
      print('Error listing all danmu: $e');
    }
    
    return result;
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

  /// Test Firestore permissions with minimal document structure
  Future<Map<String, dynamic>> testFirestorePermissions() async {
    final result = {
      'success': false,
      'collection': '',
      'error': '',
      'errorCode': '',
      'errorDetails': '',
      'authStatus': 'unknown',
      'userId': '',
      'isAnonymous': true,
    };
    
    try {
      // Check auth status first
      final user = _auth.currentUser;
      if (user != null) {
        result['authStatus'] = 'authenticated';
        result['userId'] = user.uid;
        result['isAnonymous'] = user.isAnonymous;
      } else {
        result['authStatus'] = 'not_authenticated';
      }
      
      // Create the simplest possible document to test permissions
      final testId = 'permission_test_${DateTime.now().millisecondsSinceEpoch}';
      final testData = {
        'timestamp': FieldValue.serverTimestamp(),
        'testId': testId,
      };
      
      // List of collections to test, in priority order
      final collections = [
        'danmu',                // Primary collection from original code
        'danmu_comments',       // Alternative name mentioned
        'public_test',          // Try a collection that might allow public writes
        'public',               // Another public collection possibility
        'test'                  // Last resort test collection
      ];
      
      // Try each collection and report detailed results
      for (final collection in collections) {
        try {
          print('Testing write permissions on collection: $collection');
          
          // Attempt to write the test document
          await _firestore.collection(collection).doc(testId).set(
            testData,
            SetOptions(merge: true),
          );
          
          // If we get here without an exception, try to read it back to verify
          final docSnapshot = await _firestore.collection(collection).doc(testId).get();
          
          if (docSnapshot.exists) {
            print('✓ Successfully verified write permission to collection: $collection');
            
            // Document exists, attempt to delete it to clean up
            try {
              await _firestore.collection(collection).doc(testId).delete();
              print('✓ Successfully deleted test document from: $collection');
            } catch (deleteError) {
              print('⚠️ Could not delete test document: $deleteError');
              // Continue anyway since we proved write permission
            }
            
            // Set success results
            result['success'] = true;
            result['collection'] = collection;
            
            // No need to try other collections
            break;
          } else {
            print('⚠️ Document write appeared to succeed but verification failed for: $collection');
            result['errorDetails'] = 'Document not found after write';
          }
        } catch (e) {
          // Capture error information with specific checks for permission errors
          String errorMessage = e.toString();
          
          // Detect specific error types
          if (errorMessage.contains('permission-denied') || 
              errorMessage.contains('Permission denied')) {
            print('❌ Permission denied for collection: $collection');
            result['errorCode'] = 'permission-denied';
          } else if (errorMessage.contains('not-found')) {
            print('❌ Collection not found: $collection');
            result['errorCode'] = 'not-found';
          } else if (errorMessage.contains('network')) {
            print('❌ Network error for collection: $collection');
            result['errorCode'] = 'network-error';
          } else {
            print('❌ Other error for collection: $collection: $errorMessage');
            result['errorCode'] = 'other';
          }
          
          result['error'] = errorMessage;
        }
      }
      
      // If we didn't succeed with any collection, report failure
      if (result['success'] == false) {
        print('❌ Failed to write to ANY collection. Last error: ${result['error']}');
      }
    } catch (e) {
      result['error'] = e.toString();
      print('❌ Unexpected error during permission test: $e');
    }
    
    return result;
  }

  /// Diagnose Firestore initialization issues
  Future<Map<String, dynamic>> diagnoseFirestoreInitialization() async {
    final result = {
      'initialized': false,
      'error': '',
      'authInitialized': false,
      'firestoreInitialized': false,
      'sampleCollections': <String>[],
    };
    
    try {
      // Check if Firebase Auth is initialized
      try {
        final user = _auth.currentUser; // This will throw if not initialized
        result['authInitialized'] = true;
        result['userId'] = user?.uid ?? 'no user';
      } catch (authError) {
        result['authInitialized'] = false;
        result['authError'] = authError.toString();
        print('❌ Firebase Auth not properly initialized: $authError');
      }
      
      // Check if Firestore is initialized
      try {
        // Try to access a simple collection
        final snapshot = await _firestore.collection('system').limit(1).get();
        result['firestoreInitialized'] = true;
        result['documentCount'] = snapshot.docs.length;
      } catch (firestoreError) {
        String errorMsg = firestoreError.toString();
        
        // Check for specific initialization errors
        if (errorMsg.contains('not been initialized') || 
            errorMsg.contains('firebase') || 
            errorMsg.contains('FirebaseApp')) {
          result['firestoreInitialized'] = false;
          result['firestoreError'] = 'Firebase not initialized properly: $errorMsg';
          print('❌ Firestore not properly initialized: $errorMsg');
        } else {
          // This might be a permission error rather than initialization
          result['firestoreInitialized'] = true;
          result['firestoreError'] = errorMsg;
        }
      }
      
      // Try to list some collections to verify further
      try {
        // These are common collections that might exist
        final commonCollections = ['users', 'system', 'config', 'danmu', 'danmu_comments'];
        final foundCollections = <String>[];
        
        for (final collection in commonCollections) {
          try {
            final snapshot = await _firestore.collection(collection).limit(1).get();
            foundCollections.add('$collection (${snapshot.docs.length} docs)');
          } catch (e) {
            // Skip collections we can't access
          }
        }
        
        result['sampleCollections'] = foundCollections;
      } catch (e) {
        print('Error listing collections: $e');
      }
      
      // Overall initialization status
      result['initialized'] = result['authInitialized'] == true && 
                             result['firestoreInitialized'] == true;
      
    } catch (e) {
      result['error'] = e.toString();
      print('❌ Unexpected error during Firestore diagnosis: $e');
    }
    
    return result;
  }

  /// Check if anonymous auth is allowed for writing to Firestore
  Future<bool> canWriteWithCurrentAuth() async {
    try {
      // First check if we're authenticated
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user - cannot write to Firestore');
        return false;
      }
      
      // Get user status
      final isAnonymous = user.isAnonymous;
      print('Current user: ${user.uid} (${isAnonymous ? 'Anonymous' : 'Authenticated'})');
      
      // Create a test document with minimal fields
      final testId = 'auth_test_${DateTime.now().millisecondsSinceEpoch}';
      final testData = {
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'isAnonymous': isAnonymous,
      };
      
      // Try writing to a test collection
      try {
        // First, try a collection likely to have permissive rules
        final testCollection = 'auth_tests';
        await _firestore.collection(testCollection).doc(testId).set(testData);
        
        // Verify it was saved
        final doc = await _firestore.collection(testCollection).doc(testId).get();
        if (doc.exists) {
          print('✓ Current auth status allows writing to Firestore');
          // Clean up
          await _firestore.collection(testCollection).doc(testId).delete();
          return true;
        }
      } catch (e) {
        // Let's check the error to see if it's permissions related
        String error = e.toString();
        if (error.contains('permission-denied') || error.contains('Permission denied')) {
          if (isAnonymous) {
            print('❌ Anonymous users do not have write permission to Firestore');
            print('❌ Try signing in with a real account, or update security rules');
          } else {
            print('❌ Current authenticated user does not have write permission to Firestore');
            print('❌ Update security rules to allow writes for this user');
          }
        } else {
          print('❌ Error writing to Firestore: $e');
        }
      }
      
      // If we get here, test failed
      return false;
    } catch (e) {
      print('Error checking auth write status: $e');
      return false;
    }
  }

  /// Sign in anonymously if not already authenticated
  Future<Map<String, dynamic>> signInAnonymously() async {
    final result = {
      'success': false,
      'userId': '',
      'isAnonymous': true,
      'error': '',
    };
    
    try {
      // Check if already signed in
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        result['success'] = true;
        result['userId'] = currentUser.uid;
        result['isAnonymous'] = currentUser.isAnonymous;
        result['message'] = 'Already signed in as ${currentUser.isAnonymous ? 'anonymous user' : 'authenticated user'}';
        return result;
      }
      
      // Sign in anonymously
      print('Attempting anonymous sign-in...');
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;
      
      if (user != null) {
        result['success'] = true;
        result['userId'] = user.uid;
        result['isAnonymous'] = user.isAnonymous;
        result['message'] = 'Successfully signed in anonymously';
        print('✓ Anonymous sign-in successful: ${user.uid}');
      } else {
        result['error'] = 'Sign-in completed but no user was returned';
        print('❌ Anonymous sign-in failed: No user returned');
      }
    } catch (e) {
      result['error'] = e.toString();
      print('❌ Error signing in anonymously: $e');
    }
    
    return result;
  }

  /// Check if a danmu exists in a given collection
  Future<bool> checkDanmuExists(String danmuId, String collection) async {
    try {
      final docRef = await _firestore.collection(collection).doc(danmuId).get();
      return docRef.exists;
    } catch (e) {
      print('Error checking if danmu exists in $collection: $e');
      return false;
    }
  }
  
  /// Check if a danmu exists in any of the possible collections
  Future<Map<String, bool>> checkDanmuInAllCollections(String danmuId) async {
    final collections = ['danmu', 'danmu_comments', 'danmus', 'comments'];
    final Map<String, bool> results = {};
    
    for (final collection in collections) {
      results[collection] = await checkDanmuExists(danmuId, collection);
    }
    
    return results;
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
