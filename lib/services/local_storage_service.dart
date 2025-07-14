import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_article.dart';
import 'read_articles_service.dart';

class LocalStorageService {
  static const String _articlesKey = 'cached_news_articles';
  static const String _lastFetchKey = 'last_fetch_timestamp';
  static const String _lastArticleIdKey = 'last_article_id';

  /// Save articles to local storage
  static Future<void> saveArticles(List<NewsArticle> articles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert articles to JSON
      final articlesJson = articles.map((article) => {
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
      if (articles.isNotEmpty) {
        await prefs.setString(_lastArticleIdKey, articles.first.id);
      }
      
      print('✅ Saved ${articles.length} articles to local storage');
    } catch (e) {
      print('❌ Error saving articles to local storage: $e');
    }
  }

  /// Load unread articles from local storage
  static Future<List<NewsArticle>> loadUnreadArticles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final articlesString = prefs.getString(_articlesKey);
      
      if (articlesString == null) {
        print('📱 No cached articles found');
        return [];
      }
      
      final List<dynamic> articlesJson = jsonDecode(articlesString);
      final allArticles = articlesJson.map((json) => NewsArticle(
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
      
      print('📱 Loaded ${allArticles.length} cached articles, ${unreadArticles.length} unread');
      return unreadArticles;
    } catch (e) {
      print('❌ Error loading articles from local storage: $e');
      return [];
    }
  }

  /// Add new unread articles to existing cache (for incremental updates)
  static Future<void> addNewArticles(List<NewsArticle> newArticles) async {
    try {
      // Load existing articles (all, not just unread)
      final existingArticles = await _loadAllArticles();
      
      // Combine new and existing (new articles first)
      final allArticles = [...newArticles, ...existingArticles];
      
      // Remove duplicates based on ID
      final uniqueArticles = <String, NewsArticle>{};
      for (final article in allArticles) {
        uniqueArticles[article.id] = article;
      }
      
      // Keep only latest 500 articles to prevent storage bloat
      final finalArticles = uniqueArticles.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      final limitedArticles = finalArticles.take(500).toList();
      
      // Save back to storage
      await saveArticles(limitedArticles);
      
      print('📱 Added ${newArticles.length} new articles. Total cached: ${limitedArticles.length}');
    } catch (e) {
      print('❌ Error adding new articles: $e');
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
      print('❌ Error getting last fetch time: $e');
      return null;
    }
  }

  /// Get last article ID we fetched
  static Future<String?> getLastArticleId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastArticleIdKey);
    } catch (e) {
      print('❌ Error getting last article ID: $e');
      return null;
    }
  }

  /// Check if we should fetch new articles (every 30 minutes)
  static Future<bool> shouldFetchNewArticles() async {
    final lastFetch = await getLastFetchTime();
    
    if (lastFetch == null) return true; // First time
    
    final now = DateTime.now();
    final difference = now.difference(lastFetch);
    
    // Fetch new articles every 30 minutes
    return difference.inMinutes >= 30;
  }

  /// Clear all cached data
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_articlesKey);
      await prefs.remove(_lastFetchKey);
      await prefs.remove(_lastArticleIdKey);
      print('🗑️ Cleared all cached articles');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  /// Load all articles (including read ones) - internal method
  static Future<List<NewsArticle>> _loadAllArticles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final articlesString = prefs.getString(_articlesKey);
      
      if (articlesString == null) return [];
      
      final List<dynamic> articlesJson = jsonDecode(articlesString);
      return articlesJson.map((json) => NewsArticle(
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
      
      print('🧹 Storage cleanup completed. Kept ${unreadArticles.length} unread articles');
    } catch (e) {
      print('❌ Error during storage cleanup: $e');
    }
  }
}