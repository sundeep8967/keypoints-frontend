import 'dart:async';
import 'dart:math';
import '../models/native_ad_model.dart';
import 'admob_service.dart';
import 'ad_debug_service.dart';

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
  static int _targetPoolSize = 10; // Keep 10 ads ready at all times
  static int _maxPoolSize = 15; // Maximum ads to keep in memory
  
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
    print('🚀 ADVANCED PRELOADER: Initializing...');
    
    // Initialize AdMob first
    await AdMobService.initialize();
    
    // Start background preloading
    _startBackgroundPreloading();
    
    // Preload initial batch
    await _preloadInitialBatch();
    
    print('✅ ADVANCED PRELOADER: Initialized with ${_adPool.length} ads ready');
  }

  /// Start background preloading timer
  static void _startBackgroundPreloading() {
    _preloadTimer?.cancel();
    
    _preloadTimer = Timer.periodic(_preloadInterval, (timer) {
      _backgroundPreloadCheck();
    });
    
    print('🔄 ADVANCED PRELOADER: Background preloading started');
  }

  /// Preload initial batch of ads
  static Future<void> _preloadInitialBatch() async {
    print('📱 ADVANCED PRELOADER: Loading initial batch...');
    
    try {
      // Load ads in small batches to avoid overwhelming the system
      for (int batch = 0; batch < 3; batch++) {
        final batchAds = await AdMobService.createMultipleAds(3);
        _adPool.addAll(batchAds);
        
        print('📱 BATCH $batch: Loaded ${batchAds.length} real ads (Total: ${_adPool.length})');
        
        // Small delay between batches
        await Future.delayed(const Duration(milliseconds: 1500));
        
        if (_adPool.length >= _targetPoolSize) break;
      }
      
      // If we don't have enough real ads, fill with mock ads to ensure smooth experience
      if (_adPool.length < _targetPoolSize) {
        final mockAdsNeeded = _targetPoolSize - _adPool.length;
        print('🎭 INITIAL BATCH: Adding $mockAdsNeeded mock ads to reach target');
        
        for (int i = 0; i < mockAdsNeeded; i++) {
          final mockAd = AdMobService.createMockAd();
          if (mockAd != null) {
            _adPool.add(mockAd);
          }
        }
        
        print('🎭 INITIAL BATCH: Pool now has ${_adPool.length} ads (real + mock)');
      }
      
    } catch (e) {
      print('❌ ADVANCED PRELOADER: Initial batch failed: $e');
      
      // Emergency: Create all mock ads if real ads completely fail
      print('🎭 EMERGENCY INIT: Creating all mock ads for initial batch');
      for (int i = 0; i < _targetPoolSize; i++) {
        final mockAd = AdMobService.createMockAd();
        if (mockAd != null) {
          _adPool.add(mockAd);
        }
      }
      print('🎭 EMERGENCY INIT: Created ${_adPool.length} mock ads');
    }
  }

  /// Background check to maintain ad pool
  static Future<void> _backgroundPreloadCheck() async {
    if (_isPreloading) {
      print('🔄 ADVANCED PRELOADER: Already preloading, skipping...');
      return;
    }

    final currentPoolSize = _adPool.length;
    print('📊 ADVANCED PRELOADER: Pool check - ${currentPoolSize}/${_targetPoolSize} ads');

    // Determine if we need aggressive preloading
    bool needsAggressivePreload = currentPoolSize < _minPoolThreshold;
    
    if (needsAggressivePreload) {
      print('🚨 ADVANCED PRELOADER: Pool critically low! Starting aggressive preload...');
      await _aggressivePreload();
    } else if (currentPoolSize < _targetPoolSize) {
      print('🔄 ADVANCED PRELOADER: Pool below target, gentle preload...');
      await _gentlePreload();
    } else {
      print('✅ ADVANCED PRELOADER: Pool healthy, no action needed');
    }

    // Clean up expired ads
    _cleanupExpiredAds();
  }

  /// Aggressive preloading when pool is critically low
  static Future<void> _aggressivePreload() async {
    _isPreloading = true;
    
    try {
      final adsNeeded = _targetPoolSize - _adPool.length;
      print('🚨 AGGRESSIVE PRELOAD: Loading $adsNeeded ads quickly...');
      
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
      
      print('🚨 AGGRESSIVE PRELOAD: Loaded $totalLoaded ads (Pool: ${_adPool.length})');
      
    } catch (e) {
      print('❌ AGGRESSIVE PRELOAD: Failed: $e');
    } finally {
      _isPreloading = false;
    }
  }

  /// Gentle preloading to maintain pool
  static Future<void> _gentlePreload() async {
    _isPreloading = true;
    
    try {
      final adsNeeded = min(3, _targetPoolSize - _adPool.length);
      print('🔄 GENTLE PRELOAD: Loading $adsNeeded ads...');
      
      final newAds = await AdMobService.createMultipleAds(adsNeeded);
      _adPool.addAll(newAds);
      
      print('🔄 GENTLE PRELOAD: Loaded ${newAds.length} ads (Pool: ${_adPool.length})');
      
    } catch (e) {
      print('❌ GENTLE PRELOAD: Failed: $e');
    } finally {
      _isPreloading = false;
    }
  }

  /// Get ads from the preloaded pool
  static List<NativeAdModel> getPreloadedAds(int count, {String? category}) {
    print('📱 POOL REQUEST: Getting $count ads from pool (${_adPool.length} available)');
    
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
        print('❌ INVALID AD FOUND: ${ad.id} - ${ad.isLoaded ? "loaded but invalid" : "not loaded"}');
      }
    }
    
    // Remove invalid ads from pool
    for (final invalidAd in invalidAds) {
      _adPool.remove(invalidAd);
      invalidAd.nativeAd?.dispose(); // Handle nullable nativeAd
    }
    
    print('📊 POOL HEALTH: ${validAds.length} valid, ${invalidAds.length} invalid (removed)');
    
    // Get ads to return
    final adsToReturn = validAds.take(count).toList();
    
    // Remove used ads from pool
    for (final ad in adsToReturn) {
      _adPool.remove(ad);
    }
    
    print('📱 POOL SERVED: Returned ${adsToReturn.length} ads, ${_adPool.length} remaining');
    
    // ALWAYS trigger preload when ads are requested (more aggressive)
    print('🔄 TRIGGERING PRELOAD: After serving ads');
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
        print('🔮 PREDICTIVE: User reading fast, increasing preload...');
        _targetPoolSize = min(15, _targetPoolSize + 2);
      }
    }
    
    print('🔮 PREDICTIVE: Next ads needed around ${estimatedNextAdTime.toString().substring(11, 19)}');
  }

  /// Clean up expired or invalid ads
  static void _cleanupExpiredAds() {
    final initialCount = _adPool.length;
    _adPool.removeWhere((ad) => !AdMobService.isAdValid(ad));
    
    final removedCount = initialCount - _adPool.length;
    if (removedCount > 0) {
      print('🧹 CLEANUP: Removed $removedCount expired ads (${_adPool.length} remaining)');
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
      print('📊 POOL ADJUSTED: Target size set to $_targetPoolSize');
    }
    
    if (newReadingSpeed != null) {
      _averageReadingSpeed = newReadingSpeed.clamp(10.0, 120.0);
      print('📊 READING SPEED: Adjusted to ${_averageReadingSpeed}s per article');
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
    
    print('🗑️ ADVANCED PRELOADER: Disposed all ads and timers');
  }

  /// Emergency ad request when pool is empty
  static Future<List<NativeAdModel>> emergencyAdRequest(int count) async {
    print('🚨 EMERGENCY: Pool empty! Loading ads immediately...');
    
    try {
      final emergencyAds = await AdMobService.createMultipleAds(count);
      print('🚨 EMERGENCY: Loaded ${emergencyAds.length} real emergency ads');
      
      // If we got some ads but not enough, fill with mock ads
      if (emergencyAds.length < count) {
        final mockAdsNeeded = count - emergencyAds.length;
        print('🎭 EMERGENCY FALLBACK: Creating $mockAdsNeeded mock ads');
        
        for (int i = 0; i < mockAdsNeeded; i++) {
          final mockAd = AdMobService.createMockAd();
          if (mockAd != null) {
            emergencyAds.add(mockAd);
          }
        }
      }
      
      print('🚨 EMERGENCY COMPLETE: Returning ${emergencyAds.length} total ads (real + mock)');
      return emergencyAds;
    } catch (e) {
      print('❌ EMERGENCY: Failed to load real ads: $e');
      print('🎭 EMERGENCY FALLBACK: Creating $count mock ads');
      
      // Create all mock ads as fallback
      final mockAds = <NativeAdModel>[];
      for (int i = 0; i < count; i++) {
        final mockAd = AdMobService.createMockAd();
        if (mockAd != null) {
          mockAds.add(mockAd);
        }
      }
      
      print('🎭 EMERGENCY FALLBACK COMPLETE: Created ${mockAds.length} mock ads');
      return mockAds;
    }
  }
}