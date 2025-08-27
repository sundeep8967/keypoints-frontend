import '../models/news_article.dart';
import 'supabase_service.dart';
import 'local_storage_service.dart';
import 'read_articles_service.dart';

import '../utils/app_logger.dart';
/// Integrated service that handles news loading with read article filtering
class NewsIntegrationService {
  
  /// Load unread news articles with smart caching
  static Future<List<NewsArticle>> loadUnreadNews({int displayLimit = 20}) async {
    try {
      AppLogger.info(' Loading unread news articles...');

      // Step 1: Load cached UNREAD articles immediately
      final cachedUnreadArticles = await LocalStorageService.loadUnreadArticles();
      AppLogger.info(' Found ${cachedUnreadArticles.length} cached unread articles');

      // Step 2: Check if we should fetch new articles
      final shouldFetch = await LocalStorageService.shouldFetchNewArticles();
      
      if (shouldFetch) {
        AppLogger.log('🌐 Fetching new articles from Supabase...');
        
        try {
          // Fetch 100 new articles from Supabase
          final newArticles = await SupabaseService.getNews(limit: 100);
          AppLogger.log('📥 Fetched ${newArticles.length} new articles from Supabase');
          
          if (newArticles.isNotEmpty) {
            // Add new articles to cache
            await LocalStorageService.addNewArticles(newArticles);
            
            // Reload UNREAD articles from cache
            final allUnreadArticles = await LocalStorageService.loadUnreadArticles();
            AppLogger.success(' Total unread articles after update: ${allUnreadArticles.length}');
            
            // Periodic cleanup
            await LocalStorageService.cleanupStorage();
            
            return allUnreadArticles.take(displayLimit).toList();
          }
        } catch (e) {
          AppLogger.error(' Error fetching from Supabase: $e');
          // Continue with cached articles if fetch fails
        }
      }

      // Return cached unread articles
      return cachedUnreadArticles.take(displayLimit).toList();
      
    } catch (e) {
      AppLogger.error(' Error in loadUnreadNews: $e');
      return [];
    }
  }

  /// Mark an article as read and get next unread articles
  static Future<List<NewsArticle>> markAsReadAndGetNext(
    String articleId, 
    List<NewsArticle> currentArticles,
    {int displayLimit = 20}
  ) async {
    try {
      // Mark as read
      await ReadArticlesService.markAsRead(articleId);
      AppLogger.success(' Marked article $articleId as read');
      
      // Remove from current list
      final updatedArticles = currentArticles.where((a) => a.id != articleId).toList();
      
      // If running low on articles, load more unread ones
      if (updatedArticles.length < 5) {
        final moreUnreadArticles = await LocalStorageService.loadUnreadArticles();
        return moreUnreadArticles.take(displayLimit).toList();
      }
      
      return updatedArticles;
      
    } catch (e) {
      AppLogger.error(' Error in markAsReadAndGetNext: $e');
      return currentArticles;
    }
  }

  /// Get statistics about articles and storage
  static Future<Map<String, dynamic>> getNewsStats() async {
    try {
      final cacheStats = await LocalStorageService.getCacheStats();
      final readStats = await ReadArticlesService.getReadStats();
      
      return {
        'cache': cacheStats,
        'read': readStats,
        'summary': {
          'unreadArticles': cacheStats['unreadArticles'] ?? 0,
          'readArticles': readStats['totalRead'] ?? 0,
          'storageEfficiency': cacheStats['storageEfficiency'] ?? 'Unknown',
        }
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Check if an article has been read (for UI indicators)
  static Future<bool> isArticleRead(String articleId) async {
    return await ReadArticlesService.isRead(articleId);
  }

  /// Force refresh - clear cache and fetch fresh articles
  static Future<List<NewsArticle>> forceRefresh({int displayLimit = 20}) async {
    try {
      AppLogger.info(' Force refreshing articles...');
      
      // Fetch fresh articles from Supabase
      final freshArticles = await SupabaseService.getNews(limit: 100);
      
      if (freshArticles.isNotEmpty) {
        // Replace cache with fresh articles
        await LocalStorageService.saveArticles(freshArticles);
        
        // Return unread ones
        final unreadArticles = await LocalStorageService.loadUnreadArticles();
        return unreadArticles.take(displayLimit).toList();
      }
      
      return [];
    } catch (e) {
      AppLogger.error(' Error in forceRefresh: $e');
      return [];
    }
  }
}