# Client - Flutter Mobile App

This directory contains the Flutter mobile application for the Gen Z Social Video Platform.

## Features

- Cross-platform mobile application for iOS and Android
- Video playback with interactive danmu overlay comments
- User authentication via Firebase Auth
- Content upload and sharing
- User profiles and social features

## Setup

1. Install Flutter SDK: https://flutter.dev/docs/get-started/install
2. Connect Firebase to your Flutter app:
   - Create a Firebase project in the Firebase console
   - Add Android and iOS apps to your Firebase project
   - Download the configuration files
   - Place the files in the respective platform folders

3. Install dependencies:
```bash
flutter pub get
```

4. Run the app:
```bash
flutter run
```

## Project Structure

- `lib/` - Dart source code
  - `models/` - Data models
  - `screens/` - UI screens
  - `services/` - API and backend services
  - `widgets/` - Reusable UI components
  - `utils/` - Utility functions
- `assets/` - Static assets (images, fonts, etc.)
- `android/` - Android-specific files
- `ios/` - iOS-specific files

## Development Guidelines

- Follow Flutter best practices for state management
- Use Firebase services for authentication and data storage
- Implement Material Design guidelines
- Write unit and widget tests for key functionality
