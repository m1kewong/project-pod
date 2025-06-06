import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'video_feed_screen.dart';
import 'profile_screen.dart';
import 'upload_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _pendingSearchQuery;
  
  List<Widget> get _screens => [
    VideoFeedScreen(
      initialSearchQuery: _pendingSearchQuery,
      key: ValueKey(_pendingSearchQuery ?? 'feed'),
    ),
    const UploadScreen(),
    const ProfileScreen(),
  ];
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return AlertDialog(
          title: const Text('Search Videos'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter search query...',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              searchQuery = value;
            },            onSubmitted: (value) {
              Navigator.pop(context);
              if (value.trim().isNotEmpty) {
                // Switch to video feed if not already there
                if (_selectedIndex != 0) {
                  setState(() {
                    _selectedIndex = 0;
                  });
                }
                // Set search query and rebuild video feed
                setState(() {
                  _pendingSearchQuery = value.trim();
                });
              }
            },
          ),
          actions: [            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (searchQuery.trim().isNotEmpty) {
                  // Switch to video feed if not already there
                  if (_selectedIndex != 0) {
                    setState(() {
                      _selectedIndex = 0;
                    });
                  }
                  // Set search query and rebuild video feed
                  setState(() {
                    _pendingSearchQuery = searchQuery.trim();
                  });
                }
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gen Z Video'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // TODO: Implement notifications screen
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'auth_test') {
                Navigator.pushNamed(context, '/auth_test');
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'auth_test',
                  child: Text('Auth Test'),
                ),
              ];
            },
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: (index) {
          // Check if user is authenticated for upload and profile
          if ((index == 1 || index == 2) && !authService.isAuthenticated) {
            // Show login prompt
            _showLoginPrompt(context);
          } else {
            _onItemTapped(index);
          }
        },
      ),
    );
  }
  
  void _showLoginPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign in required'),
        content: const Text('You need to sign in to access this feature.'),
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
}
