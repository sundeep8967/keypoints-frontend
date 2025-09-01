import 'package:flutter/cupertino.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/news_article_entity.dart';
import '../read_articles_service.dart';
import '../color_extraction_service.dart';
import '../news_ui_service.dart';

import '../../utils/app_logger.dart';
/// Consolidated service that merges:
/// - article_management_service.dart
/// - read_articles_service.dart  
/// - news_ui_service.dart
class ArticleService {
  // Cache for color palettes
  static final Map<String, ColorPalette> _colorCache = {};
  
  /// Mark an article as read
  static Future<void> markAsRead(String articleId) async {
    try {
      await ReadArticlesService.markAsRead(articleId);
      AppLogger.log('ArticleService: Marked article $articleId as read');
    } catch (e) {
      AppLogger.log('ArticleService.markAsRead error: $e');
      rethrow;
    }
  }

  /// Check if an article is read
  static Future<bool> isArticleRead(String articleId) async {
    try {
      return await ReadArticlesService.isRead(articleId);
    } catch (e) {
      AppLogger.log('ArticleService.isArticleRead error: $e');
      return false;
    }
  }

  /// Get all read article IDs
  static Future<Set<String>> getReadArticleIds() async {
    try {
      final readIds = await ReadArticlesService.getReadArticleIds();
      return readIds.toSet();
    } catch (e) {
      AppLogger.log('ArticleService.getReadArticleIds error: $e');
      return <String>{};
    }
  }

  /// Get count of read articles
  static Future<int> getReadArticleCount() async {
    try {
      return await ReadArticlesService.getReadCount();
    } catch (e) {
      AppLogger.log('ArticleService.getReadArticleCount error: $e');
      return 0;
    }
  }

  /// Clear all read articles (reset)
  static Future<void> clearAllReadArticles() async {
    try {
      await ReadArticlesService.clearAllRead();
      AppLogger.log('ArticleService: Cleared all read articles');
    } catch (e) {
      AppLogger.log('ArticleService.clearAllReadArticles error: $e');
      rethrow;
    }
  }

  /// Extract and cache color palette from article image
  static Future<ColorPalette> getArticleColorPalette(String imageUrl) async {
    try {
      // Check cache first
      if (_colorCache.containsKey(imageUrl)) {
        return _colorCache[imageUrl]!;
      }

      // Extract colors
      final palette = await ColorExtractionService.extractColorsFromImage(imageUrl);
      
      // Cache the result
      _colorCache[imageUrl] = palette;
      
      return palette;
    } catch (e) {
      AppLogger.log('ArticleService.getArticleColorPalette error for $imageUrl: $e');
      
      // Return default palette on error
      final defaultPalette = ColorPalette.defaultPalette();
      _colorCache[imageUrl] = defaultPalette;
      return defaultPalette;
    }
  }

  /// Preload color palettes for multiple articles
  static Future<void> preloadColorPalettes(
    List<NewsArticleEntity> articles, {
    int startIndex = 0,
    int count = 3,
  }) async {
    try {
      final endIndex = (startIndex + count).clamp(0, articles.length);
      
      for (int i = startIndex; i < endIndex; i++) {
        final article = articles[i];
        
        // Skip if already cached
        if (_colorCache.containsKey(article.imageUrl)) {
          continue;
        }
        
        // Preload in background
        getArticleColorPalette(article.imageUrl).catchError((e) {
          AppLogger.log('Background color preload failed for article $i: $e');
          return ColorPalette.defaultPalette();
        });
        
        // Small delay to avoid overwhelming the system
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      AppLogger.log('ArticleService.preloadColorPalettes error: $e');
    }
  }

  /// Get cached color palette (without network request)
  static ColorPalette? getCachedColorPalette(String imageUrl) {
    return _colorCache[imageUrl];
  }

  /// Clear color cache
  static void clearColorCache() {
    _colorCache.clear();
  }

  /// Get color cache statistics
  static Map<String, int> getColorCacheStats() {
    return {
      'cachedColors': _colorCache.length,
    };
  }

  /// Filter articles to remove invalid ones
  static Future<List<NewsArticleEntity>> filterValidArticles(List<NewsArticleEntity> articles) async {
    try {
      final validArticles = <NewsArticleEntity>[];
      final invalidArticleIds = <String>[];

      for (final article in articles) {
        if (_isArticleValid(article)) {
          validArticles.add(article);
        } else {
          invalidArticleIds.add(article.id);
          AppLogger.log('Invalid article filtered: ${article.title} (${article.id})');
        }
      }

      // Mark invalid articles as read so they don't appear again
      if (invalidArticleIds.isNotEmpty) {
        for (final id in invalidArticleIds) {
          await markAsRead(id);
        }
        AppLogger.log('Marked ${invalidArticleIds.length} invalid articles as read');
      }

      return validArticles;
    } catch (e) {
      AppLogger.log('ArticleService.filterValidArticles error: $e');
      return articles; // Return original list on error
    }
  }

  /// Share an article with full functionality
  static Future<void> shareArticle(NewsArticleEntity article) async {
    try {
      AppLogger.log('ArticleService: Sharing article: ${article.title}');
      
      // Create comprehensive share text
      final shareText = '''
📰 ${article.title}

${article.description}

📱 Read more on KeyPoints News App
${article.sourceUrl != null && article.sourceUrl!.isNotEmpty ? '\n🔗 Source: ${article.sourceUrl}' : ''}
''';
      
      // Share with subject for better email/messaging integration
      await Share.share(
        shareText,
        subject: '📰 ${article.title} - KeyPoints News',
      );
      
      AppLogger.success('Article shared successfully: ${article.title}');
      
    } catch (e) {
      AppLogger.error('ArticleService.shareArticle error: $e');
      rethrow;
    }
  }

  /// Show toast message
  static void showToast(BuildContext context, String message, {VoidCallback? onDismiss}) {
    NewsUIService.showToast(context, message, onDismiss: onDismiss);
  }

  /// Get article reading statistics
  static Future<Map<String, dynamic>> getArticleStats() async {
    try {
      final readCount = await getReadArticleCount();
      final readIds = await getReadArticleIds();
      
      return {
        'totalRead': readCount,
        'readToday': _getReadTodayCount(readIds),
        'colorsCached': _colorCache.length,
      };
    } catch (e) {
      AppLogger.log('ArticleService.getArticleStats error: $e');
      return {
        'totalRead': 0,
        'readToday': 0,
        'colorsCached': _colorCache.length,
      };
    }
  }

  /// Remove an article from all caches and mark as read
  static Future<void> removeArticle(NewsArticleEntity article) async {
    try {
      // Mark as read
      await markAsRead(article.id);
      
      // Remove color from cache
      _colorCache.remove(article.imageUrl);
      
      AppLogger.log('ArticleService: Removed article ${article.id}');
    } catch (e) {
      AppLogger.log('ArticleService.removeArticle error: $e');
      rethrow;
    }
  }

  /// Batch mark multiple articles as read
  static Future<void> markMultipleAsRead(List<String> articleIds) async {
    try {
      for (final id in articleIds) {
        await markAsRead(id);
      }
      AppLogger.log('ArticleService: Marked ${articleIds.length} articles as read');
    } catch (e) {
      AppLogger.log('ArticleService.markMultipleAsRead error: $e');
      rethrow;
    }
  }

  // Private helper methods
  static bool _isArticleValid(NewsArticleEntity article) {
    // Check if article has required fields
    if (article.title.trim().isEmpty) return false;
    if (article.description.trim().isEmpty) return false;
    if (article.imageUrl.trim().isEmpty) return false;
    
    // Check for placeholder or invalid content
    if (article.title.toLowerCase().contains('lorem ipsum')) return false;
    if (article.description.toLowerCase().contains('lorem ipsum')) return false;
    if (article.description.length < 50) return false; // Too short description
    
    return true;
  }

  static int _getReadTodayCount(Set<String> readIds) {
    // This is a simplified implementation
    // In a real app, you'd store timestamps with read articles
    // For now, return a placeholder
    return 0;
  }
}