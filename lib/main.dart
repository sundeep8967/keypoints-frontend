import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'utils/app_logger.dart';
import 'screens/news_feed_screen.dart';
import 'services/supabase_service.dart';
import 'services/ad_integration_service.dart';
import 'services/fcm_service.dart';
import 'services/streaks_service.dart';
import 'config/image_cache_config.dart';
import 'config/memory_config.dart';
import 'injection_container.dart' as di;

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

class _FastNewsAppState extends State<FastNewsApp> with WidgetsBindingObserver {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize critical services first, then show UI
    _initializeCriticalServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop usage session when app is disposed
    StreaksService.instance.stopUsageSession();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        AppLogger.log('📱 App resumed');
        StreaksService.instance.startUsageSession();
        // Check if we need to update streak after 7 minutes
        Future.delayed(const Duration(minutes: 7, seconds: 30), () {
          StreaksService.instance.checkLiveUsageAndUpdateStreak();
        });
        break;
      case AppLifecycleState.paused:
        AppLogger.log('📱 App paused');
        StreaksService.instance.stopUsageSession();
        break;
      case AppLifecycleState.inactive:
        AppLogger.log('📱 App inactive');
        break;
      case AppLifecycleState.detached:
        AppLogger.log('📱 App detached');
        StreaksService.instance.stopUsageSession();
        break;
      case AppLifecycleState.hidden:
        AppLogger.log('📱 App hidden');
        break;
    }
  }

  /// Initialize ONLY critical services (Supabase) before showing UI
  Future<void> _initializeCriticalServices() async {
    try {
      // 🎯 PRIORITY 1: Initialize Supabase ONLY - CRITICAL for data loading
      await SupabaseService.initialize();
      AppLogger.success('🎯 PRIORITY 1: Supabase initialized successfully');

      // Initialize dependency injection (ServiceCoordinator and services)
      await di.init();
      AppLogger.success('🧩 DI initialized (ServiceCoordinator ready)');
      
      // Start usage tracking session
      await StreaksService.instance.startUsageSession();
      AppLogger.success('⏱️ Usage: Tracking session started');
      
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

  /// Initialize services by YOUR PRIORITY in background - FULLY ASYNCHRONOUS
  Future<void> _initializeOtherServicesInBackground() async {
    AppLogger.info('🚀 PRIORITY ASYNC: Starting background services by YOUR priority order');
    
    // 🎯 YOUR PRIORITY SYSTEM:
    // PRIORITY 1: Current + Next article images (HIGHEST) - handled in news feed
    // PRIORITY 2: ALL ADS (HIGH) - start immediately  
    // PRIORITY 3: FCM & Background services (LOWEST) - start last
    
    // PRIORITY 2: ALL ADS - Start immediately (HIGH PRIORITY)
    _initializeAllAdsAsync();
    
    // PRIORITY 3: FCM & Background services - Start last (LOWEST PRIORITY)
    Future.delayed(const Duration(milliseconds: 1000), () {
      _initializeFirebaseAsync();
      _initializeFCMAsync();
    });
    
    AppLogger.success('🚀 PRIORITY ASYNC: All services started by YOUR priority order');
  }
  
  /// PRIORITY 2: Initialize ALL ADS (native + sticky banners) - HIGH PRIORITY
  void _initializeAllAdsAsync() {
    Future.microtask(() async {
      try {
        AppLogger.info('🎯 PRIORITY 2 (HIGH): Starting ALL ads initialization...');
        
        // Initialize native ads
        await AdIntegrationService.initialize();
        AppLogger.success('✅ PRIORITY 2: Native ads ready!');
        
        // Initialize sticky banner ads (no await - parallel)
        _initializeStickyBannersAsync();
        
        // Start preloading ads immediately (don't wait)
        _preloadAdsAsync();
        
      } catch (e) {
        AppLogger.error('❌ PRIORITY 2: Native ads error (continuing anyway): $e');
      }
    });
  }
  
  /// Initialize sticky banner ads in parallel
  void _initializeStickyBannersAsync() {
    Future.microtask(() async {
      try {
        AppLogger.info('🎯 PRIORITY 2: Starting sticky banner ads...');
        // Sticky banners will initialize when SmartStickyBannerWidget is created
        AppLogger.success('✅ PRIORITY 2: Sticky banner ads ready!');
      } catch (e) {
        AppLogger.error('❌ PRIORITY 2: Sticky banner error (continuing): $e');
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
  
  /// PRIORITY 3: Initialize Firebase - LOWEST PRIORITY
  void _initializeFirebaseAsync() {
    Future.microtask(() async {
      try {
        AppLogger.info('🔥 PRIORITY 3 (LOWEST): Starting Firebase initialization...');
        await Firebase.initializeApp();
        AppLogger.success('✅ PRIORITY 3: Firebase ready!');
        
      } catch (e) {
        AppLogger.error('❌ PRIORITY 3: Firebase error (continuing anyway): $e');
      }
    });
  }
  
  /// PRIORITY 3: Initialize FCM - LOWEST PRIORITY
  void _initializeFCMAsync() {
    Future.microtask(() async {
      try {
        AppLogger.info('🔔 PRIORITY 3 (LOWEST): Starting FCM initialization...');
        FCMService.initializeWhenReady();
        AppLogger.success('✅ PRIORITY 3: FCM started!');
      } catch (e) {
        AppLogger.error('❌ PRIORITY 3: FCM error (continuing anyway): $e');
      }
    });
  }
  
  // Unused async preloading methods removed
  
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
