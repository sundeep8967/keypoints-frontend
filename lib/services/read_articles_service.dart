import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ReadArticlesService {
  static const String _readArticlesKey = 'read_article_ids';
  static const String _lastCleanupKey = 'last_cleanup_timestamp';
  static const int _maxReadArticles = 1000; // Keep track of max 1000 read articles

  /// Mark an article as read
  static Future<void> markAsRead(String articleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds = await getReadArticleIds();
      
      if (!readIds.contains(articleId)) {
        readIds.add(articleId);
        
        // Keep only latest 1000 read articles to prevent storage bloat
        if (readIds.length > _maxReadArticles) {
          readIds.removeRange(0, readIds.length - _maxReadArticles);
        }
        
        await prefs.setString(_readArticlesKey, jsonEncode(readIds));
        print('Marked article $articleId as read. Total read: ${readIds.length}');
      }
    } catch (e) {
      print('Error marking article as read: $e');
    }
  }

  /// Check if an article has been read
  static Future<bool> isRead(String articleId) async {
    try {
      final readIds = await getReadArticleIds();
      return readIds.contains(articleId);
    } catch (e) {
      print('Error checking if article is read: $e');
      return false;
    }
  }

  /// Get all read article IDs
  static Future<List<String>> getReadArticleIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readIdsString = prefs.getString(_readArticlesKey);
      
      if (readIdsString == null) return [];
      
      final List<dynamic> readIdsList = jsonDecode(readIdsString);
      return readIdsList.cast<String>();
    } catch (e) {
      print('Error getting read article IDs: $e');
      return [];
    }
  }

  /// Get count of read articles
  static Future<int> getReadCount() async {
    final readIds = await getReadArticleIds();
    return readIds.length;
  }

  /// Clear all read articles (for testing or reset)
  static Future<void> clearAllRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_readArticlesKey);
      print('Cleared all read articles');
    } catch (e) {
      print('Error clearing read articles: $e');
    }
  }

  /// Clean up old read article IDs (keep only recent ones)
  static Future<void> cleanupOldReadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCleanup = prefs.getString(_lastCleanupKey);
      final now = DateTime.now();
      
      // Clean up once per week
      if (lastCleanup != null) {
        final lastCleanupDate = DateTime.tryParse(lastCleanup);
        if (lastCleanupDate != null && 
            now.difference(lastCleanupDate).inDays < 7) {
          return; // Too soon for cleanup
        }
      }
      
      final readIds = await getReadArticleIds();
      
      // Keep only latest 500 read article IDs
      if (readIds.length > 500) {
        final trimmedIds = readIds.sublist(readIds.length - 500);
        await prefs.setString(_readArticlesKey, jsonEncode(trimmedIds));
        print('Cleaned up read articles: ${readIds.length} -> ${trimmedIds.length}');
      }
      
      await prefs.setString(_lastCleanupKey, now.toIso8601String());
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }

  /// Get statistics about read articles
  static Future<Map<String, dynamic>> getReadStats() async {
    try {
      final readIds = await getReadArticleIds();
      final prefs = await SharedPreferences.getInstance();
      final lastCleanup = prefs.getString(_lastCleanupKey);
      
      return {
        'totalRead': readIds.length,
        'maxTracked': _maxReadArticles,
        'lastCleanup': lastCleanup,
        'storageUsed': '${(readIds.join().length / 1024).toStringAsFixed(2)} KB',
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}