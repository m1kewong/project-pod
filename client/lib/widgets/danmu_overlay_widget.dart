import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/danmu_service.dart';

class DanmuOverlayWidget extends StatefulWidget {
  final String videoId;
  final double currentTime;
  final double videoDuration;
  final Size videoSize;
  final bool isPlaying;

  const DanmuOverlayWidget({
    super.key,
    required this.videoId,
    required this.currentTime,
    required this.videoDuration,
    required this.videoSize,
    required this.isPlaying,
  });

  @override
  State<DanmuOverlayWidget> createState() => _DanmuOverlayWidgetState();
}

class _DanmuOverlayWidgetState extends State<DanmuOverlayWidget>
    with TickerProviderStateMixin {
  late DanmuService _danmuService;
  StreamSubscription<List<DanmuComment>>? _danmuSubscription;
  
  // Animation controllers for different danmu
  final Map<String, AnimationController> _controllers = {};
  final Map<String, Animation<double>> _animations = {};
  final List<ActiveDanmu> _activeDanmu = [];
  
  // Layout parameters
  static const double _lineHeight = 30.0;
  static const double _padding = 8.0;
  late int _maxLines;
  double _lastCheckedPosition = -1.0;

  @override
  void initState() {
    super.initState();
    _danmuService = DanmuService();
    _calculateMaxLines();
    _startDanmuStream();
    print('DanmuOverlayWidget initialized with videoId: ${widget.videoId}');
  }

  void _calculateMaxLines() {
    _maxLines = ((widget.videoSize.height - _padding * 2) / _lineHeight).floor();
    print('Max lines calculated: $_maxLines for height: ${widget.videoSize.height}');
  }

  void _startDanmuStream() {
    _danmuSubscription = _danmuService
        .streamDanmuForVideo(widget.videoId)
        .listen(_onDanmuUpdate);
    print('Started danmu stream for video: ${widget.videoId}');
  }

  void _onDanmuUpdate(List<DanmuComment> allDanmu) {
    if (!mounted) return;
    
    print('Received danmu update with ${allDanmu.length} comments');

    // Filter danmu for current time window
    final currentDanmu = _danmuService.filterDanmuByTime(
      videoId: widget.videoId,
      currentTime: widget.currentTime,
      windowSeconds: 8.0, // Show danmu for 8 seconds
    );
    
    print('Filtered to ${currentDanmu.length} comments for current time ${widget.currentTime}');

    // Update active danmu list
    setState(() {
      _updateActiveDanmu(currentDanmu);
    });
  }

  void _updateActiveDanmu(List<DanmuComment> currentDanmu) {
    print('Updating active danmu list. Current: ${_activeDanmu.length}, New: ${currentDanmu.length}');
    
    // Remove expired danmu
    _activeDanmu.removeWhere((activeDanmu) {
      final isExpired = widget.currentTime > activeDanmu.comment.timestamp + 8.0;
      if (isExpired) {
        print('Removing expired danmu: ${activeDanmu.comment.content} at timestamp ${activeDanmu.comment.timestamp}');
        _controllers[activeDanmu.comment.id]?.dispose();
        _controllers.remove(activeDanmu.comment.id);
        _animations.remove(activeDanmu.comment.id);
      }
      return isExpired;
    });

    // Add new danmu
    for (final danmu in currentDanmu) {
      // Check if already active
      if (_activeDanmu.any((active) => active.comment.id == danmu.id)) {
        continue;
      }

      // Create new active danmu
      final line = _findAvailableLine(danmu.position);
      final activeDanmu = ActiveDanmu(
        comment: danmu,
        line: line,
        startTime: widget.currentTime,
      );

      print('Adding new danmu: ${danmu.content} at line $line');
      _activeDanmu.add(activeDanmu);
      _createAnimation(danmu);
    }
    
    print('After update: ${_activeDanmu.length} active danmu');
  }

  int _findAvailableLine(String position) {
    switch (position) {
      case 'top':
        // Find available line in top third
        final topLines = _maxLines ~/ 3;
        for (int i = 0; i < topLines; i++) {
          if (!_activeDanmu.any((active) => active.line == i)) {
            return i;
          }
        }
        return Random().nextInt(topLines);
        
      case 'bottom':
        // Find available line in bottom third
        final bottomStart = (_maxLines * 2) ~/ 3;
        for (int i = bottomStart; i < _maxLines; i++) {
          if (!_activeDanmu.any((active) => active.line == i)) {
            return i;
          }
        }
        return bottomStart + Random().nextInt(_maxLines - bottomStart);
        
      case 'scroll':
      default:
        // Find available line in middle third or any available
        final middleStart = _maxLines ~/ 3;
        final middleEnd = (_maxLines * 2) ~/ 3;
        
        for (int i = middleStart; i < middleEnd; i++) {
          if (!_activeDanmu.any((active) => active.line == i)) {
            return i;
          }
        }
        
        // If no middle lines available, use any available line
        for (int i = 0; i < _maxLines; i++) {
          if (!_activeDanmu.any((active) => active.line == i)) {
            return i;
          }
        }
        
        return Random().nextInt(_maxLines);
    }
  }

  void _createAnimation(DanmuComment danmu) {
    print('Creating animation for danmu: ${danmu.content} with position ${danmu.position}');
    
    final controller = AnimationController(
      duration: Duration(seconds: (8.0 / danmu.speed).round()),
      vsync: this,
    );

    Animation<double> animation;
    
    switch (danmu.position) {
      case 'scroll':
        animation = Tween<double>(
          begin: 0.0,
          end: 1.0, // We'll use this to calculate the actual position
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.linear,
        ));
        break;
        
      case 'top':
      case 'bottom':
        // For top/bottom, animate opacity
        animation = TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: Curves.easeIn)),
            weight: 10.0,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 1.0),
            weight: 80.0,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 0.0)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 10.0,
          ),
        ]).animate(controller);
        break;
        
      default:
        animation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.linear,
        ));
    }

    _controllers[danmu.id] = controller;
    _animations[danmu.id] = animation;

    // Add a listener to force a rebuild and mark as complete when done
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        print('Animation completed for danmu: ${danmu.content}');
        if (mounted) {
          setState(() {
            _activeDanmu.removeWhere((active) => active.comment.id == danmu.id);
            _controllers.remove(danmu.id);
            _animations.remove(danmu.id);
          });
        }
      }
    });

    if (widget.isPlaying) {
      print('Starting animation for danmu: ${danmu.content}');
      controller.forward();
    }
  }

  @override
  void didUpdateWidget(DanmuOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isPlaying != oldWidget.isPlaying) {
      _updateAnimationPlayback();
    }
    
    if (widget.videoSize != oldWidget.videoSize) {
      _calculateMaxLines();
    }
    
    // Check if the video position has changed significantly
    if ((widget.currentTime - _lastCheckedPosition).abs() > 0.5) {
      // More than half a second difference, check for new danmu to display
      print('Position changed significantly: ${_lastCheckedPosition} -> ${widget.currentTime}');
      _lastCheckedPosition = widget.currentTime;
      
      // Filter and update danmu for the new position
      final currentDanmu = _danmuService.filterDanmuByTime(
        videoId: widget.videoId,
        currentTime: widget.currentTime,
        windowSeconds: 8.0,
      );
      
      setState(() {
        _updateActiveDanmu(currentDanmu);
      });
    }
  }

  void _updateAnimationPlayback() {
    for (final controller in _controllers.values) {
      if (widget.isPlaying) {
        controller.forward();
      } else {
        controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _danmuSubscription?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _danmuService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('Building DanmuOverlayWidget with ${_activeDanmu.length} active danmu comments');
    
    return Container(
      width: widget.videoSize.width,
      height: widget.videoSize.height,
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // Debug background to verify overlay area
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.withOpacity(0.2), width: 1),
              ),
            ),
          ),
          
          // Actual danmu comments
          ..._activeDanmu.map((activeDanmu) {
            final comment = activeDanmu.comment;
            final animation = _animations[comment.id];
            
            if (animation == null) {
              print('No animation for danmu: ${comment.id}');
              return const SizedBox.shrink();
            }

            // Debug print for positioning
            print('Positioning danmu: ${comment.content} at line ${activeDanmu.line}, position: ${comment.position}');

            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final left = _getLeftPosition(comment, animation.value);
                final top = activeDanmu.line * _lineHeight + _padding;
                
                print('Danmu position - Left: $left, Top: $top');
                
                return Positioned(
                  left: left,
                  top: top,
                  child: child ?? const SizedBox.shrink(),
                );
              },
              child: _buildDanmuText(comment),
            );
          }).toList(),
          
          // Debug overlay showing stats
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.all(4),
              color: Colors.black.withOpacity(0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Time: ${widget.currentTime.toStringAsFixed(1)}s',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    'Active: ${_activeDanmu.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    'Size: ${widget.videoSize.width.toStringAsFixed(0)}x${widget.videoSize.height.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getLeftPosition(DanmuComment comment, double animationValue) {
    switch (comment.position) {
      case 'scroll':
        return widget.videoSize.width * (1 - animationValue) - 200;
      case 'top':
      case 'bottom':
        return (widget.videoSize.width - 200) / 2; // Center
      default:
        return widget.videoSize.width * (1 - animationValue) - 200;
    }
  }

  Widget _buildDanmuText(DanmuComment comment) {
    final fontSize = _getFontSize(comment.size);
    final color = _parseColor(comment.color);
    
    return Container(
      constraints: BoxConstraints(
        maxWidth: widget.videoSize.width * 0.8, // Limit width to 80% of video width
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        comment.content,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(
              blurRadius: 3.0,
              color: Colors.black,
              offset: Offset(1.0, 1.0),
            ),
            Shadow(
              blurRadius: 2.0,
              color: Colors.black,
              offset: Offset(-1.0, -1.0),
            ),
          ],
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  double _getFontSize(String size) {
    switch (size) {
      case 'small':
        return 12.0;
      case 'large':
        return 18.0;
      case 'medium':
      default:
        return 14.0;
    }
  }

  Color _parseColor(String colorHex) {
    try {
      String hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex'; // Add alpha
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.white; // Default color
    }
  }
}

/// Represents an active danmu comment being displayed
class ActiveDanmu {
  final DanmuComment comment;
  final int line;
  final double startTime;

  ActiveDanmu({
    required this.comment,
    required this.line,
    required this.startTime,
  });
}
