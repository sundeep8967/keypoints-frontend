import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/news_feed_screen.dart';
import 'screens/language_selection_screen.dart';
import 'services/supabase_service.dart';
import 'services/local_storage_service.dart';
import 'services/ad_integration_service.dart';
import 'services/fcm_service.dart';
import 'config/image_cache_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure system navigation theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // White text/icons
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light, // White navigation icons
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  
  // Enable edge-to-edge mode
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );
  
  // Initialize image cache for better performance
  ImageCacheConfig.initialize();
  
  // Initialize Firebase (required for FCM)
  try {
    await Firebase.initializeApp();
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  
  // Initialize Supabase
  try {
    await SupabaseService.initialize();
    print('Supabase initialized successfully');
  } catch (e) {
    print('Supabase initialization error: $e');
  }

  // Initialize AdMob for native ads
  try {
    await AdIntegrationService.initialize();
    print('AdMob initialized successfully');
    
    // Preload ads for popular categories
    AdIntegrationService.preloadAdsForCategories([
      'All', 'Technology', 'Business', 'Sports', 'Entertainment'
    ]);
  } catch (e) {
    print('AdMob initialization error: $e');
  }

  // Firebase initialized for FCM - Supabase used for data storage
  
  runApp(const NewsApp());
}

class NewsApp extends StatelessWidget {
  const NewsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'News',
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.systemBlue,
        scaffoldBackgroundColor: CupertinoColors.transparent,
      ),
      home: const AppInitializer(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _isFirstTime = false;

  @override
  void initState() {
    super.initState();
    _checkFirstTimeSetup();
    
    // Initialize FCM in background after core functionality
    _initializeFCMWhenReady();
  }

  /// Initialize FCM after core app functionality is ready (background task)
  Future<void> _initializeFCMWhenReady() async {
    // Wait for core app to be ready, then initialize FCM
    FCMService.initializeWhenReady();
  }

  Future<void> _checkFirstTimeSetup() async {
    try {
      final isCompleted = await LocalStorageService.isFirstTimeSetupCompleted();
      setState(() {
        _isFirstTime = !isCompleted;
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking first-time setup: $e');
      setState(() {
        _isFirstTime = true; // Default to first-time if error
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CupertinoPageScaffold(
        backgroundColor: CupertinoColors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoActivityIndicator(
                radius: 20,
                color: CupertinoColors.white,
              ),
              SizedBox(height: 16),
              Text(
                'News',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Temporarily skip onboarding - go directly to news feed
    // TODO: Re-enable onboarding flow later
    // if (_isFirstTime) {
    //   return const LanguageSelectionScreen();
    // }

    return const NewsFeedScreen();
  }
}

// Removed unused MyApp class
