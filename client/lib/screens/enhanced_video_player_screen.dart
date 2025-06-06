import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/danmu_service.dart';
import '../widgets/danmu_overlay_widget.dart';
import '../widgets/danmu_input_widget.dart';

class EnhancedVideoPlayerScreen extends StatefulWidget {
  final String videoId;
  final String? videoUrl;
  final String? title;
  final String? description;
  
  const EnhancedVideoPlayerScreen({
    super.key,
    required this.videoId,
    this.videoUrl,
    this.title,
    this.description,
  });

  @override
  State<EnhancedVideoPlayerScreen> createState() => _EnhancedVideoPlayerScreenState();
}

class _EnhancedVideoPlayerScreenState extends State<EnhancedVideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  String _errorMessage = '';
  bool _showDanmuInput = false;
  
  // Video state tracking
  Timer? _positionTimer;
  double _currentPosition = 0.0;
  double _videoDuration = 0.0;
  bool _isPlaying = false;
  
  // Video metadata
  String? _videoTitle;
  String? _videoDescription;
  Map<String, dynamic>? _videoData;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _loadVideoMetadata();
  }

  Future<void> _loadVideoMetadata() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .get();
      
      if (doc.exists) {
        setState(() {
          _videoData = doc.data();
          _videoTitle = _videoData?['title'] ?? widget.title ?? 'Untitled Video';
          _videoDescription = _videoData?['description'] ?? widget.description ?? '';
        });
      }
    } catch (e) {
      print('Error loading video metadata: $e');
    }
  }
  
  Future<void> _initializePlayer() async {
    try {
      // Use provided URL or fallback to sample video
      final videoUrl = widget.videoUrl ?? 
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      
      _videoPlayerController = VideoPlayerController.network(videoUrl);
      await _videoPlayerController.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: 9 / 16, // Vertical video ratio for mobile
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControls: true,
        customControls: _buildCustomControls(),
      );
      
      // Set up position tracking
      _videoDuration = _videoPlayerController.value.duration.inMilliseconds / 1000.0;
      _startPositionTracking();
      
      // Listen to play/pause state
      _videoPlayerController.addListener(_onVideoStateChanged);
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  void _startPositionTracking() {
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_videoPlayerController.value.isInitialized) {
        final position = _videoPlayerController.value.position.inMilliseconds / 1000.0;
        setState(() {
          _currentPosition = position;
        });
      }
    });
  }

  void _onVideoStateChanged() {
    if (_videoPlayerController.value.isInitialized) {
      final isPlaying = _videoPlayerController.value.isPlaying;
      if (isPlaying != _isPlaying) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    }
  }

  Widget _buildCustomControls() {
    return Stack(
      children: [
        // Default Chewie controls
        const Center(),
        
        // Danmu toggle button
        Positioned(
          top: 16,
          right: 16,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _showDanmuInput = !_showDanmuInput;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    color: _showDanmuInput ? Colors.blue : Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '弹幕',
                    style: TextStyle(
                      color: _showDanmuInput ? Colors.blue : Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _videoPlayerController.removeListener(_onVideoStateChanged);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _onDanmuSent(DanmuComment danmu) {
    // Optional: Show a visual confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('弹幕已发送: ${danmu.content}'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Video Player with Danmu Overlay
            Expanded(
              child: Container(
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Video Player
                    if (_isInitialized)
                      Center(
                        child: AspectRatio(
                          aspectRatio: _videoPlayerController.value.aspectRatio,
                          child: Chewie(controller: _chewieController!),
                        ),
                      )
                    else if (_errorMessage.isNotEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading video',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      
                    // Danmu Overlay
                    if (_isInitialized)
                      DanmuOverlayWidget(
                        videoId: widget.videoId,
                        currentTime: _currentPosition,
                        videoDuration: _videoDuration,
                        videoSize: Size(
                          MediaQuery.of(context).size.width,
                          MediaQuery.of(context).size.width * (16 / 9),
                        ),
                        isPlaying: _isPlaying,
                      ),
                      
                    // Back button
                    Positioned(
                      top: 16,
                      left: 16,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Video Information
            if (_videoData != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                color: Colors.grey[900],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _videoTitle ?? 'Untitled Video',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '@${_videoData!['userId'] ?? 'unknown'}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    if (_videoDescription?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        _videoDescription!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionButton(Icons.favorite_border, 'Like'),
                        _buildActionButton(Icons.comment, 'Comment'),
                        _buildActionButton(Icons.share, 'Share'),
                        _buildActionButton(Icons.bookmark_border, 'Save'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            
            // Danmu Input (slide up from bottom)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _showDanmuInput ? null : 0,
              child: _showDanmuInput
                  ? DanmuInputWidget(
                      videoId: widget.videoId,
                      currentTime: _currentPosition,
                      onDanmuSent: _onDanmuSent,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return InkWell(
          onTap: () {
            // Check authentication for protected actions
            if (!authService.isAuthenticated && 
                (label == 'Like' || label == 'Save' || label == 'Comment')) {
              _showAuthDialog(label);
              return;
            }
            
            // Handle actions
            switch (label) {
              case 'Like':
                _handleLike();
                break;
              case 'Comment':
                setState(() {
                  _showDanmuInput = true;
                });
                break;
              case 'Share':
                _handleShare();
                break;
              case 'Save':
                _handleSave();
                break;
            }
          },
          child: Column(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAuthDialog(String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign in required'),
        content: Text('You need to sign in to $action this video.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login');
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _handleLike() {
    // TODO: Implement like functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('点赞功能开发中...'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _handleShare() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('分享功能开发中...'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _handleSave() {
    // TODO: Implement save functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('收藏功能开发中...'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}
