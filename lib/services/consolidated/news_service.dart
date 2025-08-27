import '../../models/news_article.dart';
import '../supabase_service.dart';
import '../read_articles_service.dart';
import '../news_feed_helper.dart';
import '../local_storage_service.dart';

import '../../utils/app_logger.dart';
/// Consolidated service that merges:
/// - news_loading_service.dart
/// - news_feed_helper.dart  
/// - news_integration_service.dart
class NewsService {
  static const int _defaultLimit = 50;

  /// Load news articles with fallback strategy
  static Future<List<NewsArticle>> loadNewsArticles({int limit = _defaultLimit}) async {
    try {
      // PRIORITY 1: Try to load from Supabase first
      try {
        final allArticles = await SupabaseService.getNews(limit: limit * 2); // Get more for filtering
        if (allArticles.isNotEmpty) {
          return await _processAndFilterArticles(allArticles, limit);
        }
      } catch (e) {
        AppLogger.log('Supabase loading failed: $e');
      }

      // PRIORITY 2: Try local cache
      try {
        final cachedArticles = await LocalStorageService.loadUnreadArticles();
        if (cachedArticles.isNotEmpty) {
          AppLogger.log('Loading from local cache: ${cachedArticles.length} articles');
          return await _processAndFilterArticles(cachedArticles, limit);
        }
      } catch (e) {
        AppLogger.log('Local cache loading failed: $e');
      }

      // PRIORITY 3: Try bundled assets as last resort
      try {
        final bundledArticles = <NewsArticle>[];
        if (bundledArticles.isNotEmpty) {
          AppLogger.log('Loading from bundled assets: ${bundledArticles.length} articles');
          return await _processAndFilterArticles(bundledArticles, limit);
        }
      } catch (e) {
        AppLogger.log('Bundled assets loading failed: $e');
      }

      throw Exception('No news sources available');
    } catch (e) {
      AppLogger.log('NewsService.loadNewsArticles error: $e');
      rethrow;
    }
  }

  /// Load articles by category
  static Future<List<NewsArticle>> loadNewsByCategory(
    String category, {
    int limit = _defaultLimit,
  }) async {
    try {
      final dbCategory = _mapCategoryToDatabase(category);
      
      // Try Supabase first
      try {
        final articles = await SupabaseService.getNewsByCategory(dbCategory, limit: limit * 2);
        if (articles.isNotEmpty) {
          return await _processAndFilterArticles(articles, limit);
        }
      } catch (e) {
        AppLogger.log('Supabase category loading failed for $category: $e');
      }

      // Fallback to cached articles filtered by category
      try {
        final cachedArticles = await LocalStorageService.loadUnreadArticles();
        final categoryArticles = cachedArticles
            .where((article) => article.category.toLowerCase() == dbCategory.toLowerCase())
            .toList();
        
        if (categoryArticles.isNotEmpty) {
          return await _processAndFilterArticles(categoryArticles, limit);
        }
      } catch (e) {
        AppLogger.log('Cache category filtering failed: $e');
      }

      return [];
    } catch (e) {
      AppLogger.log('NewsService.loadNewsByCategory error for $category: $e');
      rethrow;
    }
  }

  /// Get random mix of articles from all categories
  static Future<List<NewsArticle>> loadRandomMixArticles({int limit = _defaultLimit}) async {
    try {
      final allCategories = ['technology', 'business', 'sports', 'entertainment', 'health', 'science', 'world'];
      final List<NewsArticle> mixedArticles = [];
      
      // Get a few articles from each category
      final articlesPerCategory = (limit / allCategories.length).ceil();
      
      for (final category in allCategories) {
        try {
          final categoryArticles = await loadNewsByCategory(category, limit: articlesPerCategory);
          mixedArticles.addAll(categoryArticles);
        } catch (e) {
          AppLogger.log('Failed to load $category for mix: $e');
        }
      }
      
      // Shuffle and limit
      mixedArticles.shuffle();
      return mixedArticles.take(limit).toList();
    } catch (e) {
      AppLogger.log('NewsService.loadRandomMixArticles error: $e');
      rethrow;
    }
  }

  /// Refresh news from remote sources
  static Future<List<NewsArticle>> refreshNews({int limit = _defaultLimit}) async {
    try {
      // Force refresh from Supabase
      final articles = await SupabaseService.getNews(limit: limit * 2);
      
      if (articles.isNotEmpty) {
        // Cache the fresh articles
        await LocalStorageService.saveArticles(articles);
        return await _processAndFilterArticles(articles, limit);
      }
      
      throw Exception('No articles received from refresh');
    } catch (e) {
      AppLogger.log('NewsService.refreshNews error: $e');
      rethrow;
    }
  }

  /// Check if articles are stale and need refresh
  static Future<bool> needsRefresh() async {
    try {
      return await LocalStorageService.shouldFetchNewArticles();
    } catch (e) {
      AppLogger.log('NewsService.needsRefresh error: $e');
      return true; // Default to needing refresh on error
    }
  }

  /// Get article statistics
  static Future<Map<String, int>> getArticleStats() async {
    try {
      final readCount = await ReadArticlesService.getReadCount();
      final cachedArticles = await LocalStorageService.loadUnreadArticles();
      
      return {
        'total': cachedArticles.length,
        'read': readCount,
        'unread': cachedArticles.length - readCount,
      };
    } catch (e) {
      AppLogger.log('NewsService.getArticleStats error: $e');
      return {'total': 0, 'read': 0, 'unread': 0};
    }
  }

  // Private helper methods
  static Future<List<NewsArticle>> _processAndFilterArticles(
    List<NewsArticle> articles, 
    int limit,
  ) async {
    try {
      // Filter out already read articles
      final readIds = await ReadArticlesService.getReadArticleIds();
      final unreadArticles = articles.where((article) => 
        !readIds.contains(article.id)
      ).toList();
      
      // Filter out articles with no content and mark them as read
      final validArticles = await NewsFeedHelper.filterValidArticles(unreadArticles);
      
      // Limit results
      final limitedArticles = validArticles.take(limit).toList();
      
      AppLogger.log('Processed ${articles.length} → ${unreadArticles.length} unread → ${validArticles.length} valid → ${limitedArticles.length} final');
      
      return limitedArticles;
    } catch (e) {
      AppLogger.log('_processAndFilterArticles error: $e');
      return articles.take(limit).toList(); // Fallback to unprocessed articles
    }
  }

  static String _mapCategoryToDatabase(String category) {
    switch (category.toLowerCase()) {
      case 'tech':
      case 'technology':
        return 'technology';
      case 'sports':
        return 'sports';
      case 'business':
        return 'business';
      case 'entertainment':
        return 'entertainment';
      case 'health':
        return 'health';
      case 'science':
        return 'science';
      case 'world':
        return 'world';
      default:
        return category.toLowerCase();
    }
  }
}