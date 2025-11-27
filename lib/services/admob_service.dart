import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../models/native_ad_model.dart';

import '../utils/app_logger.dart';
class AdMobService {
  static bool _isInitialized = false;
  static final List<NativeAd> _loadedAds = [];
  static int _adCounter = 0;
  static DateTime? _lastCacheTime;
  static const Duration _cacheExpiration = Duration(hours: 1); // Ads expire after 1 hour

  // Test Ad Unit ID for development (replace with production ID before publishing)
  static const String _testAdUnitId = 'ca-app-pub-3940256099942544/2247696110';
  
  // Production Ad Unit IDs
  static String get _nativeAdUnitId {
    // For release builds, always use production ads
    if (kDebugMode) {
      return _testAdUnitId; // Use test ads only in debug mode
    }
    
    if (Platform.isAndroid) {
      return 'ca-app-pub-1095663786072620/6203650880'; // Your production native ad unit
    } else if (Platform.isIOS) {
      return 'ca-app-pub-1095663786072620/6203650880'; // Your production native ad unit (same for both platforms)
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// Initialize AdMob SDK
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      AppLogger.success(' AdMob initialized successfully');
    } catch (e) {
      AppLogger.error(' AdMob initialization failed: $e');
    }
  }

  /// Create a native ad using NativeAd (following Google's best practices)
  /// Updated for Google Mobile Ads SDK 5.x
  static Future<NativeAdModel?> createNativeAd() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final adId = 'native_ad_${++_adCounter}_${DateTime.now().millisecondsSinceEpoch}';
      AppLogger.info(' Attempting to create native ad: $adId');
      AppLogger.log('📍 Using ad unit: $_nativeAdUnitId');
      
      // Create a completer to handle async loading
      final completer = Completer<NativeAdModel?>();
      bool isCompleted = false;
      
      // Create NativeAd directly (new approach in SDK 5.x)
      final nativeAd = NativeAd(
        adUnitId: _nativeAdUnitId,
        factoryId: 'newsArticleNativeAd', // Register the factory ID
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            AppLogger.success(' Native ad loaded successfully: $adId');
            _loadedAds.add(ad as NativeAd);
            
            if (!isCompleted) {
              isCompleted = true;
              // Create model with placeholder data (real ad content is handled by native factories)
              final model = NativeAdModel(
                id: adId,
                title: 'Sponsored Content',
                description: 'Discover amazing products and services tailored for you.',
                imageUrl: 'https://via.placeholder.com/400x200/4285F4/FFFFFF?text=Ad',
                advertiser: 'Sponsored',
                callToAction: 'Learn More',
                nativeAd: ad as NativeAd,
                isLoaded: true,
              );
              completer.complete(model);
            }
          },
          onAdFailedToLoad: (ad, error) {
            AppLogger.error(' Native ad failed to load: $error');
            // Following Google's warning: don't retry from onAdFailedToLoad to avoid continuous failures
            if (!isCompleted) {
              isCompleted = true;
              completer.complete(null);
            }
          },
          onAdClicked: (ad) {
            AppLogger.log('👆 Native ad clicked: $adId');
          },
          onAdImpression: (ad) {
            AppLogger.log('👁️ Native ad impression: $adId');
          },
        ),
        request: const AdRequest(),
        // Native ad options for customization
        nativeAdOptions: NativeAdOptions(
          // Customize native ad options following Google's recommendations
          adChoicesPlacement: AdChoicesPlacement.topRightCorner,
          mediaAspectRatio: MediaAspectRatio.landscape,
          // Enable video controls for better user experience
          videoOptions: VideoOptions(
            startMuted: true, // Start videos muted for better UX
          ),
        ),
      );

      // Load the ad with timeout to prevent hanging
      nativeAd.load();
      
      // Wait for the ad to load or fail with timeout
      final result = await completer.future.timeout(
        const Duration(seconds: 15), // Reduced timeout for faster fallback
        onTimeout: () {
          AppLogger.log('⏰ Ad loading timed out for $adId');
          AppLogger.log('💡 This is normal in test environments or with poor connectivity');
          nativeAd.dispose(); // Clean up on timeout
          return null;
        },
      );
      
      return result;
    } catch (e) {
      AppLogger.error(' Error creating native ad: $e');
      return null;
    }
  }

  /// Check if cache is expired (following Google's 1-hour recommendation)
  static bool _isCacheExpired() {
    if (_lastCacheTime == null) return true;
    return DateTime.now().difference(_lastCacheTime!) > _cacheExpiration;
  }

  /// Clear expired ads and reload cache
  static void clearExpiredAds() {
    if (_isCacheExpired()) {
      AppLogger.log('🕐 Ad cache expired, clearing ads');
      disposeAllAds();
      _lastCacheTime = DateTime.now();
    }
  }

  /// Dispose of all loaded ads (following Google's resource management guidelines)
  static void disposeAllAds() {
    for (final ad in _loadedAds) {
      ad.dispose();
    }
    _loadedAds.clear();
    _lastCacheTime = null;
    AppLogger.log('🗑️ Disposed all native ads');
  }

  /// Dispose a specific ad (important for memory management)
  static void disposeAd(NativeAd ad) {
    ad.dispose();
    _loadedAds.remove(ad);
    AppLogger.log('🗑️ Disposed native ad');
  }

  /// Check if ads should be shown (frequency control)
  static bool shouldShowAd(int articleIndex) {
    // Show ad every 5th article (starting from index 4)
    return articleIndex > 0 && (articleIndex + 1) % 5 == 0;
  }

  /// Get ad placement positions in a list of articles
  static List<int> getAdPositions(int totalArticles) {
    final positions = <int>[];
    for (int i = 4; i < totalArticles; i += 5) {
      positions.add(i);
    }
    return positions;
  }

  /// Create multiple native ads with smart limits (following Google's best practices)
  static Future<List<NativeAdModel>> createMultipleAds(int count) async {
    // Clear expired ads first
    clearExpiredAds();
    
    final ads = <NativeAdModel>[];
    count = count.clamp(1, 3); // REDUCED: Max 3 ads per request for better performance
    
    AppLogger.info('🧠 SMART LOADING: Loading $count native ads (conservative approach)...');
    
    // Load ads sequentially to avoid overwhelming the system
    // Following Google's guideline: "Don't call loadAd() until the first request finishes"
    for (int i = 0; i < count; i++) {
      try {
        final ad = await createNativeAd();
        if (ad != null) {
          ads.add(ad);
          AppLogger.info(' Successfully loaded ad ${i + 1}/$count');
        } else {
          AppLogger.error(' Failed to load ad ${i + 1}/$count');
          // Following Google's warning: limit ad load retries to avoid continuous failed requests
          if (i == 0) {
            AppLogger.warning(' First ad failed to load, stopping batch to avoid continuous failures');
            break;
          }
        }
        
        // Small delay between ad requests to avoid rate limiting
        if (i < count - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        AppLogger.error(' Error loading ad ${i + 1}/$count: $e');
        // Stop loading more ads if we encounter errors to prevent cascading failures
        break;
      }
    }
    
    // Update cache timestamp
    if (ads.isNotEmpty) {
      _lastCacheTime = DateTime.now();
    }
    
    AppLogger.info(' Successfully created ${ads.length}/$count native ads');
    return ads;
  }

  /// Preload ads for better performance (following Google's caching recommendations)
  static Future<void> preloadAds(int count) async {
    AppLogger.info(' Preloading $count ads for better performance...');
    await createMultipleAds(count);
  }

  /// Get ad loading statistics
  static Map<String, dynamic> getAdLoadingStats() {
    return {
      'totalLoadedAds': _loadedAds.length,
      'isInitialized': _isInitialized,
      'lastCacheTime': _lastCacheTime?.toIso8601String(),
      'cacheExpired': _isCacheExpired(),
      'adCounter': _adCounter,
    };
  }

  /// Validate ad before displaying (following Google's best practices)
  static bool isAdValid(NativeAdModel? adModel) {
    if (adModel == null) return false;
    if (!adModel.isLoaded) return false;
    
    // Check if the underlying native ad is still valid
    try {
      // The ad should still be in our loaded ads list
      return _loadedAds.contains(adModel.nativeAd);
    } catch (e) {
      AppLogger.error(' Error validating ad: $e');
      return false;
    }
  }

  /// Create a banner ad fallback when native ads fail to load
  static Future<NativeAdModel?> createBannerFallback() async {
    AppLogger.log('📱 Creating banner ad fallback for native ad failure');
    
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final fallbackId = 'banner_fallback_${++_adCounter}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Get banner ad unit ID (same logic as native ads)
      final bannerAdUnitId = _getBannerAdUnitId();
      
      final completer = Completer<NativeAdModel?>();
      bool isCompleted = false;
      
      // Create banner ad with medium rectangle size to match native ad dimensions
      final bannerAd = BannerAd(
        adUnitId: bannerAdUnitId,
        size: AdSize.mediumRectangle, // 300x250 - good size for native ad replacement
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            AppLogger.success('📱 Banner fallback ad loaded successfully: $fallbackId');
            
            if (!isCompleted) {
              isCompleted = true;
              final model = NativeAdModel(
                id: fallbackId,
                title: 'Sponsored Content',
                description: 'Discover products and services tailored for you.',
                imageUrl: '',
                advertiser: 'Sponsored',
                callToAction: 'Learn More',
                nativeAd: null,
                bannerAd: ad as BannerAd,
                isLoaded: true,
                isBannerFallback: true,
              );
              completer.complete(model);
            }
          },
          onAdFailedToLoad: (ad, error) {
            AppLogger.error('📱 Banner fallback ad failed to load: $error');
            if (!isCompleted) {
              isCompleted = true;
              completer.complete(null);
            }
          },
          onAdClicked: (ad) {
            AppLogger.log('👆 Banner fallback ad clicked: $fallbackId');
          },
          onAdImpression: (ad) {
            AppLogger.log('👁️ Banner fallback ad impression: $fallbackId');
          },
        ),
      );

      // Load the banner ad
      bannerAd.load();
      
      // Wait for the ad to load with timeout
      final result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.log('⏰ Banner fallback ad loading timed out for $fallbackId');
          bannerAd.dispose();
          return null;
        },
      );
      
      return result;
    } catch (e) {
      AppLogger.error('📱 Error creating banner fallback ad: $e');
      return null;
    }
  }

  /// Get banner ad unit ID (same logic as native ads)
  static String _getBannerAdUnitId() {
    if (kDebugMode) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Test banner ad unit
    }
    
    // Use your production banner ad unit ID
    return 'ca-app-pub-1095663786072620/3038197387';
  }

  /// REMOVED: Mock ad creation - we only show real ads that generate revenue
  // Mock ads have been completely removed to prevent showing fake ads to users

  /// Get troubleshooting information for ad loading issues
  static Map<String, dynamic> getTroubleshootingInfo() {
    return {
      'isInitialized': _isInitialized,
      'adUnitId': _nativeAdUnitId,
      'isTestAdUnit': _nativeAdUnitId == _testAdUnitId,
      'loadedAdsCount': _loadedAds.length,
      'adCounter': _adCounter,
      'cacheExpired': _isCacheExpired(),
      'lastCacheTime': _lastCacheTime?.toIso8601String(),
      'troubleshootingTips': [
        'Ensure device has internet connectivity',
        'Check if test ads are being used (should work in all environments)',
        'Verify AdMob app ID is correct in AndroidManifest.xml',
        'Make sure native ad factory is properly registered',
        'Test ads may not always be available in emulators',
      ],
    };
  }
}