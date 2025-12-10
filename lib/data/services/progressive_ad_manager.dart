import '../models/native_ad_model.dart';
import 'admob_service.dart';
import '../../core/utils/app_logger.dart';

/// Progressive ad loading manager
/// Strategy: Banner first (instant) → Video upgrade (if available)
class ProgressiveAdManager {
  static final Map<String, NativeAdModel> _adUpgradeMap = {};

  /// Load ad with progressive strategy
  /// Returns banner immediately, upgrades to video in background
  static Future<NativeAdModel?> loadAdProgressive({
    required String adId,
    required Function(NativeAdModel) onUpgrade,
  }) async {
    AppLogger.info('📱 PROGRESSIVE AD LOAD: $adId');
    
    // Step 1: Load banner IMMEDIATELY (instant display)
    final bannerAd = await AdMobService.createBannerFallback();
    if (bannerAd != null) {
      AppLogger.success('⚡ INSTANT BANNER: $adId');
      _adUpgradeMap[adId] = bannerAd;
      
      // Step 2: Try to upgrade to video in background
      _upgradeToVideo(adId, onUpgrade);
      
      return bannerAd;
    }
    
    // Fallback: Try video directly if banner fails
    return await _loadVideoAd(adId);
  }

  /// Upgrade banner to video ad in background
  static Future<void> _upgradeToVideo(
    String adId,
    Function(NativeAdModel) onUpgrade,
  ) async {
    try {
      AppLogger.info('🎬 ATTEMPTING VIDEO UPGRADE: $adId');
      
      // Try to load video ad
      final videoAd = await _loadVideoAd(adId);
      
      if (videoAd != null) {
        // Success! Replace banner with video
        final oldAd = _adUpgradeMap[adId];
        _adUpgradeMap[adId] = videoAd;
        
        // Dispose old banner
        oldAd?.nativeAd?.dispose();
        
        AppLogger.success('✅ UPGRADED TO VIDEO: $adId');
        onUpgrade(videoAd);
      } else {
        AppLogger.info('📱 KEEPING BANNER: Video unavailable for $adId');
      }
    } catch (e) {
      AppLogger.warning('⚠️ VIDEO UPGRADE FAILED: $adId - $e (keeping banner)');
    }
  }

  /// Load video ad
  static Future<NativeAdModel?> _loadVideoAd(String adId) async {
    try {
      // Try to create native video ad
      final videoAd = await AdMobService.createNativeAd();
      
      if (videoAd != null && videoAd.isLoaded) {
        AppLogger.success('🎬 VIDEO AD LOADED: $adId');
        return videoAd;
      }
    } catch (e) {
      AppLogger.error('❌ VIDEO AD FAILED: $adId - $e');
    }
    return null;
  }

  /// Get current ad (might be banner or video)
  static NativeAdModel? getCurrentAd(String adId) {
    return _adUpgradeMap[adId];
  }

  /// Check if ad is video
  static bool isVideoAd(String adId) {
    final ad = _adUpgradeMap[adId];
    // You can add logic to check if it's a video ad
    // For now, we'll assume native ads can be videos
    return ad != null && ad.isLoaded;
  }

  /// Clear ad from map
  static void disposeAd(String adId) {
    final ad = _adUpgradeMap.remove(adId);
    ad?.nativeAd?.dispose();
    AppLogger.info('🗑️ DISPOSED AD: $adId');
  }

  /// Clear all ads
  static void disposeAll() {
    for (final ad in _adUpgradeMap.values) {
      ad.nativeAd?.dispose();
    }
    _adUpgradeMap.clear();
    AppLogger.info('🗑️ DISPOSED ALL PROGRESSIVE ADS');
  }

  /// Get statistics
  static Map<String, dynamic> getStats() {
    return {
      'totalAds': _adUpgradeMap.length,
      'adIds': _adUpgradeMap.keys.toList(),
    };
  }
}
