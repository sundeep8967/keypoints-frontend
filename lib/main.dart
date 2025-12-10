import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/utils/app_logger.dart';
import 'presentation/views/screens/news_feed_screen.dart';
import 'presentation/views/widgets/news_feed_widgets.dart';
import 'data/services/supabase_service.dart';
import 'data/services/ad_integration_service.dart';
import 'data/services/fcm_service.dart';
import 'data/services/streaks_service.dart';
import 'data/services/read_articles_service.dart';
import 'core/config/image_cache_config.dart';
import 'core/config/memory_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure system UI
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
  
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  // Initialize critical configs
  ImageCacheConfig.initialize();
  MemoryConfig.initialize();
  ReadArticlesService.preloadCache();
  
  // Start the app with Riverpod
  runApp(
    const ProviderScope(
      child: NewsApp(),
    ),
  );
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
      home: const _AppInitializer(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Initialize critical services then show NewsFeedScreen
class _AppInitializer extends ConsumerStatefulWidget {
  const _AppInitializer();

  @override
  ConsumerState<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<_AppInitializer> 
    with WidgetsBindingObserver {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCriticalServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  Future<void> _initializeCriticalServices() async {
    try {
      AppLogger.info('⚡ INIT: Starting critical services...');
      
      // Initialize Supabase
      await SupabaseService.initialize();
      AppLogger.success('⚡ SUPABASE: Ready');

      // Start usage tracking
      await StreaksService.instance.startUsageSession();
      AppLogger.success('⚡ STREAKS: Started');
      
      // Mark as initialized - NewsFeedNotifier will handle article loading
      setState(() {
        _isInitialized = true;
      });
      AppLogger.success('⚡ INIT COMPLETE: UI ready');
      
      // Initialize background services
      _initializeBackgroundServices();
      
    } catch (e) {
      AppLogger.error('⚡ INIT ERROR: $e');
      setState(() {
        _isInitialized = true; // Show UI anyway
      });
    }
  }

  void _initializeBackgroundServices() {
    Future.microtask(() async {
      try {
        // Initialize Firebase
        await Firebase.initializeApp();
        AppLogger.success('🔥 FIREBASE: Ready');
        
        // Initialize FCM
        FCMService.initializeWhenReady();
        AppLogger.success('🔔 FCM: Started');
        
        // Initialize ads
        AdIntegrationService.initialize();
        AppLogger.success('📣 ADS: Started');
        
      } catch (e) {
        AppLogger.error('Background services error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.black,
        child: NewsFeedWidgets.buildLoadingPage(),
      );
    }
    
    return const NewsFeedScreen();
  }
}
