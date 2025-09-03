import '../domain/entities/news_article_entity.dart';
import '../models/native_ad_model.dart';
import 'admob_service.dart';
import 'ad_debug_service.dart';
import 'advanced_ad_preloader_service.dart';

import '../utils/app_logger.dart';
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
    AppLogger.success(' Ad Integration Service initialized with advanced preloader');
  }

  /// Mix ads into a list of news articles with unlimited ad support
  static Future<List<dynamic>> integrateAdsIntoFeed({
    required List<NewsArticleEntity> articles,
    required String category,
    int maxAds = 999, // Default to unlimited
  }) async {
    AppLogger.debug(' AD INTEGRATION DEBUG: Starting for $category with ${articles.length} articles, maxAds: ${maxAds == 999 ? "UNLIMITED" : maxAds.toString()}');
    
    if (!_isInitialized) {
      AppLogger.debug(' AD INTEGRATION DEBUG: Not initialized, initializing now...');
      await initialize();
    }

    // IMPROVED: Calculate how many ads we need based on article count
    // Use a more generous ad frequency for longer feeds
    final adPositions = _calculateOptimalAdPositions(articles.length);
    final adsNeeded = adPositions.length.clamp(0, maxAds);
    
    AppLogger.debug(' AD INTEGRATION DEBUG: Ad positions: $adPositions');
    AppLogger.debug(' AD INTEGRATION DEBUG: Ads needed: $adsNeeded');
    
    if (adsNeeded == 0) {
      AppLogger.log('📰 No ads needed for ${articles.length} articles');
      return articles;
    }

    // Get or create ads for this category
    AppLogger.debug(' AD INTEGRATION DEBUG: Getting ads for category $category...');
    final ads = await _getAdsForCategory(category, adsNeeded);
    AppLogger.debug(' AD INTEGRATION DEBUG: Got ${ads.length} ads for $category');
    
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
        AppLogger.info(' ✅ INSERTED AD at position ${mixedFeed.length - 1} (after article $i)');
      }
    }
    
    AppLogger.log('📰 ✅ MIXED FEED CREATED: ${articles.length} articles + ${adIndex} ads = ${mixedFeed.length} items');
    AppLogger.debug(' AD INTEGRATION DEBUG: Final feed breakdown:');
    for (int i = 0; i < mixedFeed.length && i < 10; i++) {
      final itemType = isAd(mixedFeed[i]) ? 'AD' : 'ARTICLE';
      AppLogger.log('  Position $i: $itemType');
    }
    
    return mixedFeed;
  }

  /// Get ads for a specific category with unlimited support and smart batching
  static Future<List<NativeAdModel>> _getAdsForCategory(String category, int count) async {
    AppLogger.debug(' _getAdsForCategory: Requested $count ads for $category');
    
    // For large requests, use smart batching to avoid overwhelming the system
    if (count > 20) {
      AppLogger.info(' 🔄 LARGE AD REQUEST: $count ads requested, using smart batching');
      return await _getBatchedAds(category, count);
    }
    
    // First, try to get ads from the preloaded pool (FASTEST)
    final preloadedAds = AdvancedAdPreloaderService.getPreloadedAds(count, category: category);
    if (preloadedAds.length >= count) {
      AppLogger.info(' ✅ Using PRELOADED ads for $category (${preloadedAds.length} from pool)');
      
      // Trigger predictive preloading for future requests
      AdvancedAdPreloaderService.predictivePreload();
      
      return preloadedAds.take(count).toList();
    }
    
    // Partial fulfillment: Use preloaded + create additional
    if (preloadedAds.isNotEmpty) {
      final remaining = count - preloadedAds.length;
      AppLogger.info(' 🔄 PARTIAL PRELOAD: Using ${preloadedAds.length} preloaded, creating $remaining more');
      
      final additionalAds = await _createAdsBatch(remaining);
      return [...preloadedAds, ...additionalAds];
    }
    
    // Fallback: Check if we have cached ads for this category
    if (_categoryAds.containsKey(category) && _categoryAds[category]!.length >= count) {
      AppLogger.info(' ✅ Using cached ads for $category (${_categoryAds[category]!.length} available)');
      return _categoryAds[category]!.take(count).toList();
    }

    // Last resort: Create new ads immediately
    AppLogger.info(' 🔄 Creating $count new ads for $category...');
    final newAds = await _createAdsBatch(count);
    AppLogger.info(' 📊 Created ${newAds.length} new ads');
    
    // Debug logging if no ads were loaded
    if (newAds.isEmpty) {
      AppLogger.warning(' ❌ NO ADS LOADED for category: $category');
      AppLogger.debug(' This is why you\'re not seeing ads! Running debug analysis...');
      AdDebugService.printDebugInfo();
      
      // Show pool statistics for debugging
      final poolStats = AdvancedAdPreloaderService.getPoolStats();
      AppLogger.log('📊 POOL STATS: $poolStats');
      
      // Try to create a single test ad for debugging
      AppLogger.debug(' Attempting to create a single test ad...');
      final testAd = await AdMobService.createNativeAd();
      if (testAd != null) {
        AppLogger.success(' Test ad created successfully! Issue might be with batch creation.');
        return [testAd]; // Return the test ad
      } else {
        AppLogger.error(' Test ad also failed. Trying banner fallback...');
        final bannerFallback = await AdMobService.createBannerFallback();
        if (bannerFallback != null) {
          AppLogger.success(' Banner fallback ad created successfully!');
          return [bannerFallback];
        } else {
          AppLogger.error(' Both native and banner ads failed. Check network, emulator, or AdMob configuration.');
        }
      }
    } else {
      AppLogger.success(' Successfully loaded ${newAds.length} emergency ads for $category');
      for (int i = 0; i < newAds.length; i++) {
        AppLogger.log('  Ad ${i + 1}: ${newAds[i].isLoaded ? "LOADED" : "NOT LOADED"} - ${newAds[i].title}');
      }
    }
    
    // Cache the ads for future use
    _categoryAds[category] = newAds;
    AppLogger.info(' 💾 Cached ${newAds.length} ads for $category');
    
    return newAds;
  }

  /// Check if an item in the mixed feed is an ad
  static bool isAd(dynamic item) {
    return item is NativeAdModel;
  }

  /// Check if an item in the mixed feed is a news article
  static bool isNewsArticle(dynamic item) {
    return item is NewsArticleEntity;
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
      AppLogger.log('🗑️ Cleared ads cache for $category');
    }
  }

  /// Clear all ads cache
  static void clearAllAds() {
    for (final category in _categoryAds.keys) {
      clearCategoryAds(category);
    }
    AdMobService.disposeAllAds();
    AppLogger.log('🗑️ Cleared all ads cache');
  }

  /// Dispose all services and cleanup
  static void dispose() {
    clearAllAds();
    AdvancedAdPreloaderService.dispose();
    _isInitialized = false;
    AppLogger.log('🗑️ Ad Integration Service disposed');
  }

  /// Preload ads for popular categories (following Google's best practices)
  static Future<void> preloadAdsForCategories(List<String> categories) async {
    AppLogger.info(' Preloading ads for categories: ${categories.join(", ")}');
    
    // Clear expired ads first
    AdMobService.clearExpiredAds();
    
    for (final category in categories) {
      try {
        await _getAdsForCategory(category, 2); // Preload 2 ads per category
        await Future.delayed(const Duration(milliseconds: 1000)); // Delay between requests
      } catch (e) {
        AppLogger.error(' Failed to preload ads for $category: $e');
      }
    }
    
    AppLogger.success(' Finished preloading ads');
  }

  /// Track user reading behavior and smart lazy loading
  static void trackUserReading({
    required int articlesRead,
    required double averageTimePerArticle,
    required String currentCategory,
  }) {
    AppLogger.log('📊 SMART TRACKING: User read $articlesRead articles, avg ${averageTimePerArticle}s each');
    
    // SMART LAZY LOADING: Load more ads when user approaches the limit
    if (articlesRead >= 25 && articlesRead % 5 == 0) {
      AppLogger.info('🧠 SMART LAZY LOADING: User at article $articlesRead, preloading more ads...');
      
      // Load 2-3 more ads for next batch of articles
      _preloadMoreAdsForActiveUser(currentCategory, 2);
    }
    
    // Update preloader with user behavior
    AdvancedAdPreloaderService.adjustPoolSize(
      newReadingSpeed: averageTimePerArticle,
    );
    
    // Trigger predictive preloading only if user is actively reading
    if (articlesRead > 10) {
      AdvancedAdPreloaderService.predictivePreload();
    }
  }

  /// Preload more ads when user is actively reading (lazy loading)
  static Future<void> _preloadMoreAdsForActiveUser(String category, int count) async {
    try {
      AppLogger.info('🧠 LAZY LOADING: User is actively reading, loading $count more ads for $category');
      
      final moreAds = await _createAdsBatch(count);
      if (moreAds.isNotEmpty) {
        // Add to category cache for immediate use
        if (!_categoryAds.containsKey(category)) {
          _categoryAds[category] = [];
        }
        _categoryAds[category]!.addAll(moreAds);
        
        AppLogger.success('✅ LAZY LOADING: Added ${moreAds.length} ads to $category cache');
      }
    } catch (e) {
      AppLogger.error('❌ LAZY LOADING: Failed to load more ads: $e');
    }
  }

  /// Smart batching for large ad requests to avoid overwhelming the system
  static Future<List<NativeAdModel>> _getBatchedAds(String category, int totalCount) async {
    final allAds = <NativeAdModel>[];
    const batchSize = 10; // Create ads in batches of 10
    
    AppLogger.info(' 📦 BATCHED LOADING: Creating $totalCount ads in batches of $batchSize');
    
    for (int i = 0; i < totalCount; i += batchSize) {
      final remainingCount = (totalCount - i).clamp(0, batchSize);
      
      AppLogger.info(' 📦 Batch ${(i / batchSize).floor() + 1}: Creating $remainingCount ads');
      
      final batchAds = await _createAdsBatch(remainingCount);
      allAds.addAll(batchAds);
      
      // Small delay between batches to avoid rate limiting
      if (i + batchSize < totalCount) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      AppLogger.info(' 📦 Batch complete: ${batchAds.length} ads created, total: ${allAds.length}');
    }
    
    AppLogger.success(' 📦 BATCHED LOADING COMPLETE: ${allAds.length}/$totalCount ads created');
    return allAds;
  }
  
  /// Create a batch of ads with error handling and fallbacks
  static Future<List<NativeAdModel>> _createAdsBatch(int count) async {
    final ads = <NativeAdModel>[];
    
    // Try emergency request first (uses advanced preloader)
    try {
      final emergencyAds = await AdvancedAdPreloaderService.emergencyAdRequest(count);
      if (emergencyAds.isNotEmpty) {
        return emergencyAds;
      }
    } catch (e) {
      AppLogger.warning(' Emergency ad request failed: $e, falling back to direct creation');
    }
    
    // Fallback: Create ads directly through AdMob service
    try {
      final directAds = await AdMobService.createMultipleAds(count);
      ads.addAll(directAds);
    } catch (e) {
      AppLogger.error(' Direct ad creation failed: $e');
    }
    
    // If still no ads, create banner fallback ads to maintain user experience and revenue
    if (ads.isEmpty && count > 0) {
      AppLogger.info(' 📱 Creating ${count} banner fallback ads for better monetization');
      for (int i = 0; i < count; i++) {
        final bannerFallback = await AdMobService.createBannerFallback();
        if (bannerFallback != null) {
          ads.add(bannerFallback);
        } else {
          // Only use mock ads as absolute last resort
          AppLogger.warning(' ⚠️ Banner fallback failed, using mock ad as last resort');
          final mockAd = AdMobService.createMockAd();
          if (mockAd != null) {
            ads.add(mockAd);
          }
        }
      }
    }
    
    return ads;
  }

  /// Calculate smart ad positions based on realistic user reading behavior
  static List<int> _calculateOptimalAdPositions(int articleCount) {
    if (articleCount <= 5) return []; // No ads for very short feeds
    
    final positions = <int>[];
    
    // SMART APPROACH: Only prepare ads for articles user will likely read
    // Most users read 10-30 articles, so prepare ads accordingly
    final realisticReadingLimit = articleCount > 50 ? 30 : articleCount;
    
    AppLogger.info('🧠 SMART AD CALCULATION: Preparing ads for $realisticReadingLimit articles (out of $articleCount total)');
    
    // Place first ad after 4th article, then every 5 articles
    int nextAdPosition = 4;
    
    while (nextAdPosition < realisticReadingLimit - 1) {
      positions.add(nextAdPosition);
      nextAdPosition += 5; // Every 5 articles
    }
    
    // Limit to maximum 6 ads initially (enough for 30 articles)
    final smartPositions = positions.take(6).toList();
    
    AppLogger.debug('🧠 SMART AD POSITIONS: For realistic reading of $realisticReadingLimit articles, placing ${smartPositions.length} ads at: $smartPositions');
    return smartPositions;
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