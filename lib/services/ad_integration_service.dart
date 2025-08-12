import '../models/news_article.dart';
import '../models/native_ad_model.dart';
import 'admob_service.dart';
import 'ad_debug_service.dart';
import 'advanced_ad_preloader_service.dart';

/// Service to seamlessly integrate native ads into news feed
class AdIntegrationService {
  static const int _adFrequency = 5; // Show ad every 5th position
  static final Map<String, List<NativeAdModel>> _categoryAds = {};
  static bool _isInitialized = false;

  /// Initialize ad integration
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    await AdMobService.initialize();
    
    // Initialize advanced preloader for background ad loading
    await AdvancedAdPreloaderService.initialize();
    
    _isInitialized = true;
    print('✅ Ad Integration Service initialized with advanced preloader');
  }

  /// Mix ads into a list of news articles
  static Future<List<dynamic>> integrateAdsIntoFeed({
    required List<NewsArticle> articles,
    required String category,
    int maxAds = 3,
  }) async {
    print('🔍 AD INTEGRATION DEBUG: Starting for $category with ${articles.length} articles');
    
    if (!_isInitialized) {
      print('🔍 AD INTEGRATION DEBUG: Not initialized, initializing now...');
      await initialize();
    }

    // Calculate how many ads we need
    final adPositions = AdMobService.getAdPositions(articles.length);
    final adsNeeded = adPositions.length.clamp(0, maxAds);
    
    print('🔍 AD INTEGRATION DEBUG: Ad positions: $adPositions');
    print('🔍 AD INTEGRATION DEBUG: Ads needed: $adsNeeded');
    
    if (adsNeeded == 0) {
      print('📰 No ads needed for ${articles.length} articles');
      return articles;
    }

    // Get or create ads for this category
    print('🔍 AD INTEGRATION DEBUG: Getting ads for category $category...');
    final ads = await _getAdsForCategory(category, adsNeeded);
    print('🔍 AD INTEGRATION DEBUG: Got ${ads.length} ads for $category');
    
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
        print('📱 ✅ INSERTED AD at position ${mixedFeed.length - 1} (after article $i)');
      }
    }
    
    print('📰 ✅ MIXED FEED CREATED: ${articles.length} articles + ${adIndex} ads = ${mixedFeed.length} items');
    print('🔍 AD INTEGRATION DEBUG: Final feed breakdown:');
    for (int i = 0; i < mixedFeed.length && i < 10; i++) {
      final itemType = isAd(mixedFeed[i]) ? 'AD' : 'ARTICLE';
      print('  Position $i: $itemType');
    }
    
    return mixedFeed;
  }

  /// Get ads for a specific category (with advanced preloading)
  static Future<List<NativeAdModel>> _getAdsForCategory(String category, int count) async {
    print('🔍 _getAdsForCategory: Requested $count ads for $category');
    
    // First, try to get ads from the preloaded pool (FASTEST)
    final preloadedAds = AdvancedAdPreloaderService.getPreloadedAds(count, category: category);
    if (preloadedAds.isNotEmpty) {
      print('🚀 ✅ Using PRELOADED ads for $category (${preloadedAds.length} from pool)');
      
      // Trigger predictive preloading for future requests
      AdvancedAdPreloaderService.predictivePreload();
      
      return preloadedAds;
    }
    
    // Fallback: Check if we have cached ads for this category
    if (_categoryAds.containsKey(category) && _categoryAds[category]!.length >= count) {
      print('📱 ✅ Using cached ads for $category (${_categoryAds[category]!.length} available)');
      return _categoryAds[category]!.take(count).toList();
    }

    // Last resort: Create new ads immediately (SLOWEST)
    print('📱 🔄 Pool empty! Creating $count new ads for $category...');
    final newAds = await AdvancedAdPreloaderService.emergencyAdRequest(count);
    print('📱 📊 Emergency request returned ${newAds.length} ads');
    
    // Debug logging if no ads were loaded
    if (newAds.isEmpty) {
      print('⚠️ ❌ NO ADS LOADED for category: $category');
      print('🔍 This is why you\'re not seeing ads! Running debug analysis...');
      AdDebugService.printDebugInfo();
      
      // Show pool statistics for debugging
      final poolStats = AdvancedAdPreloaderService.getPoolStats();
      print('📊 POOL STATS: $poolStats');
      
      // Try to create a single test ad for debugging
      print('🔍 Attempting to create a single test ad...');
      final testAd = await AdMobService.createNativeAd();
      if (testAd != null) {
        print('✅ Test ad created successfully! Issue might be with batch creation.');
        return [testAd]; // Return the test ad
      } else {
        print('❌ Test ad also failed. Check network, emulator, or AdMob configuration.');
      }
    } else {
      print('✅ Successfully loaded ${newAds.length} emergency ads for $category');
      for (int i = 0; i < newAds.length; i++) {
        print('  Ad ${i + 1}: ${newAds[i].isLoaded ? "LOADED" : "NOT LOADED"} - ${newAds[i].title}');
      }
    }
    
    // Cache the ads for future use
    _categoryAds[category] = newAds;
    print('📱 💾 Cached ${newAds.length} ads for $category');
    
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
        ad.nativeAd?.dispose(); // Handle nullable nativeAd
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

  /// Dispose all services and cleanup
  static void dispose() {
    clearAllAds();
    AdvancedAdPreloaderService.dispose();
    _isInitialized = false;
    print('🗑️ Ad Integration Service disposed');
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

  /// Track user reading behavior to optimize ad preloading
  static void trackUserReading({
    required int articlesRead,
    required double averageTimePerArticle,
    required String currentCategory,
  }) {
    print('📊 TRACKING: User read $articlesRead articles, avg ${averageTimePerArticle}s each');
    
    // Update preloader with user behavior
    AdvancedAdPreloaderService.adjustPoolSize(
      newReadingSpeed: averageTimePerArticle,
    );
    
    // Trigger predictive preloading
    AdvancedAdPreloaderService.predictivePreload();
  }

  /// Get comprehensive ad statistics including preloader stats
  static Map<String, dynamic> getAdStats() {
    final totalAds = _categoryAds.values.fold<int>(0, (sum, ads) => sum + ads.length);
    final poolStats = AdvancedAdPreloaderService.getPoolStats();
    
    return {
      'totalAds': totalAds,
      'categoriesWithAds': _categoryAds.keys.length,
      'adsByCategory': _categoryAds.map((key, value) => MapEntry(key, value.length)),
      'isInitialized': _isInitialized,
      'preloaderStats': poolStats,
    };
  }
}