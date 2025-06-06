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

  @override
  void initState() {
    super.initState();
    _danmuService = DanmuService();
    _calculateMaxLines();
    _startDanmuStream();
  }

  void _calculateMaxLines() {
    _maxLines = ((widget.videoSize.height - _padding * 2) / _lineHeight).floor();
  }

  void _startDanmuStream() {
    _danmuSubscription = _danmuService
        .streamDanmuForVideo(widget.videoId)
        .listen(_onDanmuUpdate);
  }

  void _onDanmuUpdate(List<DanmuComment> allDanmu) {
    if (!mounted) return;

    // Filter danmu for current time window
    final currentDanmu = _danmuService.filterDanmuByTime(
      videoId: widget.videoId,
      currentTime: widget.currentTime,
      windowSeconds: 8.0, // Show danmu for 8 seconds
    );

    // Update active danmu list
    setState(() {
      _updateActiveDanmu(currentDanmu);
    });
  }

  void _updateActiveDanmu(List<DanmuComment> currentDanmu) {
    // Remove expired danmu
    _activeDanmu.removeWhere((activeDanmu) {
      final isExpired = widget.currentTime > activeDanmu.comment.timestamp + 8.0;
      if (isExpired) {
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

      _activeDanmu.add(activeDanmu);
      _createAnimation(danmu);
    }
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
    final controller = AnimationController(
      duration: Duration(seconds: (8.0 / danmu.speed).round()),
      vsync: this,
    );

    Animation<double> animation;
    
    switch (danmu.position) {
      case 'scroll':
        animation = Tween<double>(
          begin: widget.videoSize.width,
          end: -200.0, // Approximate text width
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.linear,
        ));
        break;
        
      case 'top':
      case 'bottom':
        animation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ));
        break;
        
      default:
        animation = Tween<double>(
          begin: widget.videoSize.width,
          end: -200.0,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.linear,
        ));
    }

    _controllers[danmu.id] = controller;
    _animations[danmu.id] = animation;

    if (widget.isPlaying) {
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
    return SizedBox(
      width: widget.videoSize.width,
      height: widget.videoSize.height,
      child: Stack(
        children: _activeDanmu.map((activeDanmu) {
          final comment = activeDanmu.comment;
          final animation = _animations[comment.id];
          
          if (animation == null) return const SizedBox.shrink();

          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Positioned(
                left: _getLeftPosition(comment, animation.value),
                top: activeDanmu.line * _lineHeight + _padding,
                child: _buildDanmuText(comment),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  double _getLeftPosition(DanmuComment comment, double animationValue) {
    switch (comment.position) {
      case 'scroll':
        return animationValue;
      case 'top':
      case 'bottom':
        return (widget.videoSize.width - 200) / 2; // Center
      default:
        return animationValue;
    }
  }

  Widget _buildDanmuText(DanmuComment comment) {
    final fontSize = _getFontSize(comment.size);
    final color = _parseColor(comment.color);
    
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
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
              blurRadius: 1.0,
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
