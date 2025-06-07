import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isFirebaseInitialized = false;
  bool _isChecking = true;
  String _errorMessage = '';
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // Set a timeout to prevent the splash screen from hanging indefinitely
    _timeoutTimer = Timer(Duration(seconds: 10), () {
      if (mounted && _isChecking) {
        setState(() {
          _isChecking = false;
          _errorMessage = 'Firebase initialization timed out. Some features may not work properly.';
        });
      }
    });
    
    try {
      // Check Firebase initialization
      final isInitialized = Firebase.app().options != null;
      
      if (mounted) {
        setState(() {
          _isFirebaseInitialized = isInitialized;
        });
      }
      
      // If firebase is initialized and we're on web, try to validate session from browser
      if (isInitialized && kIsWeb) {
        // In web, check if we have a restored session from the browser
        await _checkExistingSession();
      } else {
        // Not on web or Firebase not initialized, just finish checking
        if (mounted) {
          setState(() {
            _isChecking = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error initializing app: ${e.toString()}';
          _isChecking = false;
        });
      }
    } finally {
      // Cancel the timeout timer if it's still active
      _timeoutTimer?.cancel();
      
      if (mounted && _isChecking) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }
  
  Future<void> _checkExistingSession() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Wait briefly to allow Firebase Auth to restore from browser
      await Future.delayed(Duration(milliseconds: 500));
      
      // Validate the session
      await authService.validateSession();
      
      // Reloading the user will update the emailVerified status if it changed
      await authService.reloadUser();
    } catch (e) {
      print('Error checking existing session: $e');
      // Continue anyway, the user can still sign in manually
    }
  }

  void _continueToApp() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      if (_isFirebaseInitialized) {
        // Double-check session validity first
        if (kIsWeb && authService.currentUser != null) {
          final isSessionValid = await authService.validateSession();
          if (!isSessionValid) {
            // Session is invalid, sign out and go to login
            await authService.signOut();
            if (!mounted) return;
            Navigator.of(context).pushReplacementNamed('/login');
            return;
          }
        }
        
        // Check if user is logged in
        if (authService.isAuthenticated) {
          print('Splash screen: User is authenticated, continuing to home');
          
          // If the user is authenticated but email is not verified, 
          // redirect to login screen which will show the verification UI
          if (authService.currentUser != null && 
              authService.currentUser!.email != null && 
              !authService.currentUser!.emailVerified) {
            print('Splash screen: Email not verified, redirecting to login for verification');
            Navigator.of(context).pushReplacementNamed('/login');
            return;
          }
          
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          print('Splash screen: User is not authenticated, continuing to login');
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } else {
        // If Firebase isn't initialized, show warning but allow continuing to login
        print('Splash screen: Firebase not initialized, continuing to login with limited functionality');
        
        // Show a warning message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firebase not fully initialized. Some features may be limited.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
        
        // Continue to login screen
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      
      // Even if there's an error, try to continue to login
      print('Splash screen: Error during navigation: $_errorMessage');
      Navigator.of(context).pushReplacementNamed('/login');
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
            const SizedBox(height: 24),
            
            // Loading state
            if (_isChecking)
              Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing app...'),
                ],
              ),
              
            const SizedBox(height: 24),
            
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
              onPressed: _isChecking ? null : _continueAsTester,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
              child: const Text('Test Danmu Feature'),
            ),
            
            const SizedBox(height: 16),
            
            // Main app button
            OutlinedButton(
              onPressed: _isChecking ? null : _continueToApp,
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
