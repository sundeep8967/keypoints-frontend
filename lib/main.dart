import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'utils/app_logger.dart';
import 'screens/news_feed_screen.dart';
import 'screens/language_selection_screen.dart';
import 'services/supabase_service.dart';
import 'services/local_storage_service.dart';
import 'services/ad_integration_service.dart';
import 'services/fcm_service.dart';
import 'config/image_cache_config.dart';
import 'config/memory_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure system navigation theme (lightweight)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  
  // Enable edge-to-edge mode (lightweight)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  // ONLY do critical initialization here - everything else happens after app loads
  // Initialize image cache for better performance (lightweight)
  ImageCacheConfig.initialize();
  
  // Initialize memory optimizations (lightweight)
  MemoryConfig.initialize();
  
  // Start the app immediately - no blocking operations
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
      home: const FastNewsApp(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FastNewsApp extends StatefulWidget {
  const FastNewsApp({super.key});

  @override
  State<FastNewsApp> createState() => _FastNewsAppState();
}

class _FastNewsAppState extends State<FastNewsApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize critical services first, then show UI
    _initializeCriticalServices();
  }

  /// Initialize ONLY critical services (Supabase) before showing UI
  Future<void> _initializeCriticalServices() async {
    try {
      // 🎯 PRIORITY 1: Initialize Supabase ONLY - CRITICAL for data loading
      await SupabaseService.initialize();
      AppLogger.success('🎯 PRIORITY 1: Supabase initialized successfully');
      
      // Mark as initialized so UI can start loading data immediately
      setState(() {
        _isInitialized = true;
      });
      
      // Initialize other services in background by priority
      _initializeOtherServicesInBackground();
      
    } catch (e) {
      AppLogger.error('Critical Supabase initialization error: $e');
      // Still show UI but with error state
      setState(() {
        _isInitialized = true;
      });
    }
  }

  /// Initialize services by PRIORITY in background - FULLY ASYNCHRONOUS
  Future<void> _initializeOtherServicesInBackground() async {
    AppLogger.info('🚀 ASYNC: Starting background services by priority');
    
    // 🎯 PRIORITY-BASED ASYNC INITIALIZATION:
    
    // PRIORITY 2: AdMob - Important for revenue, start immediately
    _initializeAdMobAsync();
    
    // PRIORITY 3: Firebase - Least important, start last
    _initializeFirebaseAsync();
    
    // PRIORITY 4: Other optimizations - Start in parallel
    _initializeImagePreloadingAsync();
    _initializeColorExtractionAsync();
    _initializeFCMAsync();
    
    AppLogger.success('🚀 ASYNC: All background services started by priority');
  }
  
  /// Initialize AdMob completely asynchronously
  void _initializeAdMobAsync() {
    Future.microtask(() async {
      try {
        AppLogger.info('🎯 ASYNC ADS: Starting AdMob initialization...');
        await AdIntegrationService.initialize();
        AppLogger.success('🎯 ASYNC ADS: AdMob ready!');
        
        // Start preloading ads immediately (don't wait)
        _preloadAdsAsync();
        
      } catch (e) {
        AppLogger.error('🎯 ASYNC ADS: AdMob error (continuing anyway): $e');
      }
    });
  }
  
  /// Preload ads asynchronously - never blocks UI
  void _preloadAdsAsync() {
    Future.microtask(() async {
      try {
        AppLogger.info('🎯 ASYNC ADS: Starting ad preloading...');
        
        // Start preloading for multiple categories simultaneously
        final categories = ['All', 'Technology', 'Business', 'Sports', 'Entertainment'];
        
        // Fire all preload requests simultaneously (don't wait for each)
        AdIntegrationService.preloadAdsForCategories(categories);
        AppLogger.success('🎯 ASYNC ADS: Started preloading for all categories!');
        
      } catch (e) {
        AppLogger.error('🎯 ASYNC ADS: Preload error (continuing): $e');
      }
    });
  }
  
  /// Initialize Firebase completely asynchronously - LOWEST PRIORITY
  void _initializeFirebaseAsync() {
    Future.microtask(() async {
      try {
        AppLogger.info('🔥 PRIORITY 3: Starting Firebase initialization...');
        await Firebase.initializeApp();
        AppLogger.success('🔥 PRIORITY 3: Firebase ready!');
        
        // Start FCM after Firebase is ready
        _initializeFCMAsync();
        
      } catch (e) {
        AppLogger.error('🔥 PRIORITY 3: Firebase error (continuing anyway): $e');
      }
    });
  }
  
  /// Initialize FCM completely asynchronously
  void _initializeFCMAsync() {
    Future.microtask(() async {
      try {
        AppLogger.info('🔔 ASYNC FCM: Starting FCM initialization...');
        FCMService.initializeWhenReady();
        AppLogger.success('🔔 ASYNC FCM: FCM started!');
      } catch (e) {
        AppLogger.error('🔔 ASYNC FCM: FCM error (continuing anyway): $e');
      }
    });
  }
  
  /// Initialize image preloading asynchronously
  void _initializeImagePreloadingAsync() {
    Future.microtask(() async {
      try {
        AppLogger.info('🖼️ ASYNC IMAGES: Starting image preloading...');
        // Image preloading will start when articles are available
        AppLogger.success('🖼️ ASYNC IMAGES: Image preloader ready!');
      } catch (e) {
        AppLogger.error('🖼️ ASYNC IMAGES: Image preload error (continuing): $e');
      }
    });
  }
  
  /// Initialize color extraction asynchronously
  void _initializeColorExtractionAsync() {
    Future.microtask(() async {
      try {
        AppLogger.info('🎨 ASYNC COLORS: Starting color extraction...');
        // Color extraction will start when articles are available
        AppLogger.success('🎨 ASYNC COLORS: Color extractor ready!');
      } catch (e) {
        AppLogger.error('🎨 ASYNC COLORS: Color extraction error (continuing): $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 ULTRA FAST: Show news feed immediately, let it handle loading
    // No more splash screen blocking - news feed shows its own smart loading
    if (!_isInitialized) {
      // Show minimal splash for critical services only (~500ms max)
      return const CupertinoPageScaffold(
        backgroundColor: CupertinoColors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoActivityIndicator(
                color: CupertinoColors.white,
                radius: 20,
              ),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return const NewsFeedScreen();
  }
}

// Removed unused MyApp class
