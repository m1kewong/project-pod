import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoId;
  
  const VideoPlayerScreen({
    super.key,
    this.videoId = '1', // Default to first video if none provided
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  String _errorMessage = '';
  
  // For danmu comments
  final TextEditingController _commentController = TextEditingController();
  final List<Map<String, dynamic>> _dummyComments = [
    {
      'id': '1',
      'text': 'This is amazing! 😍',
      'username': '@user123',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
      'position': 0.2,
    },
    {
      'id': '2',
      'text': 'LOL so funny',
      'username': '@laughing_girl',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 3)),
      'position': 0.5,
    },
    {
      'id': '3',
      'text': 'Wait, what just happened?',
      'username': '@confused_dude',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 2)),
      'position': 0.7,
    },
    {
      'id': '4',
      'text': '🔥🔥🔥',
      'username': '@fire_emoji',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 1)),
      'position': 0.3,
    },
  ];
  
  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }
  
  Future<void> _initializePlayer() async {
    try {
      // In a real app, we would get the video URL from Firestore or an API
      // For now, we're using a sample video URL
      final videoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      
      _videoPlayerController = VideoPlayerController.network(videoUrl);
      await _videoPlayerController.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: true,
        aspectRatio: 9 / 16, // Vertical video ratio
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControls: true,
      );
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }
  
  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    _commentController.dispose();
    super.dispose();
  }
  
  void _sendComment() {
    if (_commentController.text.trim().isEmpty) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      // Show login prompt
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign in required'),
          content: const Text('You need to sign in to comment.'),
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
      return;
    }
    
    // In a real app, we would send this to Firestore
    // For now, we're just adding it to our dummy list
    setState(() {
      _dummyComments.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'text': _commentController.text,
        'username': '@${authService.currentUser?.displayName ?? 'user'}',
        'timestamp': DateTime.now(),
        'position': _videoPlayerController.value.position.inMilliseconds / 
                   _videoPlayerController.value.duration.inMilliseconds,
      });
      _commentController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Video Player with Danmu Overlay
            AspectRatio(
              aspectRatio: 9 / 16,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Video Player
                  if (_isInitialized)
                    Chewie(controller: _chewieController!)
                  else if (_errorMessage.isNotEmpty)
                    Center(
                      child: Text(
                        'Error: $_errorMessage',
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  else
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                    
                  // Danmu Overlay (would be animated in a real app)
                  if (_isInitialized)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Stack(
                          children: _dummyComments.map((comment) {
                            return Positioned(
                              left: 0,
                              right: 0,
                              top: MediaQuery.of(context).size.height * (comment['position'] as double),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  '${comment['text']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 3.0,
                                        color: Colors.black,
                                        offset: Offset(1.0, 1.0),
                                      ),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
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
            
            // Video Info and Actions
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Video Title',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '@username',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
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
            
            // Comment Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Add a danmu comment...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendComment,
                  ),
                ],
              ),
            ),
            
            // Comments List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _dummyComments.length,
                itemBuilder: (context, index) {
                  final comment = _dummyComments[_dummyComments.length - 1 - index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(comment['username'].substring(1, 2).toUpperCase()),
                    ),
                    title: Text(comment['username']),
                    subtitle: Text(comment['text']),
                    trailing: Text(
                      '${DateTime.now().difference(comment['timestamp']).inMinutes}m ago',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButton(IconData icon, String label) {
    return InkWell(
      onTap: () {
        final authService = Provider.of<AuthService>(context, listen: false);
        
        // Check if user is authenticated for protected actions
        if (!authService.isAuthenticated && 
            (label == 'Like' || label == 'Save' || label == 'Comment')) {
          // Show login prompt
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Sign in required'),
              content: Text('You need to sign in to $label this video.'),
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
          return;
        }
        
        // Perform the action if authenticated or if it's a non-protected action
        if (label == 'Like') {
          // TODO: Implement like functionality
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video liked!')),
          );
        } else if (label == 'Comment') {
          // Focus the comment input field
          FocusScope.of(context).requestFocus(FocusNode());
        } else if (label == 'Share') {
          // TODO: Implement share functionality
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Share dialog would open here')),
          );
        } else if (label == 'Save') {
          // TODO: Implement save functionality
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video saved!')),
          );
        }
      },
      child: Column(
        children: [
          Icon(icon),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}
