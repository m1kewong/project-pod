import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import for Apple Sign In
import 'dart:io' show Platform;
import 'package:sign_in_with_apple/sign_in_with_apple.dart' show SignInWithApple, AppleIDCredential, AppleIDAuthorizationScopes, SignInWithAppleAuthorizationException;

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isAuthenticated => currentUser != null;
  bool get isAnonymous => currentUser?.isAnonymous ?? false;
  
  // Anonymous sign in
  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      notifyListeners();
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException signing in anonymously: ${e.code} - ${e.message}');
      rethrow;
    } on PlatformException catch (e) {
      print('PlatformException signing in anonymously: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Error signing in anonymously: $e');
      rethrow;
    }
  }
  
  // Email & Password Sign In
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException signing in with email: ${e.code} - ${e.message}');
      rethrow;
    } on PlatformException catch (e) {
      print('PlatformException signing in with email: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Error signing in with email: $e');
      rethrow;
    }
  }
  
  // Email & Password Registration
  Future<User?> registerWithEmail(String email, String password, String displayName) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update user profile
      await userCredential.user?.updateDisplayName(displayName);
      
      // Create user document in Firestore
      await _createUserDocument(userCredential.user!, displayName);
      
      notifyListeners();
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException registering with email: ${e.code} - ${e.message}');
      rethrow;
    } on PlatformException catch (e) {
      print('PlatformException registering with email: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Error registering with email: $e');
      rethrow;
    }
  }
    // Google Sign In
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) return null;
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Check if this is a new user
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _createUserDocument(
          userCredential.user!,
          userCredential.user?.displayName ?? googleUser.displayName ?? 'User',
          photoURL: userCredential.user?.photoURL ?? googleUser.photoUrl,
        );
      }
      
      notifyListeners();
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException signing in with Google: ${e.code} - ${e.message}');
      rethrow;
    } on PlatformException catch (e) {
      print('PlatformException signing in with Google: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }
  // Apple Sign In
  Future<User?> signInWithApple() async {
    // Only available on iOS or macOS
    if (!kIsWeb && !Platform.isIOS && !Platform.isMacOS) {
      throw PlatformException(
        code: 'APPLE_SIGN_IN_NOT_AVAILABLE',
        message: 'Apple Sign In is only available on iOS, macOS, and web platforms',
      );
    }

    try {
      // Request credential for Apple ID
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      
      // Create an OAuthCredential
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      
      // Sign in with Firebase using the Apple credential
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      
      // Apple might not return the user's name every time, only the first time they sign in
      String? displayName = userCredential.user?.displayName;
      
      // If we have the name from the Apple ID credential, use it
      if (displayName == null || displayName.isEmpty) {
        if (appleCredential.givenName != null && appleCredential.familyName != null) {
          displayName = '${appleCredential.givenName} ${appleCredential.familyName}';
          
          // Update user's display name in Firebase if we got it from Apple
          await userCredential.user?.updateDisplayName(displayName);
        }
      }
        // Check if this is a new user
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _createUserDocument(
          userCredential.user!,
          displayName ?? 'Apple User',
          photoURL: userCredential.user?.photoURL,
        );
      }
      
      notifyListeners();
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException signing in with Apple: ${e.code} - ${e.message}');
      rethrow;
    } on SignInWithAppleAuthorizationException catch (e) {
      print('SignInWithAppleAuthorizationException: ${e.code} - ${e.message}');
      rethrow;
    } on PlatformException catch (e) {
      print('PlatformException signing in with Apple: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Error signing in with Apple: $e');
      rethrow;
    }
  }
  
  // Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      notifyListeners();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }
  
  // Update user profile
  Future<void> updateUserProfile({String? displayName, String? photoURL}) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');
      
      // Update Firebase Auth profile
      await user.updateDisplayName(displayName);
      await user.updatePhotoURL(photoURL);
      
      // Update Firestore document
      await _firestore.collection('users').doc(user.uid).update({
        if (displayName != null) 'displayName': displayName,
        if (photoURL != null) 'photoURL': photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      notifyListeners();
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }  // Mock authentication for testing
  Future<User?> signInAsMockUser() async {
    try {
      // Check if we're already using a mock user
      if (currentUser != null && (currentUser!.isAnonymous || currentUser!.email == 'test@example.com')) {
        return currentUser;
      }
      
      try {
        // Attempt to use anonymous auth for testing
        final userCredential = await _auth.signInAnonymously();
        
        // If successful, update display name to mark as test user
        await userCredential.user?.updateDisplayName('Test User');
        
        // Create mock user data
        try {
          await _createUserDocument(userCredential.user!, 'Test User', isMockUser: true);
        } catch (e) {
          print('Error creating user document, but continuing: $e');
        }
        
        notifyListeners();
        return userCredential.user;
      } catch (firebaseError) {
        print('Firebase anonymous auth failed: $firebaseError');
        
        // If Firebase auth fails completely, create a fake local state to allow the app to work
        print('Using completely fake user state for testing');
        
        // We don't actually set Firebase currentUser here since we can't without auth,
        // but we notify listeners so the app can proceed
        notifyListeners();
        return null;
      }
    } catch (e) {
      print('Error signing in as mock user: $e');
      // Create a completely fake user without auth
      notifyListeners();
      return null;
    }
  }
    // Enhanced user document creation
  Future<void> _createUserDocument(User user, String displayName, {bool isMockUser = false, String? photoURL}) async {
    final userData = {
      'uid': user.uid,
      'email': user.email,
      'displayName': displayName,
      'photoURL': photoURL ?? user.photoURL,
      'isAnonymous': user.isAnonymous,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'videoCount': 0,
      'followerCount': 0,
      'followingCount': 0,
      'likeCount': 0,
      'bio': '',
      'website': '',
      'location': '',
      'deviceToken': '',  // For push notifications
      'settings': {
        'notifications': true,
        'darkMode': false,
        'privateAccount': false,
      },
      'accountType': 'standard',  // standard, creator, verified
      'joinDate': FieldValue.serverTimestamp(),
    };
    
    // If this is a mock user, set additional mock-specific fields
    if (isMockUser) {
      userData.addAll({
        'emailVerified': true,
        'mockUser': true,
        'testData': {
          'sampleField': 'sampleValue',
        },
      });
    }
    
    await _firestore.collection('users').doc(user.uid).set(userData);
  }
  
  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }
  
  // Update user's last login timestamp
  Future<void> updateLastLogin(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last login: $e');
    }
  }
}
