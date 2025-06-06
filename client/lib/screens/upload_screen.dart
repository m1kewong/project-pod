import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/video_upload_service.dart';
import 'dart:io';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  File? _videoFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _errorMessage = '';
  
  final List<String> _categories = [
    'Comedy',
    'Dance',
    'Music',
    'Food',
    'Travel',
    'Sports',
    'Gaming',
    'Education',
    'Pets',
    'Beauty',
    'Fashion',
    'DIY',
  ];
  
  String? _selectedCategory;
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
    Future<void> _pickVideo() async {
    // Show dialog to choose between gallery and file system
    final source = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Video Source'),
          content: const Text('Choose how you want to select your video:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('gallery'),
              child: const Text('Gallery'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('files'),
              child: const Text('Files'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (source == null) return;

    try {
      if (source == 'gallery') {
        final picker = ImagePicker();
        final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
        
        if (pickedFile != null) {
          setState(() {
            _videoFile = File(pickedFile.path);
          });
        }
      } else if (source == 'files') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.video,
          allowMultiple: false,
        );
        
        if (result != null && result.files.single.path != null) {
          setState(() {
            _videoFile = File(result.files.single.path!);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
    Future<void> _uploadVideo() async {
    if (!_formKey.currentState!.validate()) return;
    if (_videoFile == null) {
      setState(() {
        _errorMessage = 'Please select a video to upload';
      });
      return;
    }
    
    setState(() {
      _isUploading = true;
      _errorMessage = '';
      _uploadProgress = 0.0;
    });
    
    try {
      final videoUploadService = VideoUploadService();
      
      // Upload the video with progress tracking
      final videoId = await videoUploadService.uploadVideo(
        videoFile: _videoFile!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        privacy: 'public', // Default to public for now
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );
      
      if (!mounted) return;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video uploaded successfully! ID: $videoId'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Reset the form
      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _videoFile = null;
        _selectedCategory = null;
      });
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Upload failed: ${e.toString()}';
      });
      
      // Show error snackbar as well
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {        _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
      // Redirect to login if not authenticated
    if (!authService.isAuthenticated) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Sign in to upload videos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('Sign In'),
            ),
          ],
        ),
      );
    }
    
    // User is authenticated, show upload form
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Video'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Upload New Video',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
                // Video Picker
              GestureDetector(
                onTap: _isUploading ? null : _pickVideo,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: _videoFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              const Center(
                                child: Icon(
                                  Icons.video_file,
                                  size: 64,
                                  color: Colors.indigo,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8.0),
                                  color: Colors.black54,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _videoFile!.path.split('/').last,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      FutureBuilder<int>(
                                        future: _videoFile!.length(),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData) {
                                            final sizeInMB = snapshot.data! / (1024 * 1024);
                                            return Text(
                                              'Size: ${sizeInMB.toStringAsFixed(1)} MB',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.cloud_upload,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to select a video',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Max size: 100MB',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              
              // Category
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Error Message
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              // Upload Progress
              if (_isUploading)
                Column(
                  children: [
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: 8),
                    Text('Uploading: ${(_uploadProgress * 100).toStringAsFixed(0)}%'),
                    const SizedBox(height: 16),
                  ],
                ),
              
              // Upload Button
              ElevatedButton(
                onPressed: _isUploading ? null : _uploadVideo,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Upload Video'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
