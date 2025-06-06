import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
// import 'screens/upload_screen.dart';  // Temporarily commented out due to compilation errors
import 'screens/video_player_screen.dart';
import 'screens/danmu_test_screen.dart';
import 'screens/auth_test_screen.dart';
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
        title: 'Gen Z Social Video',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        initialRoute: '/danmu_test',        routes: {
          '/': (context) => const SplashScreen(),
          '/home': (context) => const HomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/profile': (context) => const ProfileScreen(),
          // '/upload': (context) => const UploadScreen(),  // Temporarily commented out
          '/player': (context) => const VideoPlayerScreen(),
          '/danmu_test': (context) => const DanmuTestScreen(),
          '/auth_test': (context) => const AuthTestScreen(),
        },
      ),
    );
  }
}
