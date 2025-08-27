import 'package:flutter/cupertino.dart';
import '../../models/news_article.dart';
import '../color_extraction_service.dart';
import 'news_service.dart';
import 'category_service.dart';
import 'article_service.dart';

import '../../utils/app_logger.dart';
/// Facade pattern to simplify service interactions and reduce UI dependencies
/// This is the single entry point for all news-related operations
class NewsFacade {
  // Singleton pattern
  static final NewsFacade _instance = NewsFacade._internal();
  factory NewsFacade() => _instance;
  NewsFacade._internal();

  // State management
  final Map<String, List<NewsArticle>> _categoryCache = {};
  final Map<String, bool> _loadingStates = {};

  /// Initialize the facade and preload essential data
  static Future<void> initialize() async {
    try {
      // Initialize category caches
      CategoryService.initializeCategories();
      
      // Preload popular categories in background
      CategoryService.preloadPopularCategories();
      
      AppLogger.log('NewsFacade: Initialized successfully');
    } catch (e) {
      AppLogger.log('NewsFacade.initialize error: $e');
    }
  }

  /// Load articles for the main feed (All category)
  Future<List<NewsArticle>> loadMainFeed({bool forceRefresh = false}) async {
    try {
      _setLoading('All', true);
      
      List<NewsArticle> articles;
      if (forceRefresh) {
        articles = await NewsService.refreshNews();
      } else {
        articles = await NewsService.loadRandomMixArticles();
      }
      
      // Filter and process articles
      final validArticles = await ArticleService.filterValidArticles(articles);
      
      // Cache the results
      _categoryCache['All'] = validArticles;
      
      // Preload colors for first few articles
      if (validArticles.isNotEmpty) {
        ArticleService.preloadColorPalettes(validArticles, count: 3);
      }
      
      _setLoading('All', false);
      return validArticles;
      
    } catch (e) {
      _setLoading('All', false);
      AppLogger.log('NewsFacade.loadMainFeed error: $e');
      rethrow;
    }
  }

  /// Load articles for a specific category
  Future<List<NewsArticle>> loadCategoryFeed(
    String category, {
    bool forceRefresh = false,
  }) async {
    try {
      _setLoading(category, true);
      
      final articles = await CategoryService.loadCategoryArticles(
        category,
        forceRefresh: forceRefresh,
      );
      
      // Filter and process articles
      final validArticles = await ArticleService.filterValidArticles(articles);
      
      // Cache the results
      _categoryCache[category] = validArticles;
      
      // Preload colors for first few articles
      if (validArticles.isNotEmpty) {
        ArticleService.preloadColorPalettes(validArticles, count: 3);
      }
      
      _setLoading(category, false);
      return validArticles;
      
    } catch (e) {
      _setLoading(category, false);
      AppLogger.log('NewsFacade.loadCategoryFeed error for $category: $e');
      rethrow;
    }
  }

  /// Get cached articles for a category
  List<NewsArticle> getCachedArticles(String category) {
    return _categoryCache[category] ?? [];
  }

  /// Check if category is currently loading
  bool isLoading(String category) {
    return _loadingStates[category] ?? false;
  }

  /// Mark article as read (but keep in current session cache to prevent list changes)
  Future<void> markArticleAsRead(NewsArticle article) async {
    try {
      await ArticleService.markAsRead(article.id);
      
      // DON'T remove from cached categories during active session
      // This prevents the "articles changing while viewing" issue
      // Articles will be filtered out when cache is refreshed or app restarted
      
      AppLogger.log('📖 NewsFacade: Article marked as read (kept in session cache): ${article.title}');
    } catch (e) {
      AppLogger.log('❌ NewsFacade.markArticleAsRead error: $e');
      rethrow;
    }
  }

  /// Share an article
  Future<void> shareArticle(NewsArticle article) async {
    try {
      await ArticleService.shareArticle(article);
    } catch (e) {
      AppLogger.log('NewsFacade.shareArticle error: $e');
      rethrow;
    }
  }

  /// Get color palette for article
  Future<ColorPalette> getArticleColors(String imageUrl) async {
    try {
      return await ArticleService.getArticleColorPalette(imageUrl);
    } catch (e) {
      AppLogger.log('NewsFacade.getArticleColors error: $e');
      return ColorPalette.defaultPalette();
    }
  }

  /// Get available categories
  List<String> getAvailableCategories() {
    return CategoryService.getAllCategories();
  }

  /// Get user's preferred categories
  Future<List<String>> getUserPreferences() async {
    try {
      return await CategoryService.getUserPreferredCategories();
    } catch (e) {
      AppLogger.log('NewsFacade.getUserPreferences error: $e');
      return CategoryService.getPopularCategories();
    }
  }

  /// Save user's category preferences
  Future<void> saveUserPreferences(List<String> categories) async {
    try {
      await CategoryService.saveUserPreferences(categories);
    } catch (e) {
      AppLogger.log('NewsFacade.saveUserPreferences error: $e');
      rethrow;
    }
  }

  /// Show toast message
  void showToast(BuildContext context, String message, {VoidCallback? onDismiss}) {
    ArticleService.showToast(context, message, onDismiss: onDismiss);
  }

  /// Get comprehensive statistics
  Future<Map<String, dynamic>> getStats() async {
    try {
      final newsStats = await NewsService.getArticleStats();
      final articleStats = await ArticleService.getArticleStats();
      final categoryStats = CategoryService.getCategoryStats();
      
      return {
        'news': newsStats,
        'articles': articleStats,
        'categories': categoryStats,
        'cache': {
          'categoriesCached': _categoryCache.length,
          'totalCachedArticles': _categoryCache.values
              .fold<int>(0, (sum, list) => sum + list.length),
        },
      };
    } catch (e) {
      AppLogger.log('NewsFacade.getStats error: $e');
      return {};
    }
  }

  /// Clear all caches and reset
  Future<void> clearAllCaches() async {
    try {
      _categoryCache.clear();
      _loadingStates.clear();
      CategoryService.clearAllCaches();
      ArticleService.clearColorCache();
      
      AppLogger.log('NewsFacade: All caches cleared');
    } catch (e) {
      AppLogger.log('NewsFacade.clearAllCaches error: $e');
    }
  }

  /// Refresh all data
  Future<void> refreshAll() async {
    try {
      await clearAllCaches();
      await initialize();
      AppLogger.log('NewsFacade: Full refresh completed');
    } catch (e) {
      AppLogger.log('NewsFacade.refreshAll error: $e');
      rethrow;
    }
  }

  /// Check if refresh is needed
  Future<bool> needsRefresh() async {
    try {
      return await NewsService.needsRefresh();
    } catch (e) {
      AppLogger.log('NewsFacade.needsRefresh error: $e');
      return true;
    }
  }

  // Private helper methods
  void _setLoading(String category, bool loading) {
    _loadingStates[category] = loading;
  }
}