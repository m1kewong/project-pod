import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../widgets/danmu_overlay_widget.dart';
import '../widgets/danmu_input_widget.dart';
import '../services/danmu_service.dart';

class DanmuTestScreen extends StatefulWidget {
  const DanmuTestScreen({super.key});

  @override
  State<DanmuTestScreen> createState() => _DanmuTestScreenState();
}

class _DanmuTestScreenState extends State<DanmuTestScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _showDanmuInput = false;
  
  // Video state tracking
  Timer? _positionTimer;
  double _currentPosition = 0.0;
  double _videoDuration = 0.0;
  bool _isPlaying = false;
  
  // Sample video ID for testing
  final String testVideoId = 'test_video_123';
  
  // Demo video URL - using a public sample video
  final String demoVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
  
  // Firestore status tracking
  bool _lastFirestoreWriteSuccess = false;
  String _lastFirestoreErrorMessage = "";
  bool _isFirestoreConnected = false;
  Timer? _firestoreConnectivityTimer;
  
  // Service instance for checking status
  final DanmuService _danmuService = DanmuService();
    @override
  void initState() {
    super.initState();
    _initializePlayer();
    _startPositionTracking();
    _startFirestoreConnectivityCheck();
    
    // Force a danmu test message after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      _createTestDanmu();
    });
  }
  
  void _startFirestoreConnectivityCheck() {
    // Do an initial check
    _checkFirestoreConnectivity();
    
    // Set up a periodic check every 30 seconds
    _firestoreConnectivityTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkFirestoreConnectivity();
    });
  }
  
  Future<void> _checkFirestoreConnectivity() async {
    try {
      final result = await _danmuService.checkFirestoreConnectivity();
      setState(() {
        _isFirestoreConnected = result['isConnected'] == true;
      });
      print('Firestore connectivity check: ${_isFirestoreConnected ? 'Connected' : 'Disconnected'}');
    } catch (e) {
      print('Error checking Firestore connectivity: $e');
      setState(() {
        _isFirestoreConnected = false;
      });
    }
  }
  
  void _startPositionTracking() {
    _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_videoPlayerController.value.isInitialized) {
        setState(() {
          _currentPosition = _videoPlayerController.value.position.inMilliseconds / 1000.0;
          _videoDuration = _videoPlayerController.value.duration.inMilliseconds / 1000.0;
          _isPlaying = _videoPlayerController.value.isPlaying;
        });
      }
    });
  }
  
  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.network(demoVideoUrl);
      await _videoPlayerController.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: true,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        placeholder: const Center(child: CircularProgressIndicator()),
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.redAccent,
        ),
      );
      
      setState(() {
        _isInitialized = true;
        _videoDuration = _videoPlayerController.value.duration.inMilliseconds / 1000.0;
      });
    } catch (e) {
      setState(() {
        _isInitialized = false;
      });
      print('Error initializing video player: $e');
    }
  }
    void _createTestDanmu() async {
    try {
      // Create a test danmu at the current position
      final danmu = await _danmuService.createDanmu(
        videoId: testVideoId,
        content: "Test danmu at ${_currentPosition.toStringAsFixed(1)}s",
        timestamp: _currentPosition,
        color: "#FFEB3B", // Yellow
        size: "medium",
        position: "scroll",
        speed: 1.0,
      );
      
      // Get Firestore write status
      _lastFirestoreWriteSuccess = _danmuService.lastFirestoreWriteSuccess;
      _lastFirestoreErrorMessage = _danmuService.lastFirestoreErrorMessage;
      
      print('Created test danmu: ${danmu?.content}');
      print('Firestore write successful: $_lastFirestoreWriteSuccess');
      
      if (_lastFirestoreWriteSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Danmu successfully saved to Firestore!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to save danmu to Firestore: $_lastFirestoreErrorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Error creating test danmu: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating danmu: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
    @override
  void dispose() {
    _positionTimer?.cancel();
    _firestoreConnectivityTimer?.cancel();
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate video size based on the current screen size
    final Size screenSize = MediaQuery.of(context).size;
    final Size videoSize = Size(
      screenSize.width,
      screenSize.width / (_videoPlayerController.value.aspectRatio > 0 
          ? _videoPlayerController.value.aspectRatio 
          : 16/9)
    );
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danmu Test'),
        actions: [
          IconButton(
            icon: Icon(_showDanmuInput ? Icons.close : Icons.chat),
            onPressed: () {
              setState(() {
                _showDanmuInput = !_showDanmuInput;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Video player
                Center(
                  child: _isInitialized
                      ? Chewie(controller: _chewieController!)
                      : const CircularProgressIndicator(),
                ),
                
                // Danmu overlay
                if (_isInitialized)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DanmuOverlayWidget(
                        videoId: testVideoId,
                        currentTime: _currentPosition,
                        videoDuration: _videoDuration,
                        videoSize: videoSize,
                        isPlaying: _isPlaying,
                      ),
                    ),
                  ),
                
                // Video progress indicator
                if (_isInitialized)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 20,
                      color: Colors.black45,
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow, 
                              color: Colors.white,
                              size: 16,
                            ),
                            onPressed: () {
                              if (_isPlaying) {
                                _videoPlayerController.pause();
                              } else {
                                _videoPlayerController.play();
                              }
                            },
                            iconSize: 16,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(maxHeight: 20, maxWidth: 20),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              ),
                              child: Slider(
                                value: _currentPosition.clamp(0, _videoDuration),
                                min: 0,
                                max: _videoDuration > 0 ? _videoDuration : 1,
                                onChanged: (value) {
                                  _videoPlayerController.seekTo(Duration(milliseconds: (value * 1000).toInt()));
                                },
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              '${_formatDuration(_currentPosition)} / ${_formatDuration(_videoDuration)}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                // Danmu test button (separate from the input)
                if (_isInitialized)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: ElevatedButton(
                      onPressed: _createTestDanmu,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('Add Test Danmu'),
                    ),
                  ),
              ],
            ),
          ),
            // Danmu input
          if (_showDanmuInput)
            DanmuInputWidget(
              videoId: testVideoId,
              currentTime: _currentPosition,
              onDanmuSent: (danmu) {
                print('Danmu sent: ${danmu.content}');
                // Update Firestore status
                setState(() {
                  _lastFirestoreWriteSuccess = _danmuService.lastFirestoreWriteSuccess;
                  _lastFirestoreErrorMessage = _danmuService.lastFirestoreErrorMessage;
                });
                
                // Show status message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_lastFirestoreWriteSuccess 
                      ? '✅ 弹幕已发送: ${danmu.content}' 
                      : '⚠️ 弹幕已发送但未保存到数据库'),
                    backgroundColor: _lastFirestoreWriteSuccess ? Colors.green : Colors.orange,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            
          // Debug panel for Firestore status
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[900],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [                Text(
                  'Firestore Debug Info:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 12, 
                      height: 12, 
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isFirestoreConnected ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isFirestoreConnected 
                        ? 'Firestore status: CONNECTED' 
                        : 'Firestore status: DISCONNECTED',
                      style: TextStyle(
                        color: _isFirestoreConnected ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 12, 
                      height: 12, 
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _lastFirestoreWriteSuccess ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _lastFirestoreWriteSuccess 
                        ? 'Last write: SUCCESS' 
                        : 'Last write: FAILED',
                      style: TextStyle(
                        color: _lastFirestoreWriteSuccess ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                if (!_lastFirestoreWriteSuccess && _lastFirestoreErrorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Error: $_lastFirestoreErrorMessage',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: _createTestDanmu,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('Add Test Danmu'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          final lastDanmuId = _danmuService.lastDanmuId;
                          if (lastDanmuId != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Checking Firestore collections...'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                              // Check in all collections
                            final results = await _danmuService.checkDanmuInAllCollections(lastDanmuId);
                            bool foundInAnyCollection = results.values.contains(true);
                            
                            if (foundInAnyCollection) {
                              // Find which collection it was found in
                              final foundCollection = results.entries
                                  .firstWhere((entry) => entry.value, orElse: () => const MapEntry('', false))
                                  .key;
                                  
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ Found danmu in "$foundCollection" collection'),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('❌ Danmu not found in any collection'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No danmu ID available to check'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          print('Error checking Firestore: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('Verify in Firestore'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Running Firestore connectivity check...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          
                          final result = await _danmuService.checkFirestoreConnectivity();
                          
                          // Show detailed results
                          if (result['isConnected'] == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('✅ Firestore connection successful'),
                                    Text('Auth: ${result['authStatus']}'),
                                    Text('Collections: ${(result['collections'] as List).join(', ')}'),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('❌ Firestore connection failed'),
                                    Text('Auth: ${result['authStatus']}'),
                                    Text('Error: ${result['error']}'),
                                  ],
                                ),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        } catch (e) {
                          print('Error checking Firestore connectivity: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error checking connectivity: $e'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('Check Connectivity'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Testing Firestore permissions...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          
                          final permissionResult = await _danmuService.testFirestorePermissions();
                          
                          if (permissionResult['success'] == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('✅ Firestore permissions verified!'),
                                    Text('Working collection: ${permissionResult['collection']}'),
                                    Text('Auth status: ${permissionResult['authStatus']}'),
                                    Text('User ID: ${permissionResult['userId']}'),
                                    Text('Anonymous: ${permissionResult['isAnonymous']}'),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('❌ Firestore permission test failed'),
                                    Text('Error code: ${permissionResult['errorCode']}'),
                                    Text('Auth status: ${permissionResult['authStatus']}'),
                                    Text('Details: ${permissionResult['error']}'),
                                  ],
                                ),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        } catch (e) {
                          print('Error during permission test: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error testing permissions: $e'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('Test Permissions'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),                ElevatedButton(
                  onPressed: () async {
                    try {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Testing write to public collection...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      
                      final success = await _danmuService.createPublicTestDocument(testVideoId);
                      
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Successfully wrote to a public collection!'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ Failed to write to any public collection: ${_danmuService.lastFirestoreErrorMessage}'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    } catch (e) {
                      print('Error testing public collection: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error testing public collection: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('Test Public Collection Write'),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Checking authentication status...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          
                          final canWrite = await _danmuService.canWriteWithCurrentAuth();
                          
                          if (canWrite) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Current auth status allows Firestore writes'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('❌ Current auth status DOES NOT allow Firestore writes. Check console for details.'),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 5),
                              ),
                            );
                          }
                        } catch (e) {
                          print('Error checking auth status: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error checking auth status: $e'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('Check Auth Write Permission'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Listing all danmu in all collections...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      
                      final allDanmu = await _danmuService.listAllDanmuForVideo(testVideoId);
                      
                      // Format results for display
                      final buffer = StringBuffer();
                      bool anyFound = false;
                      
                      allDanmu.forEach((collection, danmuList) {
                        buffer.write('$collection: ${danmuList.length} danmu\n');
                        
                        if (danmuList.isNotEmpty) {
                          anyFound = true;
                          danmuList.forEach((danmu) {
                            buffer.write('  - ${danmu['content']} (${danmu['timestamp']}s)\n');
                          });
                        }
                      });
                      
                      if (anyFound) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('All Danmu'),
                            content: SingleChildScrollView(
                              child: Text(buffer.toString()),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No danmu found in any collection'),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    } catch (e) {
                      print('Error listing all danmu: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error listing all danmu: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('List All Danmu'),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Diagnosing Firestore initialization...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          
                          final diagResult = await _danmuService.diagnoseFirestoreInitialization();
                          
                          if (diagResult['initialized'] == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('✅ Firebase correctly initialized'),
                                    Text('Auth: ${diagResult['authInitialized'] ? 'OK' : 'FAILED'}'),
                                    Text('Firestore: ${diagResult['firestoreInitialized'] ? 'OK' : 'FAILED'}'),
                                    Text('User ID: ${diagResult['userId']}'),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          } else {
                            // Build error details
                            final errorDetails = StringBuffer();
                            if (diagResult['authInitialized'] == false) {
                              errorDetails.write('Auth error: ${diagResult['authError']}\n');
                            }
                            if (diagResult['firestoreInitialized'] == false) {
                              errorDetails.write('Firestore error: ${diagResult['firestoreError']}\n');
                            }
                            
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Firebase Initialization Issues'),
                                content: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('❌ Firebase initialization issues detected:', 
                                        style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text('Auth initialized: ${diagResult['authInitialized'] ? 'Yes' : 'No'}'),
                                      Text('Firestore initialized: ${diagResult['firestoreInitialized'] ? 'Yes' : 'No'}'),
                                      const SizedBox(height: 8),
                                      const Text('Error details:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text(errorDetails.toString()),
                                      const SizedBox(height: 8),
                                      const Text('Available collections:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text(diagResult['sampleCollections'].join('\n')),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          }
                        } catch (e) {
                          print('Error during Firebase diagnosis: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error during diagnosis: $e'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('Diagnose Firebase Initialization'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Signing in anonymously...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          
                          final result = await _danmuService.signInAnonymously();
                          
                          if (result['success'] == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✅ ${result['message']} (ID: ${result['userId']})'),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                            
                            // After signing in, try to test write permissions
                            await Future.delayed(const Duration(seconds: 1));
                            final canWrite = await _danmuService.canWriteWithCurrentAuth();
                            
                            if (canWrite) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Anonymous auth allows Firestore writes'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('⚠️ Anonymous auth DOES NOT allow Firestore writes'),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('❌ Failed to sign in: ${result['error']}'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        } catch (e) {
                          print('Error signing in: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error signing in: $e'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('Sign In Anonymously'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Format duration as mm:ss
  String _formatDuration(double seconds) {
    final Duration duration = Duration(milliseconds: (seconds * 1000).toInt());
    final int minutes = duration.inMinutes;
    final int remainingSeconds = duration.inSeconds - minutes * 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
