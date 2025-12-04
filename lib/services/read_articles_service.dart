import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';
class ReadArticlesService {
  // Stream controller for read count changes
  static final StreamController<int> _readCountController = StreamController<int>.broadcast();
  
  /// Stream to listen for read count changes
  static Stream<int> get readCountStream => _readCountController.stream;
  static const String _readArticlesKey = 'read_article_ids';
  static const String _lastCleanupKey = 'last_cleanup_timestamp';
  static const int _maxReadArticles = 1000; // Keep track of max 1000 read articles
  
  // ⚡ PERFORMANCE: Memory cache for read IDs (eliminates 300ms SharedPreferences lookup)
  static Set<String>? _memoryCache;
  static bool _isPreloading = false;

  /// Mark an article as read
  static Future<void> markAsRead(String articleId) async {
    try {
      // ⚡ INSTANT: Update memory cache first
      if (_memoryCache != null) {
        _memoryCache!.add(articleId);
      }
      
      final prefs = await SharedPreferences.getInstance();
      final readIds = await getReadArticleIds();
      
      AppLogger.debug('📖 ReadArticlesService: Attempting to mark article $articleId as read');
      AppLogger.debug('📖 ReadArticlesService: Current read count before: ${readIds.length}');
      
      if (!readIds.contains(articleId)) {
        readIds.add(articleId);
        
        // Keep only latest 1000 read articles to prevent storage bloat
        if (readIds.length > _maxReadArticles) {
          readIds.removeRange(0, readIds.length - _maxReadArticles);
        }
        
        await prefs.setString(_readArticlesKey, jsonEncode(readIds));
        
        // ⚡ UPDATE: Refresh memory cache after write
        _memoryCache = readIds.toSet();
        
        AppLogger.log('Marked article $articleId as read. Total read: ${readIds.length}');
        
        // Emit the new count to listeners
        AppLogger.debug('📖 ReadArticlesService: Emitting new count to stream: ${readIds.length}');
        _readCountController.add(readIds.length);
      } else {
        AppLogger.debug('📖 ReadArticlesService: Article $articleId already marked as read');
      }
    } catch (e) {
      AppLogger.log('Error marking article as read: $e');
    }
  }

  /// Check if an article has been read
  static Future<bool> isRead(String articleId) async {
    try {
      final readIds = await getReadArticleIds();
      return readIds.contains(articleId);
    } catch (e) {
      AppLogger.log('Error checking if article is read: $e');
      return false;
    }
  }

  /// Get all read article IDs (with memory cache for instant access)
  static Future<List<String>> getReadArticleIds() async {
    try {
      // ⚡ INSTANT: Return from memory cache if available
      if (_memoryCache != null) {
        AppLogger.debug('⚡ CACHE HIT: Returning ${_memoryCache!.length} read IDs from memory (0ms)');
        return _memoryCache!.toList();
      }
      
      // Load from storage (only happens once)
      AppLogger.debug('💾 CACHE MISS: Loading read IDs from SharedPreferences (~300ms)');
      final prefs = await SharedPreferences.getInstance();
      final readIdsString = prefs.getString(_readArticlesKey);
      
      if (readIdsString == null) {
        _memoryCache = {};
        return [];
      }
      
      final List<dynamic> readIdsList = jsonDecode(readIdsString);
      final ids = readIdsList.cast<String>();
      
      // ⚡ CACHE: Store in memory for future instant access
      _memoryCache = ids.toSet();
      AppLogger.success('⚡ CACHED: Loaded ${ids.length} read IDs into memory');
      
      return ids;
    } catch (e) {
      AppLogger.log('Error getting read article IDs: $e');
      _memoryCache = {};
      return [];
    }
  }
  
  /// ⚡ PRELOAD: Load read IDs into memory cache at app startup (non-blocking)
  static void preloadCache() {
    if (_isPreloading || _memoryCache != null) return;
    
    _isPreloading = true;
    AppLogger.info('⚡ PRELOAD: Starting read IDs cache preload...');
    
    getReadArticleIds().then((ids) {
      AppLogger.success('⚡ PRELOAD: Cache ready with ${ids.length} read IDs');
      _isPreloading = false;
    }).catchError((e) {
      AppLogger.error('⚡ PRELOAD: Failed: $e');
      _isPreloading = false;
    });
  }

  /// Get count of read articles
  static Future<int> getReadCount() async {
    final readIds = await getReadArticleIds();
    return readIds.length;
  }

  /// Get current count and emit it to stream (useful for initial load)
  static Future<void> emitCurrentCount() async {
    try {
      final count = await getReadCount();
      AppLogger.debug(' ReadArticlesService: About to emit current count: $count');
      AppLogger.debug(' ReadArticlesService: Stream controller has listeners: ${_readCountController.hasListener}');
      _readCountController.add(count);
      AppLogger.debug(' ReadArticlesService: Successfully emitted current count: $count');
    } catch (e) {
      AppLogger.error(' ReadArticlesService: Error emitting current count: $e');
    }
  }


  /// Clear all read articles (for testing or reset)
  static Future<void> clearAllRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_readArticlesKey);
      
      // ⚡ CLEAR: Invalidate memory cache
      _memoryCache = {};
      
      AppLogger.log('Cleared all read articles');
      
      // Emit count of 0 to listeners
      _readCountController.add(0);
    } catch (e) {
      AppLogger.log('Error clearing read articles: $e');
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
        AppLogger.log('Cleaned up read articles: ${readIds.length} -> ${trimmedIds.length}');
      }
      
      await prefs.setString(_lastCleanupKey, now.toIso8601String());
    } catch (e) {
      AppLogger.log('Error during cleanup: $e');
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