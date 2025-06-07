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
  
  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _startPositionTracking();
    
    // Force a danmu test message after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      _createTestDanmu();
    });
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
    final danmuService = DanmuService();
    
    try {
      // Create a test danmu at the current position
      final danmu = await danmuService.createDanmu(
        videoId: testVideoId,
        content: "Test danmu at ${_currentPosition.toStringAsFixed(1)}s",
        timestamp: _currentPosition,
        color: "#FFEB3B", // Yellow
        size: "medium",
        position: "scroll",
        speed: 1.0,
      );
      
      print('Created test danmu: ${danmu?.content}');
    } catch (e) {
      print('Error creating test danmu: $e');
    }
  }
  
  @override
  void dispose() {
    _positionTimer?.cancel();
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
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('弹幕已发送: ${danmu.content}'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
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
