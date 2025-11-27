import '../../core/interfaces/article_interface.dart';
import '../../core/interfaces/news_interface.dart';
import '../../core/interfaces/category_interface.dart';
import '../../core/interfaces/ad_manager_interface.dart';
import '../../domain/entities/news_article_entity.dart';
import 'article_validator_service.dart';
import 'article_state_manager.dart';
import 'news_loader_service.dart';
import 'news_processor_service.dart';
import 'category_manager_service.dart';
import 'ad_manager_service.dart';
import '../../utils/app_logger.dart';

/// Service coordinator that manages all refactored services and provides a unified interface
/// This replaces the old circular dependency pattern with a clean coordinator pattern
class ServiceCoordinator {
  static final ServiceCoordinator _instance = ServiceCoordinator._internal();
  factory ServiceCoordinator() => _instance;
  ServiceCoordinator._internal();

  // Service instances
  late final IArticleValidator _articleValidator;
  late final IArticleStateManager _articleStateManager;
  late final INewsLoader _newsLoader;
  late final INewsProcessor _newsProcessor;
  late final ICategoryManager _categoryManager;
  late final IAdManager _adManager;

  bool _initialized = false;

  /// Initialize all services
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _articleValidator = ArticleValidatorService();
      _articleStateManager = ArticleStateManager();
      _newsLoader = NewsLoaderService();
      _newsProcessor = NewsProcessorService();
      _categoryManager = CategoryManagerService();
      _adManager = AdManagerService();

      // Initialize ad manager
      await _adManager.initialize();

      // Initialize category system
      await (_categoryManager as CategoryManagerService).initializeCategories();
      
      // Preload popular categories in background
      _preloadPopularCategoriesInBackground();

      _initialized = true;
      AppLogger.log('ServiceCoordinator: All services initialized successfully');
    } catch (e) {
      AppLogger.log('ServiceCoordinator.initialize error: $e');
      rethrow;
    }
  }

  /// Get article validator service
  IArticleValidator get articleValidator {
    _ensureInitialized();
    return _articleValidator;
  }

  /// Get article state manager service
  IArticleStateManager get articleStateManager {
    _ensureInitialized();
    return _articleStateManager;
  }

  /// Get news loader service
  INewsLoader get newsLoader {
    _ensureInitialized();
    return _newsLoader;
  }

  /// Get news processor service
  INewsProcessor get newsProcessor {
    _ensureInitialized();
    return _newsProcessor;
  }

  /// Get category manager service
  ICategoryManager get categoryManager {
    _ensureInitialized();
    return _categoryManager;
  }

  /// Get ad manager service
  IAdManager get adManager {
    _ensureInitialized();
    return _adManager;
  }

  /// Load main news feed with proper coordination
  Future<List<NewsArticleEntity>> loadMainFeed({bool forceRefresh = false}) async {
    _ensureInitialized();
    
    try {
      List<NewsArticleEntity> articles;
      
      if (forceRefresh) {
        articles = await _newsLoader.refreshNews();
      } else {
        articles = await _newsLoader.loadRandomMixArticles();
      }
      
      AppLogger.log('ServiceCoordinator: Loaded ${articles.length} articles for main feed');
      return articles;
    } catch (e) {
      AppLogger.log('ServiceCoordinator.loadMainFeed error: $e');
      return [];
    }
  }

  /// Load articles for a specific category
  Future<List<NewsArticleEntity>> loadCategoryFeed(String category, {bool forceRefresh = false}) async {
    _ensureInitialized();
    
    try {
      if (forceRefresh) {
        // Clear cache and reload
        if (_categoryManager is CategoryManagerService) {
          (_categoryManager as CategoryManagerService).clearCategoryCache(category);
        }
      }
      
      final articles = await _categoryManager.loadCategoryArticles(category);
      AppLogger.log('ServiceCoordinator: Loaded ${articles.length} articles for category: $category');
      return articles;
    } catch (e) {
      AppLogger.log('ServiceCoordinator.loadCategoryFeed error for $category: $e');
      return [];
    }
  }

  /// Check if a category is currently loading
  bool isCategoryLoading(String category) {
    _ensureInitialized();
    if (_categoryManager is CategoryManagerService) {
      return (_categoryManager as CategoryManagerService).isCategoryLoading(category);
    }
    return false;
  }

  /// Clear cache for a specific category
  void clearCategoryCache(String category) {
    _ensureInitialized();
    if (_categoryManager is CategoryManagerService) {
      (_categoryManager as CategoryManagerService).clearCategoryCache(category);
    }
  }

  /// Mark article as read and handle any side effects
  Future<void> markArticleAsRead(String articleId) async {
    _ensureInitialized();
    
    try {
      await _articleStateManager.markAsRead(articleId);
      AppLogger.log('ServiceCoordinator: Marked article $articleId as read');
    } catch (e) {
      AppLogger.log('ServiceCoordinator.markArticleAsRead error: $e');
      rethrow;
    }
  }

  /// Get comprehensive article statistics
  Future<Map<String, dynamic>> getArticleStatistics() async {
    _ensureInitialized();
    
    try {
      final readCount = await _articleStateManager.getReadArticleCount();
      final readIds = await _articleStateManager.getReadArticleIds();
      
      return {
        'readCount': readCount,
        'readIds': readIds.toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger.log('ServiceCoordinator.getArticleStatistics error: $e');
      return {};
    }
  }

  /// Preload popular categories in background
  void _preloadPopularCategoriesInBackground() {
    Future.delayed(const Duration(milliseconds: 1000), () async {
      try {
        await _categoryManager.preloadPopularCategories();
      } catch (e) {
        AppLogger.log('Background preloading failed: $e');
      }
    });
  }

  /// Ensure services are initialized
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('ServiceCoordinator must be initialized before use. Call initialize() first.');
    }
  }

  /// Load main feed progressively with ads
  Stream<List<dynamic>> loadFeedProgressivelyWithAds() async* {
    _ensureInitialized();
    
    final articleStream = _newsLoader.loadArticlesProgressively();
    
    await for (final articles in articleStream) {
      // Integrate ads
      final feed = await _adManager.integrateAdsIntoFeed(
        articles: articles,
        category: 'All', // Main feed
      );
      yield feed;
    }
  }

  /// Reset all services (useful for testing or complete refresh)
  Future<void> reset() async {
    try {
      if (_categoryManager is CategoryManagerService) {
        _categoryManager.clearAllCaches();
      }
      
      _adManager.dispose();
      _initialized = false;
      await initialize();
      
      AppLogger.log('ServiceCoordinator: Reset completed');
    } catch (e) {
      AppLogger.log('ServiceCoordinator.reset error: $e');
      rethrow;
    }
  }
}