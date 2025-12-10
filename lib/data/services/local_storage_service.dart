import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/news_article_entity.dart';
import 'read_articles_service.dart';

import '../../core/utils/app_logger.dart';
class LocalStorageService {
  static const String _articlesKey = 'cached_news_articles';
  static const String _lastFetchKey = 'last_fetch_timestamp';
  static const String _lastArticleIdKey = 'last_article_id';
  static const String _firstTimeSetupKey = 'first_time_setup_completed';
  static const String _languagePreferenceKey = 'language_preference';
  static const String _categoryPreferencesKey = 'category_preferences';
  static const String _availableCategoriesKey = 'available_categories';
  static const String _categoriesLastSyncKey = 'categories_last_sync';

  /// Save articles to local storage (with LRU cache limit of 500 articles)
  static Future<void> saveArticles(List<NewsArticleEntity> articles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // CRITICAL FIX: Filter out read articles before saving
      final readIds = await ReadArticlesService.getReadArticleIds();
      final unreadArticles = articles.where((article) => 
        !readIds.contains(article.id)
      ).toList();
      
      AppLogger.info('💾 SAVE FILTER: ${articles.length} total articles → ${unreadArticles.length} unread articles (filtered out ${articles.length - unreadArticles.length} read articles)');
      
      // 🎯 LRU CACHE: Load existing cache and merge with new articles
      final existingArticles = await _loadAllArticles();
      
      // Use LinkedHashMap to maintain insertion order (LRU behavior)
      final cache = <String, NewsArticleEntity>{};
      
      // Add existing articles first (maintain order)
      for (final article in existingArticles) {
        cache[article.id] = article;
      }
      
      // Add new unread articles (will replace duplicates and move to end)
      for (final article in unreadArticles) {
        cache.remove(article.id); // Remove if exists
        cache[article.id] = article; // Add to end (most recent)
      }
      
      // 🎯 LRU EVICTION: Keep only last 500 articles
      final allCached = cache.values.toList();
      final lruArticles = allCached.length > 500 
          ? allCached.sublist(allCached.length - 500) // Keep last 500
          : allCached;
      
      AppLogger.info('🎯 LRU CACHE: ${cache.length} total → ${lruArticles.length} after eviction (limit: 500)');
      
      // Convert to JSON
      final articlesJson = lruArticles.map((article) => {
        'id': article.id,
        'title': article.title,
        'description': article.description,
        'imageUrl': article.imageUrl,
        'timestamp': article.timestamp.toIso8601String(),
        'category': article.category,
      }).toList();
      
      // Save to SharedPreferences
      await prefs.setString(_articlesKey, jsonEncode(articlesJson));
      await prefs.setString(_lastFetchKey, DateTime.now().toIso8601String());
      
      // Save the latest article ID to track what we've seen
      if (lruArticles.isNotEmpty) {
        await prefs.setString(_lastArticleIdKey, lruArticles.first.id);
      }
      
      AppLogger.success('💾 Saved ${lruArticles.length} articles to LRU cache (max: 500)');
    } catch (e) {
      AppLogger.error('❌ Error saving articles to local storage: $e');
    }
  }

  /// Load unread articles from local storage
  static Future<List<NewsArticleEntity>> loadUnreadArticles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final articlesString = prefs.getString(_articlesKey);
      
      if (articlesString == null) {
        AppLogger.info('📱 No cached articles found');
        return [];
      }
      
      final List<dynamic> articlesJson = jsonDecode(articlesString);
      final allArticles = articlesJson.map((json) => NewsArticleEntity(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        imageUrl: json['imageUrl'] ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
        category: json['category'] ?? 'General',
      )).toList();
      
      // Filter out read articles
      final readIds = await ReadArticlesService.getReadArticleIds();
      final unreadArticles = allArticles.where((article) => 
        !readIds.contains(article.id)
      ).toList();
      
      AppLogger.info('📱 LOAD CACHE: ${allArticles.length} cached articles, ${readIds.length} read IDs, ${unreadArticles.length} unread articles');
      
      // Debug: Show first few articles and their read status
      if (allArticles.isNotEmpty) {
        AppLogger.info('📱 CACHE DEBUG: First 3 cached articles:');
        for (int i = 0; i < allArticles.length && i < 3; i++) {
          final article = allArticles[i];
          final isRead = readIds.contains(article.id);
          final titlePreview = article.title.length > 50 ? article.title.substring(0, 50) + '...' : article.title;
          AppLogger.info('  ${i+1}. "${titlePreview}" (ID: ${article.id}) - ${isRead ? "READ" : "UNREAD"}');
        }
      }
      
      return unreadArticles;
    } catch (e) {
      AppLogger.error('❌ Error loading articles from local storage: $e');
      return [];
    }
  }

  /// Add new unread articles to existing cache (for incremental updates)
  static Future<void> addNewArticles(List<NewsArticleEntity> newArticles) async {
    try {
      // Load existing articles (all, not just unread)
      final existingArticles = await _loadAllArticles();
      
      // Combine new and existing (new articles first)
      final allArticles = [...newArticles, ...existingArticles];
      
      // Remove duplicates based on ID
      final uniqueArticles = <String, NewsArticleEntity>{};
      for (final article in allArticles) {
        uniqueArticles[article.id] = article;
      }
      
      // Keep only latest 500 articles to prevent storage bloat
      final finalArticles = uniqueArticles.values.toList()
        ..sort((a, b) => b.id.compareTo(a.id));
      
      final limitedArticles = finalArticles.take(500).toList();
      
      // Save back to storage
      await saveArticles(limitedArticles);
      
      AppLogger.info(' Added ${newArticles.length} new articles. Total cached: ${limitedArticles.length}');
    } catch (e) {
      AppLogger.error(' Error adding new articles: $e');
    }
  }

  /// Get last fetch timestamp
  static Future<DateTime?> getLastFetchTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampString = prefs.getString(_lastFetchKey);
      
      if (timestampString == null) return null;
      
      return DateTime.tryParse(timestampString);
    } catch (e) {
      AppLogger.error(' Error getting last fetch time: $e');
      return null;
    }
  }

  /// Get last article ID we fetched
  static Future<String?> getLastArticleId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastArticleIdKey);
    } catch (e) {
      AppLogger.error(' Error getting last article ID: $e');
      return null;
    }
  }

  /// Clear all cached data
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_articlesKey);
      await prefs.remove(_lastFetchKey);
      await prefs.remove(_lastArticleIdKey);
      AppLogger.log('🗑️ Cleared all cached articles');
    } catch (e) {
      AppLogger.error(' Error clearing cache: $e');
    }
  }

  /// Load all articles (including read ones) - internal method
  static Future<List<NewsArticleEntity>> _loadAllArticles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final articlesString = prefs.getString(_articlesKey);
      
      if (articlesString == null) return [];
      
      final List<dynamic> articlesJson = jsonDecode(articlesString);
      return articlesJson.map((json) => NewsArticleEntity(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        imageUrl: json['imageUrl'] ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
        category: json['category'] ?? 'General',
      )).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final allArticles = await _loadAllArticles();
      final unreadArticles = await loadUnreadArticles();
      final lastFetch = await getLastFetchTime();
      final lastArticleId = await getLastArticleId();
      final readCount = await ReadArticlesService.getReadCount();
      
      return {
        'totalCached': allArticles.length,
        'unreadArticles': unreadArticles.length,
        'readArticles': readCount,
        'lastFetch': lastFetch?.toIso8601String(),
        'lastArticleId': lastArticleId,
        'oldestArticle': allArticles.isNotEmpty ? allArticles.last.timestamp.toIso8601String() : null,
        'newestArticle': allArticles.isNotEmpty ? allArticles.first.timestamp.toIso8601String() : null,
        'storageEfficiency': '${((unreadArticles.length / (allArticles.length + 1)) * 100).toStringAsFixed(1)}% unread',
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Clean up storage by removing old read articles
  static Future<void> cleanupStorage() async {
    try {
      // Get all articles and read IDs
      final allArticles = await _loadAllArticles();
      final readIds = await ReadArticlesService.getReadArticleIds();
      
      // Keep only unread articles + last 50 read articles for reference
      final unreadArticles = allArticles.where((article) => 
        !readIds.contains(article.id)
      ).toList();
      
      // Save only unread articles back to storage
      await saveArticles(unreadArticles);
      
      // Also cleanup old read IDs
      await ReadArticlesService.cleanupOldReadIds();
      
      AppLogger.log('🧹 Storage cleanup completed. Kept ${unreadArticles.length} unread articles');
    } catch (e) {
      AppLogger.error(' Error during storage cleanup: $e');
    }
  }

  // First-time setup methods
  
  /// Check if first-time setup has been completed
  static Future<bool> isFirstTimeSetupCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_firstTimeSetupKey) ?? false;
    } catch (e) {
      AppLogger.error(' Error checking first-time setup: $e');
      return false;
    }
  }

  /// Mark first-time setup as completed
  static Future<void> setFirstTimeSetupCompleted(bool completed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_firstTimeSetupKey, completed);
      AppLogger.success(' First-time setup marked as ${completed ? 'completed' : 'not completed'}');
    } catch (e) {
      AppLogger.error(' Error setting first-time setup: $e');
    }
  }

  /// Save language preference
  static Future<void> setLanguagePreference(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languagePreferenceKey, languageCode);
      AppLogger.success(' Language preference saved: $languageCode');
    } catch (e) {
      AppLogger.error(' Error saving language preference: $e');
    }
  }

  /// Get language preference
  static Future<String?> getLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_languagePreferenceKey);
    } catch (e) {
      AppLogger.error(' Error getting language preference: $e');
      return null;
    }
  }

  /// Save category preferences
  static Future<void> setCategoryPreferences(List<String> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_categoryPreferencesKey, categories);
      AppLogger.success(' Category preferences saved: ${categories.join(', ')}');
    } catch (e) {
      AppLogger.error(' Error saving category preferences: $e');
    }
  }

  /// Get category preferences
  static Future<List<String>> getCategoryPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_categoryPreferencesKey) ?? [];
    } catch (e) {
      AppLogger.error(' Error getting category preferences: $e');
      return [];
    }
  }

  /// Save available categories (fetched from backend)
  static Future<void> setAvailableCategories(List<String> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_availableCategoriesKey, categories);
      await prefs.setString(_categoriesLastSyncKey, DateTime.now().toIso8601String());
      AppLogger.success('📦 Available categories cached: ${categories.join(', ')}');
    } catch (e) {
      AppLogger.error('❌ Error saving available categories: $e');
    }
  }

  /// Get available categories from cache
  static Future<List<String>?> getAvailableCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_availableCategoriesKey);
    } catch (e) {
      AppLogger.error('❌ Error getting available categories: $e');
      return null;
    }
  }

  /// Get categories last sync timestamp
  static Future<DateTime?> getCategoriesLastSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncString = prefs.getString(_categoriesLastSyncKey);
      if (syncString == null) return null;
      return DateTime.tryParse(syncString);
    } catch (e) {
      AppLogger.error('❌ Error getting categories last sync: $e');
      return null;
    }
  }

  /// Reset first-time setup (for testing)
  static Future<void> resetFirstTimeSetup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_firstTimeSetupKey);
      await prefs.remove(_languagePreferenceKey);
      await prefs.remove(_categoryPreferencesKey);
      AppLogger.info('🔄 First-time setup reset');
    } catch (e) {
      AppLogger.error('❌ Error resetting first-time setup: $e');
    }
  }
}