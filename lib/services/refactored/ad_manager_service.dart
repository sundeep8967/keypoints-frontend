import '../../core/interfaces/ad_manager_interface.dart';
import '../../domain/entities/news_article_entity.dart';
import '../../models/native_ad_model.dart';
import '../admob_service.dart';
import '../advanced_ad_preloader_service.dart';
import '../../utils/app_logger.dart';

/// Ad management service that handles ad integration, preloading, and caching
class AdManagerService implements IAdManager {
  static final AdManagerService _instance = AdManagerService._internal();
  factory AdManagerService() => _instance;
  AdManagerService._internal();

  final Map<String, List<NativeAdModel>> _categoryAds = {};
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await AdMobService.initialize();
    
    // Initialize advanced preloader for background ad loading
    await AdvancedAdPreloaderService.initialize();
    
    _isInitialized = true;
    AppLogger.success('AdManagerService: Initialized with advanced preloader');
  }

  @override
  Future<List<dynamic>> integrateAdsIntoFeed({
    required List<NewsArticleEntity> articles,
    required String category,
    int maxAds = 999,
  }) async {
    // AppLogger.debug('AD MANAGER: Starting for $category with ${articles.length} articles');
    
    if (!_isInitialized) {
      await initialize();
    }

    final adPositions = _calculateOptimalAdPositions(articles.length);
    final adsNeeded = adPositions.length.clamp(0, maxAds);
    
    if (adsNeeded == 0) {
      return articles;
    }

    // Get or create ads for this category
    final ads = await _getAdsForCategory(category, adsNeeded);
    
    // Create mixed feed
    final mixedFeed = <dynamic>[];
    int adIndex = 0;
    
    for (int i = 0; i < articles.length; i++) {
      mixedFeed.add(articles[i]);
      
      if (adPositions.contains(i) && adIndex < ads.length) {
        mixedFeed.add(ads[adIndex]);
        adIndex++;
      }
    }
    
    AppLogger.log('📰 ✅ MIXED FEED CREATED: ${articles.length} articles + ${adIndex} ads');
    return mixedFeed;
  }

  @override
  void clearAllAds() {
    for (final category in _categoryAds.keys) {
      _clearCategoryAds(category);
    }
    AdMobService.disposeAllAds();
    AppLogger.log('AdManagerService: Cleared all ads cache');
  }

  @override
  void dispose() {
    clearAllAds();
    AdvancedAdPreloaderService.dispose();
    _isInitialized = false;
    AppLogger.log('AdManagerService: Disposed');
  }

  @override
  Future<void> preloadAdsForCategories(List<String> categories) async {
    AppLogger.info('AdManagerService: Preloading ads for ${categories.length} categories');
    
    AdMobService.clearExpiredAds();
    
    for (final category in categories) {
      try {
        await _getAdsForCategory(category, 2);
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        AppLogger.error('AdManagerService: Failed to preload for $category: $e');
      }
    }
  }

  @override
  void trackUserReading({
    required int articlesRead,
    required double averageTimePerArticle,
    required String currentCategory,
  }) {
    // Smart lazy loading
    if (articlesRead >= 25 && articlesRead % 5 == 0) {
      AppLogger.info('AdManagerService: Lazy loading more ads...');
      _preloadMoreAdsForActiveUser(currentCategory, 2);
    }
    
    AdvancedAdPreloaderService.adjustPoolSize(
      newReadingSpeed: averageTimePerArticle,
    );
    
    if (articlesRead > 10) {
      AdvancedAdPreloaderService.predictivePreload();
    }
  }

  @override
  Map<String, dynamic> getAdStats() {
    final totalAds = _categoryAds.values.fold<int>(0, (sum, ads) => sum + ads.length);
    
    return {
      'totalAds': totalAds,
      'categoriesWithAds': _categoryAds.keys.length,
      'isInitialized': _isInitialized,
    };
  }

  // Private helpers

  Future<List<NativeAdModel>> _getAdsForCategory(String category, int count) async {
    // Use smart batching for large requests
    if (count > 20) {
      return await _getBatchedAds(category, count);
    }
    
    // 1. Try preloaded pool
    final preloadedAds = AdvancedAdPreloaderService.getPreloadedAds(count, category: category);
    if (preloadedAds.length >= count) {
      AdvancedAdPreloaderService.predictivePreload();
      return preloadedAds.take(count).toList();
    }
    
    // 2. Partial fulfillment
    if (preloadedAds.isNotEmpty) {
      final remaining = count - preloadedAds.length;
      final additionalAds = await _createAdsBatch(remaining);
      return [...preloadedAds, ...additionalAds];
    }
    
    // 3. Cache
    if (_categoryAds.containsKey(category) && _categoryAds[category]!.length >= count) {
      return _categoryAds[category]!.take(count).toList();
    }

    // 4. Create new
    final newAds = await _createAdsBatch(count);
    
    // Update cache
    _categoryAds[category] = newAds;
    
    return newAds;
  }

  void _clearCategoryAds(String category) {
    if (_categoryAds.containsKey(category)) {
      for (final ad in _categoryAds[category]!) {
        ad.nativeAd?.dispose();
      }
      _categoryAds.remove(category);
    }
  }

  Future<List<NativeAdModel>> _createAdsBatch(int count) async {
    final ads = <NativeAdModel>[];
    
    // Try emergency request
    try {
      final emergencyAds = await AdvancedAdPreloaderService.emergencyAdRequest(count);
      if (emergencyAds.isNotEmpty) return emergencyAds;
    } catch (_) {}
    
    // Fallback to direct creation
    try {
      final directAds = await AdMobService.createMultipleAds(count);
      ads.addAll(directAds);
    } catch (e) {
      AppLogger.error('AdManagerService: Direct creation failed: $e');
    }
    
    // Banner fallback
    if (ads.isEmpty && count > 0) {
      for (int i = 0; i < count; i++) {
        final banner = await AdMobService.createBannerFallback();
        if (banner != null) ads.add(banner);
      }
    }
    
    return ads;
  }

  Future<List<NativeAdModel>> _getBatchedAds(String category, int totalCount) async {
    final allAds = <NativeAdModel>[];
    const batchSize = 10;
    
    for (int i = 0; i < totalCount; i += batchSize) {
      final remaining = (totalCount - i).clamp(0, batchSize);
      final batchAds = await _createAdsBatch(remaining);
      allAds.addAll(batchAds);
      
      if (i + batchSize < totalCount) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return allAds;
  }

  Future<void> _preloadMoreAdsForActiveUser(String category, int count) async {
    try {
      final moreAds = await _createAdsBatch(count);
      if (moreAds.isNotEmpty) {
        _categoryAds[category] = _categoryAds[category] ?? [];
        _categoryAds[category]!.addAll(moreAds);
      }
    } catch (_) {}
  }

  List<int> _calculateOptimalAdPositions(int articleCount) {
    if (articleCount <= 5) return [];
    
    final positions = <int>[];
    // Place first ad after 4th article, then every 5 articles across the whole feed
    int nextAdPosition = 4;
    while (nextAdPosition < articleCount - 1) {
      positions.add(nextAdPosition);
      nextAdPosition += 5;
    }
    
    // No hard cap: let the UI decide how many to request via maxAds or batching
    return positions;
  }
}