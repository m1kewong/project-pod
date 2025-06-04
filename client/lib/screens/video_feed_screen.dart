import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'video_player_screen.dart';

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final List<Map<String, dynamic>> _dummyVideos = [
    {
      'id': '1',
      'title': 'Amazing Sunset',
      'username': '@sunset_lover',
      'likes': 1254,
      'comments': 87,
      'shares': 42,
      'thumbnailUrl': 'https://picsum.photos/id/1001/400/600',
    },
    {
      'id': '2',
      'title': 'Street Dance Performance',
      'username': '@dance_king',
      'likes': 2548,
      'comments': 154,
      'shares': 89,
      'thumbnailUrl': 'https://picsum.photos/id/1002/400/600',
    },
    {
      'id': '3',
      'title': 'Cat being cute',
      'username': '@cat_lady',
      'likes': 4587,
      'comments': 245,
      'shares': 178,
      'thumbnailUrl': 'https://picsum.photos/id/1003/400/600',
    },
    {
      'id': '4',
      'title': 'Coffee Art Tutorial',
      'username': '@barista_pro',
      'likes': 987,
      'comments': 65,
      'shares': 34,
      'thumbnailUrl': 'https://picsum.photos/id/1004/400/600',
    },
    {
      'id': '5',
      'title': 'Mountain Hiking',
      'username': '@adventure_time',
      'likes': 3254,
      'comments': 134,
      'shares': 98,
      'thumbnailUrl': 'https://picsum.photos/id/1005/400/600',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // TODO: Implement refresh functionality
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView.builder(
        itemCount: _dummyVideos.length,
        itemBuilder: (context, index) {
          final video = _dummyVideos[index];
          return VideoCard(
            video: video,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(videoId: video['id']),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class VideoCard extends StatelessWidget {
  final Map<String, dynamic> video;
  final VoidCallback onTap;

  const VideoCard({
    super.key,
    required this.video,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Thumbnail
            Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Image.network(
                    video['thumbnailUrl'],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.error, color: Colors.red),
                        ),
                      );
                    },
                  ),
                ),
                const Icon(
                  Icons.play_circle_outline,
                  size: 64,
                  color: Colors.white,
                ),
              ],
            ),
            
            // Video Info
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video['title'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video['username'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStat(Icons.favorite, video['likes'].toString()),
                      _buildStat(Icons.comment, video['comments'].toString()),
                      _buildStat(Icons.share, video['shares'].toString()),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStat(IconData icon, String count) {
    return Row(
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(count),
      ],
    );
  }
}
