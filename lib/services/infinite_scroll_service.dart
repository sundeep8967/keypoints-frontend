import '../domain/entities/news_article_entity.dart';
import '../services/supabase_service.dart';
import '../services/read_articles_service.dart';
import '../utils/app_logger.dart';

/// Enhanced infinite scrolling service that ensures users never run out of articles
/// Designed to handle 11,500+ articles with smart preloading and fallback strategies
class InfiniteScrollService {
  static const int _maxBufferSize = 1000; // Maximum articles to keep in memory
  static const int _preloadThreshold = 50; // Start loading when this many articles remain
  static const int _batchSize = 300; // Articles to load per batch
  static const int _fallbackBatchSize = 500; // Larger batch for fallback scenarios
  
  /// Enhanced load more articles with multiple fallback strategies
  static Future<List<NewsArticleEntity>> loadMoreArticlesEnhanced({
    required String category,
    required List<NewsArticleEntity> currentArticles,
    required List<String> readIds,
    int? customBatchSize,
  }) async {
    try {
      final batchSize = customBatchSize ?? _batchSize;
      final offset = currentArticles.length;
      
      AppLogger.info('🔄 INFINITE SCROLL: Loading $batchSize more articles for $category (offset: $offset)');
      
      List<NewsArticleEntity> newArticles = [];
      
      if (category == 'All') {
        newArticles = await _loadMoreForAllCategory(readIds, currentArticles, batchSize);
      } else {
        newArticles = await _loadMoreForSpecificCategory(category, readIds, offset, batchSize);
      }
      
      // If we got very few articles, try fallback strategies
      if (newArticles.length < 10) {
        AppLogger.warning('🔄 INFINITE SCROLL: Got only ${newArticles.length} articles, trying fallback strategies');
        newArticles = await _tryFallbackStrategies(category, readIds, currentArticles);
      }
      
      AppLogger.success('🔄 INFINITE SCROLL: Successfully loaded ${newArticles.length} new articles for $category');
      return newArticles;
      
    } catch (e) {
      AppLogger.error('🔄 INFINITE SCROLL ERROR: $e');
      return [];
    }
  }
  
  /// Load more articles for "All" category from multiple sources
  static Future<List<NewsArticleEntity>> _loadMoreForAllCategory(
    List<String> readIds, 
    List<NewsArticleEntity> currentArticles,
    int batchSize,
  ) async {
    final allCategories = [
      'Technology', 'Business', 'Sports', 'Health', 'Science', 
      'Entertainment', 'World', 'Top', 'Travel', 'Politics', 
      'National', 'India', 'Education', 'Celebrity', 'Startups'
    ];
    
    final List<NewsArticleEntity> allNewArticles = [];
    final existingIds = currentArticles.map((a) => a.id).toSet();
    
    // Calculate offset per category to get different articles
    final offsetPerCategory = currentArticles.length ~/ allCategories.length;
    final articlesPerCategory = (batchSize / allCategories.length).ceil();
    
    // Fetch from all categories in parallel
    final futures = allCategories.map((cat) async {
      try {
        final categoryArticles = await SupabaseService.getUnreadNewsByCategory(
          cat, 
          readIds, 
          limit: articlesPerCategory, 
          offset: offsetPerCategory
        );
        return categoryArticles;
      } catch (e) {
        AppLogger.error('🔄 Error loading from $cat: $e');
        return <NewsArticleEntity>[];
      }
    });
    
    final results = await Future.wait(futures);
    for (final articles in results) {
      allNewArticles.addAll(articles);
    }
    
    // Remove duplicates and articles we already have
    final uniqueNewArticles = allNewArticles.where((article) => 
      !existingIds.contains(article.id) && 
      !readIds.contains(article.id) &&
      article.title.trim().isNotEmpty && 
      article.description.trim().isNotEmpty
    ).toList();
    
    return uniqueNewArticles;
  }
  
  /// Load more articles for a specific category
  static Future<List<NewsArticleEntity>> _loadMoreForSpecificCategory(
    String category,
    List<String> readIds,
    int offset,
    int batchSize,
  ) async {
    final dbCategory = _mapUIToDatabaseCategory(category);
    
    final moreArticles = await SupabaseService.getUnreadNewsByCategory(
      dbCategory, 
      readIds, 
      limit: batchSize, 
      offset: offset
    );
    
    // Filter out invalid articles
    final validArticles = moreArticles.where((article) => 
      article.title.trim().isNotEmpty && 
      article.description.trim().isNotEmpty
    ).toList();
    
    return validArticles;
  }
  
  /// Try multiple fallback strategies when normal loading fails
  static Future<List<NewsArticleEntity>> _tryFallbackStrategies(
    String category,
    List<String> readIds,
    List<NewsArticleEntity> currentArticles,
  ) async {
    AppLogger.info('🔄 FALLBACK: Trying fallback strategies for $category');
    
    // Strategy 1: Try with larger batch size
    try {
      final largerBatch = await loadMoreArticlesEnhanced(
        category: category,
        currentArticles: currentArticles,
        readIds: readIds,
        customBatchSize: _fallbackBatchSize,
      );
      
      if (largerBatch.length > 10) {
        AppLogger.success('🔄 FALLBACK 1: Success with larger batch (${largerBatch.length} articles)');
        return largerBatch;
      }
    } catch (e) {
      AppLogger.error('🔄 FALLBACK 1 failed: $e');
    }
    
    // Strategy 2: Load from similar categories
    if (category != 'All') {
      try {
        final similarArticles = await _loadFromSimilarCategories(category, readIds, currentArticles);
        if (similarArticles.isNotEmpty) {
          AppLogger.success('🔄 FALLBACK 2: Success with similar categories (${similarArticles.length} articles)');
          return similarArticles;
        }
      } catch (e) {
        AppLogger.error('🔄 FALLBACK 2 failed: $e');
      }
    }
    
    // Strategy 3: Load from all articles with different sorting
    try {
      final allArticles = await SupabaseService.getNews(limit: _fallbackBatchSize);
      final existingIds = currentArticles.map((a) => a.id).toSet();
      
      final freshArticles = allArticles.where((article) => 
        !existingIds.contains(article.id) &&
        !readIds.contains(article.id) &&
        article.title.trim().isNotEmpty && 
        article.description.trim().isNotEmpty
      ).toList();
      
      if (freshArticles.isNotEmpty) {
        AppLogger.success('🔄 FALLBACK 3: Success with fresh fetch (${freshArticles.length} articles)');
        return freshArticles;
      }
    } catch (e) {
      AppLogger.error('🔄 FALLBACK 3 failed: $e');
    }
    
    AppLogger.warning('🔄 FALLBACK: All strategies exhausted for $category');
    return [];
  }
  
  /// Load articles from categories similar to the current one
  static Future<List<NewsArticleEntity>> _loadFromSimilarCategories(
    String category,
    List<String> readIds,
    List<NewsArticleEntity> currentArticles,
  ) async {
    final similarCategories = _getSimilarCategories(category);
    final existingIds = currentArticles.map((a) => a.id).toSet();
    final List<NewsArticleEntity> similarArticles = [];
    
    for (String similarCategory in similarCategories) {
      try {
        final articles = await SupabaseService.getUnreadNewsByCategory(
          similarCategory, readIds, limit: 50
        );
        
        final validArticles = articles.where((article) => 
          !existingIds.contains(article.id) &&
          article.title.trim().isNotEmpty && 
          article.description.trim().isNotEmpty
        ).toList();
        
        similarArticles.addAll(validArticles);
        
        if (similarArticles.length >= 20) break; // Stop when we have enough
      } catch (e) {
        AppLogger.error('🔄 Error loading from similar category $similarCategory: $e');
      }
    }
    
    return similarArticles;
  }
  
  /// Get categories similar to the given category
  static List<String> _getSimilarCategories(String category) {
    final categoryGroups = {
      'Technology': ['Science', 'Business', 'Startups', 'Education'],
      'Science': ['Technology', 'Health', 'Education'],
      'Business': ['Technology', 'Politics', 'National', 'Startups'],
      'Sports': ['Entertainment', 'Health'],
      'Entertainment': ['Sports', 'Celebrity', 'Viral'],
      'Health': ['Science', 'Sports'],
      'World': ['Politics', 'National', 'India'],
      'Politics': ['World', 'National', 'Business'],
      'National': ['Politics', 'India', 'World'],
      'India': ['National', 'Politics', 'World'],
      'Education': ['Science', 'Technology'],
      'Celebrity': ['Entertainment', 'Viral'],
      'Startups': ['Technology', 'Business'],
    };
    
    return categoryGroups[category] ?? ['Technology', 'Business', 'World', 'Entertainment'];
  }
  
  /// Map UI category names to database category names
  static String _mapUIToDatabaseCategory(String category) {
    final categoryMap = {
      'Tech': 'Technology',
      'Entertainment': 'Entertainment',
      'Business': 'Business',
      'Health': 'Health',
      'Sports': 'Sports',
      'Science': 'Science',
      'World': 'World',
      'Top': 'Top',
      'Travel': 'Travel',
      'Startups': 'Startups',
      'Politics': 'Politics',
      'National': 'National',
      'India': 'India',
      'Education': 'Education',
      'Celebrity': 'Celebrity',
      'Scandal': 'Scandal',
      'Viral': 'Viral',
      'State': 'State',
    };
    
    return categoryMap[category] ?? category;
  }
  
  /// Check if we should trigger loading more articles
  static bool shouldLoadMore(int currentIndex, int totalItems, {int threshold = 15}) {
    if (totalItems == 0) return false;
    
    // Load when approaching the end
    final remainingItems = totalItems - currentIndex - 1;
    final shouldLoad = remainingItems <= threshold;
    
    if (shouldLoad) {
      AppLogger.info('🔄 SHOULD LOAD MORE: At index $currentIndex of $totalItems (${remainingItems} remaining)');
    }
    
    return shouldLoad;
  }
  
  /// Optimize article buffer by removing old articles if buffer gets too large
  static List<NewsArticleEntity> optimizeBuffer(List<NewsArticleEntity> articles, int currentIndex) {
    if (articles.length <= _maxBufferSize) return articles;
    
    // Keep articles around current position and future articles
    final startIndex = (currentIndex - 50).clamp(0, articles.length);
    final optimizedArticles = articles.sublist(startIndex);
    
    AppLogger.info('🔄 BUFFER OPTIMIZED: Reduced from ${articles.length} to ${optimizedArticles.length} articles');
    return optimizedArticles;
  }
}