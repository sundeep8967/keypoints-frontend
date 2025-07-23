import 'package:flutter/cupertino.dart';
import '../../models/news_article.dart';
import '../color_extraction_service.dart';
import 'news_service.dart';
import 'category_service.dart';
import 'article_service.dart';

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
      
      print('NewsFacade: Initialized successfully');
    } catch (e) {
      print('NewsFacade.initialize error: $e');
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
      print('NewsFacade.loadMainFeed error: $e');
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
      print('NewsFacade.loadCategoryFeed error for $category: $e');
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

  /// Mark article as read and remove from feeds
  Future<void> markArticleAsRead(NewsArticle article) async {
    try {
      await ArticleService.markAsRead(article.id);
      
      // Remove from all cached categories
      for (final categoryList in _categoryCache.values) {
        categoryList.removeWhere((a) => a.id == article.id);
      }
      
      print('NewsFacade: Article marked as read and removed from feeds');
    } catch (e) {
      print('NewsFacade.markArticleAsRead error: $e');
      rethrow;
    }
  }

  /// Share an article
  Future<void> shareArticle(NewsArticle article) async {
    try {
      await ArticleService.shareArticle(article);
    } catch (e) {
      print('NewsFacade.shareArticle error: $e');
      rethrow;
    }
  }

  /// Get color palette for article
  Future<ColorPalette> getArticleColors(String imageUrl) async {
    try {
      return await ArticleService.getArticleColorPalette(imageUrl);
    } catch (e) {
      print('NewsFacade.getArticleColors error: $e');
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
      print('NewsFacade.getUserPreferences error: $e');
      return CategoryService.getPopularCategories();
    }
  }

  /// Save user's category preferences
  Future<void> saveUserPreferences(List<String> categories) async {
    try {
      await CategoryService.saveUserPreferences(categories);
    } catch (e) {
      print('NewsFacade.saveUserPreferences error: $e');
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
      print('NewsFacade.getStats error: $e');
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
      
      print('NewsFacade: All caches cleared');
    } catch (e) {
      print('NewsFacade.clearAllCaches error: $e');
    }
  }

  /// Refresh all data
  Future<void> refreshAll() async {
    try {
      await clearAllCaches();
      await initialize();
      print('NewsFacade: Full refresh completed');
    } catch (e) {
      print('NewsFacade.refreshAll error: $e');
      rethrow;
    }
  }

  /// Check if refresh is needed
  Future<bool> needsRefresh() async {
    try {
      return await NewsService.needsRefresh();
    } catch (e) {
      print('NewsFacade.needsRefresh error: $e');
      return true;
    }
  }

  // Private helper methods
  void _setLoading(String category, bool loading) {
    _loadingStates[category] = loading;
  }
}