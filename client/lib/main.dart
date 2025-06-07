import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/video_player_screen.dart';
import 'screens/enhanced_video_player_screen.dart';
import 'screens/auth_test_screen.dart';
import 'screens/danmu_test_screen.dart';  // Import the new screen
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with error handling for web builds
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Failed to initialize Firebase (this is expected in some development environments): $e');
    // Continue execution anyway for testing purposes
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'Gen Z Social Video',        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,        
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',          routes: {
          '/': (context) => const SplashScreen(),
          '/home': (context) => const HomeScreen(),          '/login': (context) => const LoginScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/upload': (context) => const UploadScreen(),
          // Enhanced player route will be navigated to with parameters:
          // Navigator.pushNamed(context, '/enhanced_player', arguments: {'videoId': 'video_id_here'});
          '/auth_test': (context) => const AuthTestScreen(),
          '/danmu_test': (context) => const DanmuTestScreen(),  // Add the new route
        },
        // Add onGenerateRoute for handling routes with parameters
        onGenerateRoute: (settings) {
          if (settings.name == '/player') {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => VideoPlayerScreen(
                videoId: args?['videoId'] ?? '1',
              ),
            );
          } else if (settings.name == '/enhanced_player') {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => EnhancedVideoPlayerScreen(
                videoId: args?['videoId'] ?? '1',
                videoUrl: args?['videoUrl'],
                title: args?['title'],
                description: args?['description'],
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}
