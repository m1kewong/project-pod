# Firebase Configuration

This file serves as a placeholder for Firebase configuration. 

## Setup Instructions

1. Create a Firebase project at https://console.firebase.google.com/
2. Register your Flutter app with Firebase
   - Android package name: com.genzapp.socialvideo
   - iOS bundle ID: com.genzapp.socialvideo
3. Download and add the configuration files:
   - For Android: place `google-services.json` in `android/app/`
   - For iOS: place `GoogleService-Info.plist` in `ios/Runner/`
4. Run `flutterfire configure` to generate the `firebase_options.dart` file

## Firebase Services Used
- Authentication
- Cloud Firestore
- Storage
- Cloud Functions (later)
- Analytics
- Crashlytics

## Security Rules
Remember to set up proper security rules for Firestore and Storage to protect user data.
