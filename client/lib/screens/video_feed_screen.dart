import 'package:flutter/material.dart';
import '../services/video_service.dart';
import 'swipeable_video_player_screen.dart';

class VideoFeedScreen extends StatefulWidget {
  final String? initialSearchQuery;
  
  const VideoFeedScreen({super.key, this.initialSearchQuery});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final VideoService _videoService = VideoService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  List<VideoModel> _videos = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _errorMessage = '';
  String _sortBy = 'date'; // date, popular, views
  bool _isSearchMode = false;
  String _currentSearchQuery = '';
    @override
  void initState() {
    super.initState();
    _loadVideos();
    _scrollController.addListener(_onScroll);
    
    // Handle initial search query if provided
    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchController.text = widget.initialSearchQuery!;
        _searchVideos(widget.initialSearchQuery!);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreVideos();
    }
  }

  Future<void> _loadVideos({bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      if (refresh) {
        _videos.clear();
        _currentPage = 1;
        _hasMore = true;
      }
    });

    try {
      final response = await _videoService.getVideoFeed(
        page: _currentPage,
        limit: 20,
        sort: _sortBy,
      );

      setState(() {
        if (refresh) {
          _videos = response.videos;
        } else {
          _videos.addAll(response.videos);
        }
        _hasMore = response.pagination.hasMore;
        _currentPage++;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load videos: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      VideoFeedResponse response;
      
      if (_isSearchMode && _currentSearchQuery.isNotEmpty) {
        final searchResponse = await _videoService.searchVideos(
          query: _currentSearchQuery,
          page: _currentPage,
          limit: 20,
        );
        response = VideoFeedResponse(
          videos: searchResponse.videos,
          pagination: searchResponse.pagination,
        );
      } else {
        response = await _videoService.getVideoFeed(
          page: _currentPage,
          limit: 20,
          sort: _sortBy,
        );
      }

      setState(() {
        _videos.addAll(response.videos);
        _hasMore = response.pagination.hasMore;
        _currentPage++;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load more videos: $e')),
      );
    }
  }

  Future<void> _searchVideos(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearchMode = false;
        _currentSearchQuery = '';
      });
      _loadVideos(refresh: true);
      return;
    }

    setState(() {
      _isSearchMode = true;
      _currentSearchQuery = query.trim();
      _isLoading = true;
      _videos.clear();
      _currentPage = 1;
      _hasMore = true;
      _errorMessage = '';
    });

    try {
      final response = await _videoService.searchVideos(
        query: query.trim(),
        page: 1,
        limit: 20,
      );

      setState(() {
        _videos = response.videos;
        _hasMore = response.pagination.hasMore;
        _currentPage = 2;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to search videos: $e';
        _isLoading = false;
      });
    }
  }  void _changeSortOrder(String sortBy) {
    if (_sortBy != sortBy) {
      setState(() {
        _sortBy = sortBy;
      });
      _loadVideos(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search videos...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _searchVideos('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onSubmitted: _searchVideos,
                  onChanged: (value) {
                    setState(() {}); // Update UI for clear button
                  },
                ),
                const SizedBox(height: 12),
                
                // Sort Options
                if (!_isSearchMode) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSortChip('Latest', 'date'),
                      _buildSortChip('Popular', 'popular'),
                      _buildSortChip('Most Viewed', 'views'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Video Feed
          Expanded(
            child: _buildVideoFeed(),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _changeSortOrder(value),
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).primaryColor : null,
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
    );
  }

  Widget _buildVideoFeed() {
    if (_isLoading && _videos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading videos...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty && _videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadVideos(refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSearchMode ? Icons.search_off : Icons.video_library_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _isSearchMode 
                  ? 'No videos found for "$_currentSearchQuery"'
                  : 'No videos available',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadVideos(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _videos.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _videos.length) {
            // Loading indicator at the bottom
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final video = _videos[index];
          return VideoCard(
            video: video,            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SwipeableVideoPlayerScreen(
                    videos: _videos,
                    initialIndex: index,
                  ),
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
  final VideoModel video;
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
                    video.thumbnailUrl,
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
                // Play button overlay
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                // Duration badge
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(video.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Video Info
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    video.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  
                  // Username and upload time
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: video.user?.profilePicture != null
                            ? NetworkImage(video.user!.profilePicture!)
                            : null,
                        child: video.user?.profilePicture == null
                            ? Text(
                                video.user?.displayName.isNotEmpty == true 
                                    ? video.user!.displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@${video.user?.username ?? 'unknown'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _formatTimeAgo(video.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Tags
                  if (video.tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: video.tags.take(3).map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStat(Icons.favorite, _formatCount(video.likeCount)),
                      _buildStat(Icons.comment, _formatCount(video.commentCount)),
                      _buildStat(Icons.visibility, _formatCount(video.viewCount)),
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
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          count,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
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

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
