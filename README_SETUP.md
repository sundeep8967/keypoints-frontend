# KeyPoints - iOS Style News App Setup Guide

## Overview
KeyPoints is an iOS-themed news app similar to Inshorts, built with Flutter and Firebase. It features a clean, native iOS design with smooth animations and intuitive navigation.

## Features
- 📱 Native iOS design using Cupertino widgets
- 🔥 Firebase Firestore integration for real-time news data
- 🖼️ Cached network images for optimal performance
- 📰 Card-based news layout similar to Inshorts
- 🔄 Pull-to-refresh functionality
- 📖 Detailed news view with sharing capabilities
- ⏰ Smart timestamp formatting (e.g., "2h ago", "Just now")

## Firebase Setup

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name (e.g., "keypoints-news")
4. Enable Google Analytics (optional)

### 2. Add Android App
1. Click "Add app" → Android
2. Package name: `com.example.keypoints`
3. Download `google-services.json`
4. Replace the placeholder file in `android/app/google-services.json`

### 3. Add iOS App
1. Click "Add app" → iOS
2. Bundle ID: `com.example.keypoints`
3. Download `GoogleService-Info.plist`
4. Replace the placeholder file in `ios/Runner/GoogleService-Info.plist`

### 4. Configure Firestore
1. Go to Firestore Database in Firebase Console
2. Click "Create database"
3. Choose "Start in test mode" (for development)
4. Select a location close to your users

### 5. Add Sample Data
Create a collection called `news` with documents containing:
```json
{
  "title": "Breaking: Flutter 3.0 Released",
  "description": "Google announces Flutter 3.0 with exciting new features including improved performance, better web support, and enhanced developer tools. This release marks a significant milestone in Flutter's evolution.",
  "image": "https://example.com/flutter-news.jpg",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

## Installation Steps

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Configure Firebase (Alternative Method)
If you prefer using FlutterFire CLI:
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure
```

### 3. Update Firebase Configuration
Replace the placeholder values in:
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

### 4. Run the App
```bash
flutter run
```

## Project Structure
```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
├── models/
│   └── news_article.dart     # News article data model
├── services/
│   └── firebase_service.dart # Firebase operations
├── screens/
│   ├── home_screen.dart      # Main news feed
│   └── news_detail_screen.dart # Article detail view
└── widgets/
    └── news_card.dart        # News card component
```

## Firebase Firestore Structure
```
news (collection)
├── document1
│   ├── title: string
│   ├── description: string
│   ├── image: string (URL)
│   └── timestamp: timestamp
├── document2
│   └── ...
```

## Customization

### Colors & Theme
The app uses iOS system colors that automatically adapt to light/dark mode:
- Primary: `CupertinoColors.systemBlue`
- Background: `CupertinoColors.systemGroupedBackground`
- Text: `CupertinoColors.label`

### Adding More Features
- **Search**: Implement search functionality in the navigation bar
- **Categories**: Add news categories with filtering
- **Bookmarks**: Allow users to save articles
- **Push Notifications**: Send breaking news alerts
- **Offline Support**: Cache articles for offline reading

## Troubleshooting

### Common Issues
1. **Firebase not initialized**: Ensure `google-services.json` and `GoogleService-Info.plist` are properly configured
2. **Network images not loading**: Check internet connection and image URLs
3. **Build errors**: Run `flutter clean` and `flutter pub get`

### Performance Tips
- Images are cached automatically using `cached_network_image`
- Use `const` constructors where possible
- Implement pagination for large news lists

## Contributing
Feel free to contribute by:
- Adding new features
- Improving UI/UX
- Fixing bugs
- Adding tests

## License
This project is open source and available under the MIT License.