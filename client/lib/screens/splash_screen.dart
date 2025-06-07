import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isFirebaseInitialized = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkFirebaseStatus();
  }

  Future<void> _checkFirebaseStatus() async {
    try {
      // Check Firebase initialization
      final isInitialized = Firebase.app().options != null;
      
      setState(() {
        _isFirebaseInitialized = isInitialized;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }
  
  void _continueToApp() async {
    try {
      if (_isFirebaseInitialized) {
        // Check if user is logged in
        final authService = Provider.of<AuthService>(context, listen: false);
        if (authService.currentUser != null) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } else {
        // If Firebase isn't initialized, just show an error
        setState(() {
          _errorMessage = 'Firebase not initialized. Login unavailable.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }
    void _continueAsTester() async {
    try {
      // First try to sign in as a mock user if possible
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInAsMockUser();
      
      // Navigate to danmu test regardless of auth result
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/danmu_test');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      // Still navigate to danmu test even if authentication fails
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/danmu_test');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo or icon
            const Icon(
              Icons.video_library,
              size: 80,
              color: Colors.indigo,
            ),
            const SizedBox(height: 24),
            const Text(
              'Gen Z Social Video',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error: $_errorMessage',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
              
            const SizedBox(height: 20),
            
            // Test button always available
            ElevatedButton(
              onPressed: _continueAsTester,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
              child: const Text('Test Danmu Feature'),
            ),
            
            const SizedBox(height: 16),
            
            // Main app button
            OutlinedButton(
              onPressed: _continueToApp,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
              child: const Text('Continue to Full App'),
            ),
          ],
        ),
      ),
    );
  }
}
