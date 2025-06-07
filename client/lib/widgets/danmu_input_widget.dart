import 'package:flutter/material.dart';
import '../services/danmu_service.dart';

class DanmuInputWidget extends StatefulWidget {
  final String videoId;
  final double currentTime;
  final Function(DanmuComment)? onDanmuSent;

  const DanmuInputWidget({
    super.key,
    required this.videoId,
    required this.currentTime,
    this.onDanmuSent,
  });

  @override
  State<DanmuInputWidget> createState() => _DanmuInputWidgetState();
}

class _DanmuInputWidgetState extends State<DanmuInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final DanmuService _danmuService = DanmuService();
  
  // Danmu styling options
  String _selectedColor = '#FFFFFF';
  String _selectedSize = 'medium';
  String _selectedPosition = 'scroll';
  double _selectedSpeed = 1.0;
  bool _isLoading = false;
  bool _showStyleOptions = false;

  // Color options
  final List<DanmuColorOption> _colorOptions = [
    DanmuColorOption('White', '#FFFFFF'),
    DanmuColorOption('Red', '#FF6B6B'),
    DanmuColorOption('Orange', '#FFA726'),
    DanmuColorOption('Yellow', '#FFEB3B'),
    DanmuColorOption('Green', '#66BB6A'),
    DanmuColorOption('Blue', '#42A5F5'),
    DanmuColorOption('Purple', '#AB47BC'),
    DanmuColorOption('Pink', '#EC407A'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }  Future<void> _sendDanmu() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final danmu = await _danmuService.createDanmu(
        videoId: widget.videoId,
        content: content,
        timestamp: widget.currentTime,
        color: _selectedColor,
        size: _selectedSize,
        position: _selectedPosition,
        speed: _selectedSpeed,
      );

      if (danmu != null) {
        _controller.clear();
        widget.onDanmuSent?.call(danmu);
        
        // Force a state refresh to show the new danmu right away
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('弹幕发送成功！'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        throw Exception('Failed to create danmu, please try again');
      }
    } catch (e) {
      print('Error sending danmu: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('发送失败: ${e.toString().contains('Exception:') ? e.toString().split('Exception:')[1] : e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Style options toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '发送弹幕',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  _showStyleOptions ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _showStyleOptions = !_showStyleOptions;
                  });
                },
              ),
            ],
          ),
          
          // Style options panel
          if (_showStyleOptions) ...[
            const SizedBox(height: 16),
            _buildStyleOptions(),
            const SizedBox(height: 16),
          ],
          
          // Input field and send button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: '说点什么...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    counterStyle: TextStyle(color: Colors.grey[400]),
                  ),
                  onSubmitted: (_) => _sendDanmu(),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: _selectedColor == '#FFFFFF' 
                      ? Colors.blue 
                      : _parseColor(_selectedColor),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  onPressed: _isLoading ? null : _sendDanmu,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStyleOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Color selection
        const Text(
          '颜色',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _colorOptions.map((colorOption) {
            final isSelected = _selectedColor == colorOption.value;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedColor = colorOption.value;
                });
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _parseColor(colorOption.value),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.black, size: 16)
                    : null,
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 16),
        
        // Size and position selection
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '大小',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _selectedSize,
                    items: [
                      DropdownMenuItem(value: 'small', child: Text('小')),
                      DropdownMenuItem(value: 'medium', child: Text('中')),
                      DropdownMenuItem(value: 'large', child: Text('大')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSize = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 16),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '位置',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _selectedPosition,
                    items: [
                      DropdownMenuItem(value: 'scroll', child: Text('滚动')),
                      DropdownMenuItem(value: 'top', child: Text('顶部')),
                      DropdownMenuItem(value: 'bottom', child: Text('底部')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedPosition = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Speed selection
        const Text(
          '速度',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('慢', style: TextStyle(color: Colors.grey)),
            Expanded(
              child: Slider(
                value: _selectedSpeed,
                min: 0.5,
                max: 2.0,
                divisions: 3,
                activeColor: _parseColor(_selectedColor),
                onChanged: (value) {
                  setState(() {
                    _selectedSpeed = value;
                  });
                },
              ),
            ),
            const Text('快', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: Colors.grey[800],
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Color _parseColor(String colorHex) {
    try {
      String hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.white;
    }
  }
}

class DanmuColorOption {
  final String name;
  final String value;

  DanmuColorOption(this.name, this.value);
}
