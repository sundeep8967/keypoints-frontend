import '../models/news_article.dart';
import '../models/native_ad_model.dart';
import 'admob_service.dart';
import 'ad_debug_service.dart';

/// Service to seamlessly integrate native ads into news feed
class AdIntegrationService {
  static const int _adFrequency = 5; // Show ad every 5th position
  static final Map<String, List<NativeAdModel>> _categoryAds = {};
  static bool _isInitialized = false;

  /// Initialize ad integration
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    await AdMobService.initialize();
    _isInitialized = true;
    print('✅ Ad Integration Service initialized');
  }

  /// Mix ads into a list of news articles
  static Future<List<dynamic>> integrateAdsIntoFeed({
    required List<NewsArticle> articles,
    required String category,
    int maxAds = 3,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Calculate how many ads we need
    final adPositions = AdMobService.getAdPositions(articles.length);
    final adsNeeded = adPositions.length.clamp(0, maxAds);
    
    if (adsNeeded == 0) {
      print('📰 No ads needed for ${articles.length} articles');
      return articles;
    }

    // Get or create ads for this category
    final ads = await _getAdsForCategory(category, adsNeeded);
    
    // Create mixed feed
    final mixedFeed = <dynamic>[];
    int adIndex = 0;
    
    for (int i = 0; i < articles.length; i++) {
      // Add the article
      mixedFeed.add(articles[i]);
      
      // Check if we should add an ad after this article
      if (adPositions.contains(i) && adIndex < ads.length) {
        mixedFeed.add(ads[adIndex]);
        adIndex++;
        print('📱 Inserted ad at position ${mixedFeed.length - 1}');
      }
    }
    
    print('📰 Mixed feed created: ${articles.length} articles + ${adIndex} ads = ${mixedFeed.length} items');
    return mixedFeed;
  }

  /// Get ads for a specific category (with caching)
  static Future<List<NativeAdModel>> _getAdsForCategory(String category, int count) async {
    // Check if we have cached ads for this category
    if (_categoryAds.containsKey(category) && _categoryAds[category]!.length >= count) {
      print('📱 Using cached ads for $category');
      return _categoryAds[category]!.take(count).toList();
    }

    // Create new ads
    print('📱 Creating $count new ads for $category');
    final newAds = await AdMobService.createMultipleAds(count);
    
    // Debug logging if no ads were loaded
    if (newAds.isEmpty) {
      print('⚠️ No ads loaded for category: $category');
      print('🔍 Running ad debug analysis...');
      AdDebugService.printDebugInfo();
    }
    
    // Cache the ads
    _categoryAds[category] = newAds;
    
    return newAds;
  }

  /// Check if an item in the mixed feed is an ad
  static bool isAd(dynamic item) {
    return item is NativeAdModel;
  }

  /// Check if an item in the mixed feed is a news article
  static bool isNewsArticle(dynamic item) {
    return item is NewsArticle;
  }

  /// Get the type of item for debugging
  static String getItemType(dynamic item) {
    if (isAd(item)) return 'AD';
    if (isNewsArticle(item)) return 'ARTICLE';
    return 'UNKNOWN';
  }

  /// Clear ads cache for a category
  static void clearCategoryAds(String category) {
    if (_categoryAds.containsKey(category)) {
      // Dispose of the ads
      for (final ad in _categoryAds[category]!) {
        ad.nativeAd.dispose();
      }
      _categoryAds.remove(category);
      print('🗑️ Cleared ads cache for $category');
    }
  }

  /// Clear all ads cache
  static void clearAllAds() {
    for (final category in _categoryAds.keys) {
      clearCategoryAds(category);
    }
    AdMobService.disposeAllAds();
    print('🗑️ Cleared all ads cache');
  }

  /// Preload ads for popular categories (following Google's best practices)
  static Future<void> preloadAdsForCategories(List<String> categories) async {
    print('📱 Preloading ads for categories: ${categories.join(", ")}');
    
    // Clear expired ads first
    AdMobService.clearExpiredAds();
    
    for (final category in categories) {
      try {
        await _getAdsForCategory(category, 2); // Preload 2 ads per category
        await Future.delayed(const Duration(milliseconds: 1000)); // Delay between requests
      } catch (e) {
        print('❌ Failed to preload ads for $category: $e');
      }
    }
    
    print('✅ Finished preloading ads');
  }

  /// Get ad statistics
  static Map<String, dynamic> getAdStats() {
    final totalAds = _categoryAds.values.fold<int>(0, (sum, ads) => sum + ads.length);
    
    return {
      'totalAds': totalAds,
      'categoriesWithAds': _categoryAds.keys.length,
      'adsByCategory': _categoryAds.map((key, value) => MapEntry(key, value.length)),
      'isInitialized': _isInitialized,
    };
  }
}