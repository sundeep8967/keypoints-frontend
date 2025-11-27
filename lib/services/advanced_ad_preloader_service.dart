import 'dart:async';
import 'dart:math';
import '../models/native_ad_model.dart';
import 'admob_service.dart';
import '../utils/app_logger.dart';
/// Advanced ad preloading service that loads ads in background while user reads
class AdvancedAdPreloaderService {
  static final AdvancedAdPreloaderService _instance = AdvancedAdPreloaderService._internal();
  factory AdvancedAdPreloaderService() => _instance;
  AdvancedAdPreloaderService._internal();

  // Ad pool management
  static final List<NativeAdModel> _adPool = [];
  static final Map<String, List<NativeAdModel>> _categoryAdPools = {};
  static bool _isPreloading = false;
  static Timer? _preloadTimer;
  static int _targetPoolSize = 3; // Keep only 3 ads ready (for ~15 articles)
  static int _maxPoolSize = 5; // Maximum ads to keep in memory
  
  // Preloading strategy
  static const Duration _preloadInterval = Duration(seconds: 30); // Check every 30 seconds
  static const Duration _aggressivePreloadInterval = Duration(seconds: 10); // When pool is low
  static const int _minPoolThreshold = 3; // Start aggressive preloading when below this
  
  // User behavior tracking
  static int _articlesReadInSession = 0;
  static DateTime? _lastAdRequest;
  static double _averageReadingSpeed = 45.0; // seconds per article (estimated)

  /// Initialize the advanced preloader
  static Future<void> initialize() async {
    AppLogger.info(' ADVANCED PRELOADER: Initializing...');
    
    // Initialize AdMob first
    await AdMobService.initialize();
    
    // Start background preloading
    _startBackgroundPreloading();
    
    // Preload initial batch
    await _preloadInitialBatch();
    
    AppLogger.success(' ADVANCED PRELOADER: Initialized with ${_adPool.length} ads ready');
  }

  /// Start background preloading timer
  static void _startBackgroundPreloading() {
    _preloadTimer?.cancel();
    
    _preloadTimer = Timer.periodic(_preloadInterval, (timer) {
      _backgroundPreloadCheck();
    });
    
    AppLogger.info(' ADVANCED PRELOADER: Background preloading started');
  }

  /// Preload initial batch of ads (smart loading for typical user behavior)
  static Future<void> _preloadInitialBatch() async {
    AppLogger.info('🧠 SMART PRELOADER: Loading initial batch for ~15 articles...');
    
    try {
      // Load only 2 ads initially (enough for first 10 articles)
      final initialAds = await AdMobService.createMultipleAds(2);
      _adPool.addAll(initialAds);
      
      AppLogger.info('📦 SMART BATCH: Loaded ${initialAds.length} real ads (enough for first 10 articles)');
      
      if (_adPool.length >= _targetPoolSize) {
        AppLogger.success('✅ Initial batch complete, ready for user reading');
        return;
      }
      
      // If we don't have enough real ads, fill with mock ads to ensure smooth experience
      if (_adPool.length < _targetPoolSize) {
        final mockAdsNeeded = _targetPoolSize - _adPool.length;
        AppLogger.log('📱 INITIAL BATCH: Adding $mockAdsNeeded banner fallback ads to reach target');
        
        for (int i = 0; i < mockAdsNeeded; i++) {
          final bannerFallback = await AdMobService.createBannerFallback();
          if (bannerFallback != null) {
            _adPool.add(bannerFallback);
          } else {
            // No mock ads - wait for real ads only
            AppLogger.log('📱 INITIAL BATCH: Banner fallback failed, will wait for real ads instead of showing mock');
          }
        }
        
        AppLogger.log('📱 INITIAL BATCH: Pool now has ${_adPool.length} real ads only');
      }
      
    } catch (e) {
      AppLogger.error(' ADVANCED PRELOADER: Initial batch failed: $e');
      
      // Emergency: Don't create mock ads - better to wait for real ads
      AppLogger.log('🚨 EMERGENCY INIT: Real ads failed, will wait and retry later instead of showing mock ads');
      // Pool remains empty - will retry loading real ads when needed
    }
  }

  /// Background check to maintain ad pool
  static Future<void> _backgroundPreloadCheck() async {
    if (_isPreloading) {
      AppLogger.info(' ADVANCED PRELOADER: Already preloading, skipping...');
      return;
    }

    final currentPoolSize = _adPool.length;
    AppLogger.log('📊 ADVANCED PRELOADER: Pool check - ${currentPoolSize}/${_targetPoolSize} ads');

    // Determine if we need aggressive preloading
    bool needsAggressivePreload = currentPoolSize < _minPoolThreshold;
    
    if (needsAggressivePreload) {
      AppLogger.log('🚨 ADVANCED PRELOADER: Pool critically low! Starting aggressive preload...');
      await _aggressivePreload();
    } else if (currentPoolSize < _targetPoolSize) {
      AppLogger.info(' ADVANCED PRELOADER: Pool below target, gentle preload...');
      await _gentlePreload();
    } else {
      AppLogger.success(' ADVANCED PRELOADER: Pool healthy, no action needed');
    }

    // Clean up expired ads
    _cleanupExpiredAds();
  }

  /// Aggressive preloading when pool is critically low
  static Future<void> _aggressivePreload() async {
    _isPreloading = true;
    
    try {
      final adsNeeded = _targetPoolSize - _adPool.length;
      AppLogger.log('🚨 AGGRESSIVE PRELOAD: Loading $adsNeeded ads quickly...');
      
      // Load in parallel batches for speed
      final futures = <Future<List<NativeAdModel>>>[];
      final batchSize = 2;
      final numBatches = (adsNeeded / batchSize).ceil();
      
      for (int i = 0; i < numBatches; i++) {
        futures.add(AdMobService.createMultipleAds(batchSize));
        
        // Small delay between batch starts
        if (i < numBatches - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      // Wait for all batches
      final results = await Future.wait(futures);
      
      int totalLoaded = 0;
      for (final batch in results) {
        _adPool.addAll(batch);
        totalLoaded += batch.length;
      }
      
      AppLogger.log('🚨 AGGRESSIVE PRELOAD: Loaded $totalLoaded ads (Pool: ${_adPool.length})');
      
    } catch (e) {
      AppLogger.error(' AGGRESSIVE PRELOAD: Failed: $e');
    } finally {
      _isPreloading = false;
    }
  }

  /// Gentle preloading to maintain pool
  static Future<void> _gentlePreload() async {
    _isPreloading = true;
    
    try {
      final adsNeeded = min(3, _targetPoolSize - _adPool.length);
      AppLogger.info(' GENTLE PRELOAD: Loading $adsNeeded ads...');
      
      final newAds = await AdMobService.createMultipleAds(adsNeeded);
      _adPool.addAll(newAds);
      
      AppLogger.info(' GENTLE PRELOAD: Loaded ${newAds.length} ads (Pool: ${_adPool.length})');
      
    } catch (e) {
      AppLogger.error(' GENTLE PRELOAD: Failed: $e');
    } finally {
      _isPreloading = false;
    }
  }

  /// Get ads from the preloaded pool
  static List<NativeAdModel> getPreloadedAds(int count, {String? category}) {
    AppLogger.info(' POOL REQUEST: Getting $count ads from pool (${_adPool.length} available)');
    
    // Track user behavior
    _articlesReadInSession++;
    _lastAdRequest = DateTime.now();
    
    // CRITICAL FIX: Check if ads are actually valid before using them
    final validAds = <NativeAdModel>[];
    final invalidAds = <NativeAdModel>[];
    
    for (final ad in _adPool) {
      if (AdMobService.isAdValid(ad)) {
        validAds.add(ad);
      } else {
        invalidAds.add(ad);
        AppLogger.error(' INVALID AD FOUND: ${ad.id} - ${ad.isLoaded ? "loaded but invalid" : "not loaded"}');
      }
    }
    
    // Remove invalid ads from pool
    for (final invalidAd in invalidAds) {
      _adPool.remove(invalidAd);
      invalidAd.nativeAd?.dispose(); // Handle nullable nativeAd
    }
    
    AppLogger.log('📊 POOL HEALTH: ${validAds.length} valid, ${invalidAds.length} invalid (removed)');
    
    // Get ads to return
    final adsToReturn = validAds.take(count).toList();
    
    // Remove used ads from pool
    for (final ad in adsToReturn) {
      _adPool.remove(ad);
    }
    
    AppLogger.info(' POOL SERVED: Returned ${adsToReturn.length} ads, ${_adPool.length} remaining');
    
    // ALWAYS trigger preload when ads are requested (more aggressive)
    AppLogger.info(' TRIGGERING PRELOAD: After serving ads');
    _triggerImmediatePreload();
    
    return adsToReturn;
  }

  /// Trigger immediate preload when pool is low
  static void _triggerImmediatePreload() {
    // Use shorter interval for aggressive preloading
    _preloadTimer?.cancel();
    _preloadTimer = Timer.periodic(_aggressivePreloadInterval, (timer) {
      _backgroundPreloadCheck();
      
      // Switch back to normal interval once pool is healthy
      if (_adPool.length >= _targetPoolSize) {
        timer.cancel();
        _startBackgroundPreloading();
      }
    });
  }

  /// Predictive preloading based on user reading patterns
  static void predictivePreload() {
    final now = DateTime.now();
    
    // Estimate when user will need next ads
    final estimatedNextAdTime = now.add(Duration(seconds: _averageReadingSpeed.round() * 5));
    
    // If we predict user will need ads soon, preload more aggressively
    if (_lastAdRequest != null) {
      final timeSinceLastRequest = now.difference(_lastAdRequest!).inSeconds;
      
      if (timeSinceLastRequest > _averageReadingSpeed * 3) {
        AppLogger.log('🔮 PREDICTIVE: User reading fast, increasing preload...');
        _targetPoolSize = min(15, _targetPoolSize + 2);
      }
    }
    
    AppLogger.log('🔮 PREDICTIVE: Next ads needed around ${estimatedNextAdTime.toString().substring(11, 19)}');
  }

  /// Clean up expired or invalid ads
  static void _cleanupExpiredAds() {
    final initialCount = _adPool.length;
    _adPool.removeWhere((ad) => !AdMobService.isAdValid(ad));
    
    final removedCount = initialCount - _adPool.length;
    if (removedCount > 0) {
      AppLogger.log('🧹 CLEANUP: Removed $removedCount expired ads (${_adPool.length} remaining)');
    }
  }

  /// Get pool statistics
  static Map<String, dynamic> getPoolStats() {
    return {
      'poolSize': _adPool.length,
      'targetSize': _targetPoolSize,
      'maxSize': _maxPoolSize,
      'isPreloading': _isPreloading,
      'articlesReadInSession': _articlesReadInSession,
      'averageReadingSpeed': _averageReadingSpeed,
      'lastAdRequest': _lastAdRequest?.toIso8601String(),
      'validAds': _adPool.where((ad) => AdMobService.isAdValid(ad)).length,
    };
  }

  /// Adjust pool size based on user behavior
  static void adjustPoolSize({int? newTargetSize, double? newReadingSpeed}) {
    if (newTargetSize != null) {
      _targetPoolSize = newTargetSize.clamp(5, 20);
      AppLogger.log('📊 POOL ADJUSTED: Target size set to $_targetPoolSize');
    }
    
    if (newReadingSpeed != null) {
      _averageReadingSpeed = newReadingSpeed.clamp(10.0, 120.0);
      AppLogger.log('📊 READING SPEED: Adjusted to ${_averageReadingSpeed}s per article');
    }
  }

  /// Dispose and cleanup
  static void dispose() {
    _preloadTimer?.cancel();
    
    // Dispose all ads in pool
    for (final ad in _adPool) {
      ad.nativeAd?.dispose(); // Handle nullable nativeAd
    }
    _adPool.clear();
    
    // Clear category pools
    for (final categoryAds in _categoryAdPools.values) {
      for (final ad in categoryAds) {
        ad.nativeAd?.dispose(); // Handle nullable nativeAd
      }
    }
    _categoryAdPools.clear();
    
    AppLogger.log('🗑️ ADVANCED PRELOADER: Disposed all ads and timers');
  }

  /// Emergency ad request when pool is empty
  static Future<List<NativeAdModel>> emergencyAdRequest(int count) async {
    AppLogger.log('🚨 EMERGENCY: Pool empty! Loading ads immediately...');
    
    try {
      final emergencyAds = await AdMobService.createMultipleAds(count);
      AppLogger.log('🚨 EMERGENCY: Loaded ${emergencyAds.length} real emergency ads');
      
      // Don't fill with mock ads - use only real ads we got
      if (emergencyAds.length < count) {
        final realAdsCount = emergencyAds.length;
        AppLogger.log('🚨 EMERGENCY: Got only $realAdsCount real ads out of $count requested - will use these instead of adding mock ads');
      }
      
      AppLogger.log('🚨 EMERGENCY COMPLETE: Returning ${emergencyAds.length} real ads only');
      return emergencyAds;
    } catch (e) {
      AppLogger.error('🚨 EMERGENCY: Failed to load real ads: $e');
      AppLogger.log('✅ No mock ads created - better user experience without fake ads');
      
      // Return empty list instead of mock ads
      return <NativeAdModel>[];
    }
  }
}