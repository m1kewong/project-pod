import 'package:flutter/material.dart';
import '../services/video_service.dart';
import 'enhanced_video_player_screen.dart';

class SwipeableVideoPlayerScreen extends StatefulWidget {
  final List<VideoModel> videos;
  final int initialIndex;

  const SwipeableVideoPlayerScreen({
    super.key,
    required this.videos,
    required this.initialIndex,
  });

  @override
  State<SwipeableVideoPlayerScreen> createState() => _SwipeableVideoPlayerScreenState();
}

class _SwipeableVideoPlayerScreenState extends State<SwipeableVideoPlayerScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.videos.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final video = widget.videos[index];
          return Stack(
            children: [
              // Full-screen video player
              EnhancedVideoPlayerScreen(
                videoId: video.id,
                videoUrl: video.videoUrl,
                title: video.title,
                description: video.description,
              ),
              
              // Overlay controls
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 10,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              
              // Video info overlay
              Positioned(
                bottom: 80,
                left: 16,
                right: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${video.user?.username ?? 'unknown'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    if (video.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        video.description,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (video.tags.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        children: video.tags.take(3).map((tag) => Text(
                          '#$tag',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        )).toList(),
                      ),
                  ],
                ),
              ),
              
              // Right side actions
              Positioned(
                bottom: 80,
                right: 16,
                child: Column(
                  children: [
                    _buildActionButton(
                      Icons.favorite,
                      '${_formatCount(video.likeCount)}',
                      () {
                        // TODO: Implement like functionality
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildActionButton(
                      Icons.comment,
                      '${_formatCount(video.commentCount)}',
                      () {
                        // TODO: Show comments overlay
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildActionButton(
                      Icons.share,
                      'Share',
                      () {
                        // TODO: Implement share functionality
                      },
                    ),
                  ],
                ),
              ),
              
              // Scroll indicator
              if (widget.videos.length > 1)
                Positioned(
                  right: 8,
                  top: MediaQuery.of(context).size.height * 0.3,
                  bottom: MediaQuery.of(context).size.height * 0.3,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      heightFactor: 1 / widget.videos.length,
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: EdgeInsets.only(
                          top: (_currentIndex / widget.videos.length) * 
                               (MediaQuery.of(context).size.height * 0.4 - 20),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
