import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _showForgotPassword = false;
  bool _showEmailVerification = false;
  String _errorMessage = '';
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    // Stop email verification check if running
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.stopEmailVerificationCheck();
    super.dispose();
  }
  
  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = '';
      _showForgotPassword = false;
      _showEmailVerification = false;
    });
  }
  
  void _toggleForgotPassword() {
    setState(() {
      _showForgotPassword = !_showForgotPassword;
      _errorMessage = '';
    });
  }
  
  Future<void> _authenticateWithEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _showEmailVerification = false;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      if (_isLogin) {
        // Login
        final user = await authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
        
        if (!mounted) return;
        
        // Check if email is verified for non-anonymous users
        if (user != null && user.email != null && !user.emailVerified) {
          setState(() {
            _showEmailVerification = true;
            _isLoading = false;
          });
          return;
        }
        
        // Navigate to home screen
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // Register
        final user = await authService.registerWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );
        
        if (!mounted) return;
        
        // Show email verification message
        if (user != null) {
          setState(() {
            _showEmailVerification = true;
            // Start checking for email verification
            authService.startEmailVerificationCheck();
          });
        } else {
          // Navigate to home screen (should not reach here, but just in case)
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = _formatAuthError(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _sendPasswordResetEmail() async {
    if (_emailController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.resetPassword(_emailController.text.trim());
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to ${_emailController.text}'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
      
      // Return to login mode
      setState(() {
        _showForgotPassword = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = _formatAuthError(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _resendVerificationEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.sendEmailVerification();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification email sent to ${_emailController.text}'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
      
      // Start checking for email verification
      authService.startEmailVerificationCheck();
    } catch (e) {
      setState(() {
        _errorMessage = _formatAuthError(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _checkEmailVerification() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final isVerified = await authService.checkEmailVerification();
      
      if (!mounted) return;
      
      if (isVerified) {
        // Email is verified, navigate to home screen
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // Email is not verified yet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email not verified yet. Please check your inbox.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = _formatAuthError(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _authenticateWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      try {
        // Try Google Sign-In first
        await authService.signInWithGoogle();
      } catch (e) {
        // Temporarily fall back to anonymous auth if Google Sign-In fails
        print('Google Sign-In failed, falling back to anonymous: $e');
        
        // Show a snackbar notification about the fallback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Google Sign-In is not configured yet. Using anonymous login as a temporary fallback.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
        
        await authService.signInAnonymously();
      }
      
      if (!mounted) return;
      
      // Navigate to home screen
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
    Future<void> _anonymousBrowsing() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Attempt to sign in anonymously
      print('Login screen: Attempting anonymous sign-in');
      await authService.signInAnonymously();
      
      if (!mounted) return;
      
      // Check if we're actually authenticated (either with real or mock user)
      if (authService.isAnonymous) {
        print('Login screen: Anonymous sign-in successful');
        // Navigate to home screen
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // This should not happen with our updated implementation, but just in case
        print('Login screen: Anonymous sign-in failed silently');
        setState(() {
          _errorMessage = 'Anonymous browsing is currently unavailable. Please try another sign-in method.';
        });
      }
    } catch (e) {
      print('Login screen: Anonymous sign-in error: $e');
      if (mounted) {
        // Show a more user-friendly error message
        setState(() {
          _errorMessage = 'Unable to continue as guest. Please try another sign-in method.';
        });
        
        // Show a snackbar with more details for debugging
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guest login error: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _authenticateWithApple() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInWithApple();
      
      if (!mounted) return;
      
      // Navigate to home screen
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() {
        _errorMessage = _formatAuthError(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Format authentication error messages to be more user-friendly
  String _formatAuthError(String errorMessage) {
    if (errorMessage.contains('user-not-found')) {
      return 'No account found with this email.';
    } else if (errorMessage.contains('wrong-password')) {
      return 'Incorrect password. Please try again.';
    } else if (errorMessage.contains('email-already-in-use')) {
      return 'An account already exists with this email.';
    } else if (errorMessage.contains('weak-password')) {
      return 'Password is too weak. Please use a stronger password.';
    } else if (errorMessage.contains('invalid-email')) {
      return 'The email address is not valid.';
    } else if (errorMessage.contains('APPLE_SIGN_IN_NOT_AVAILABLE')) {
      return 'Apple Sign In is only available on iOS, macOS, and web.';
    } else if (errorMessage.contains('network-request-failed')) {
      return 'Network error. Please check your connection and try again.';
    } else if (errorMessage.contains('too-many-requests')) {
      return 'Too many unsuccessful attempts. Please try again later.';
    } else if (errorMessage.contains('user-disabled')) {
      return 'This account has been disabled. Please contact support.';
    } else if (errorMessage.contains('operation-not-allowed')) {
      return 'This operation is not allowed. Please contact support.';
    } else if (errorMessage.contains('popup-closed-by-user')) {
      return 'The sign-in popup was closed before completing authentication.';
    } else if (errorMessage.contains('popup-blocked')) {
      return 'Sign-in popup was blocked by your browser. Please allow popups for this site.';
    } else if (errorMessage.contains('account-exists-with-different-credential')) {
      return 'An account already exists with the same email but different sign-in credentials.';
    } else {
      return errorMessage;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show email verification UI
    if (_showEmailVerification) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Email Verification'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _showEmailVerification = false;
              });
            },
          ),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mark_email_read,
                    size: 80,
                    color: Colors.blue,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Verify Your Email',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'We\'ve sent a verification email to ${_emailController.text}. Please check your inbox and click the verification link.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 24),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _checkEmailVerification,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('I\'ve Verified My Email'),
                  ),
                  SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _isLoading ? null : _resendVerificationEmail,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Resend Verification Email'),
                  ),
                  SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      // Redirect to login screen
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: const Text('Back to Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    // Show forgot password UI
    if (_showForgotPassword) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Reset Password'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: _toggleForgotPassword,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_reset,
                    size: 64,
                    color: Colors.indigo,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Reset Your Password',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Enter your email address and we\'ll send you a link to reset your password.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendPasswordResetEmail,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Send Reset Link'),
                  ),
                  TextButton(
                    onPressed: _toggleForgotPassword,
                    child: const Text('Back to Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    // Main login/register UI
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App logo or icon
                const Icon(
                  Icons.video_library,
                  size: 64,
                  color: Colors.indigo,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Gen Z Social Video',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                
                // Email/Password Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (!_isLogin) ...[
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Display Name',
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (!_isLogin && value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      if (_isLogin) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _toggleForgotPassword,
                            child: const Text('Forgot Password?'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _authenticateWithEmailPassword,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : Text(_isLogin ? 'Sign In' : 'Register'),
                      ),
                      TextButton(
                        onPressed: _isLoading ? null : _toggleMode,
                        child: Text(_isLogin
                            ? 'Don\'t have an account? Register'
                            : 'Already have an account? Sign In'),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('OR'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Social Sign-in Buttons
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _authenticateWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 24),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _authenticateWithApple,
                  icon: const Icon(Icons.apple, size: 24),
                  label: const Text('Continue with Apple'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Anonymous Browsing
                TextButton(
                  onPressed: _isLoading ? null : _anonymousBrowsing,
                  child: const Text('Continue as Guest'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
