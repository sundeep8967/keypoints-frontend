import '../../data/models/native_ad_model.dart';

/// Repository interface for ad management
/// Provides clean abstraction over ad loading and lifecycle
abstract class IAdRepository {
  /// Get a native ad (image or video)
  Future<NativeAdModel?> getNativeAd();
  
  /// Get a banner ad as fallback
  Future<NativeAdModel?> getBannerAd();
  
  /// Preload ads for a specific category
  Future<void> preloadAdsForCategory(String category);
  
  /// Preload ads for multiple categories
  Future<void> preloadAdsForCategories(List<String> categories);
  
  /// Dispose of an ad by ID
  void disposeAd(String adId);
  
  /// Initialize ad services
  Future<void> initialize();
}
