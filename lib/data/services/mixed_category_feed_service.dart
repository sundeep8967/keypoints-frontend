import '../../domain/entities/news_article_entity.dart';
import '../services/supabase_service.dart';
import '../services/read_articles_service.dart';
import '../../core/utils/app_logger.dart';

/// Service to create mixed category feeds
/// Intelligently mixes articles from multiple categories
class MixedCategoryFeedService {
  /// Popular categories to mix in the feed
  static const List<String> _popularCategories = [
    'Technology',
    'Sports',
    'Business',
    'Entertainment',
    'Politics',
  ];

  /// Create a mixed feed from multiple categories
  /// Returns articles interleaved from different categories
  static Future<List<NewsArticleEntity>> createMixedFeed({
    int articlesPerCategory = 20,
    List<String>? customCategories,
  }) async {
    AppLogger.info('🎨 CREATING MIXED FEED from ${customCategories?.length ?? _popularCategories.length} categories');
    
    final categories = customCategories ?? _popularCategories;
    final readIds = await ReadArticlesService.getReadArticleIds();
    
    // Fetch articles from each category concurrently
    final futures = categories.map((category) => 
      _fetchCategoryArticles(category, articlesPerCategory, readIds.toList())
    ).toList();
    
    final results = await Future.wait(futures);
    
    // Mix articles intelligently
    final mixedArticles = _interleaveArticles(results, categories);
    
    AppLogger.success('✅ MIXED FEED CREATED: ${mixedArticles.length} articles from ${categories.length} categories');
    
    return mixedArticles;
  }

  /// Fetch articles from a specific category
  static Future<List<NewsArticleEntity>> _fetchCategoryArticles(
    String category,
    int limit,
    List<String> readIds,
  ) async {
    try {
      final articles = await SupabaseService.getUnreadNewsByCategory(
        category,
        readIds,
        limit: limit,
      );
      
      AppLogger.info('📂 Fetched ${articles.length} unread articles from $category');
      return articles;
    } catch (e) {
      AppLogger.error('❌ Failed to fetch $category: $e');
      return [];
    }
  }

  /// Intelligently interleave articles from different categories
  /// Uses round-robin to ensure variety and removes duplicates
  static List<NewsArticleEntity> _interleaveArticles(
    List<List<NewsArticleEntity>> categoryArticles,
    List<String> categories,
  ) {
    final mixed = <NewsArticleEntity>[];
    final seenIds = <String>{}; // Track unique article IDs
    final maxLength = categoryArticles.map((list) => list.length).reduce((a, b) => a > b ? a : b);
    
    // Round-robin through categories
    for (int i = 0; i < maxLength; i++) {
      for (int j = 0; j < categoryArticles.length; j++) {
        if (i < categoryArticles[j].length) {
          final article = categoryArticles[j][i];
          
          // Only add if we haven't seen this article ID before
          if (!seenIds.contains(article.id)) {
            mixed.add(article);
            seenIds.add(article.id);
            AppLogger.debug('✓ Added unique article from ${categories[j]}: ${article.id}');
          } else {
            AppLogger.debug('⊗ Skipped duplicate article: ${article.id}');
          }
        }
      }
    }
    
    AppLogger.info('🎨 INTERLEAVED: ${mixed.length} unique articles (${seenIds.length} total, duplicates removed)');
    return mixed;
  }

  /// Get available categories for mixing
  static List<String> getAvailableCategories() {
    return List.from(_popularCategories);
  }

  /// Create a custom mixed feed with specific categories and ratios
  static Future<List<NewsArticleEntity>> createCustomMixedFeed({
    required Map<String, int> categoryRatios,
  }) async {
    AppLogger.info('🎨 CREATING CUSTOM MIXED FEED with ratios: $categoryRatios');
    
    final readIds = await ReadArticlesService.getReadArticleIds();
    final categoryArticles = <List<NewsArticleEntity>>[];
    final categories = <String>[];
    
    for (final entry in categoryRatios.entries) {
      final articles = await _fetchCategoryArticles(
        entry.key,
        entry.value,
        readIds.toList(),
      );
      categoryArticles.add(articles);
      categories.add(entry.key);
    }
    
    return _interleaveArticles(categoryArticles, categories);
  }
}
