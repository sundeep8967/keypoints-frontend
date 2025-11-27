import '../../core/interfaces/news_interface.dart';
import '../../core/interfaces/article_interface.dart';
import '../../domain/entities/news_article_entity.dart';
import '../supabase_service.dart';
import '../local_storage_service.dart';
import 'article_validator_service.dart';
import 'article_state_manager.dart';
import 'news_processor_service.dart';
import '../../utils/app_logger.dart';

/// News loading service that implements INewsLoader without circular dependencies
class NewsLoaderService implements INewsLoader {
  static final NewsLoaderService _instance = NewsLoaderService._internal();
  factory NewsLoaderService() => _instance;
  NewsLoaderService._internal();

  final IArticleValidator _articleValidator = ArticleValidatorService();
  final IArticleStateManager _articleStateManager = ArticleStateManager();
  final INewsProcessor _newsProcessor = NewsProcessorService();

  static const int _defaultLimit = 50;

  @override
  Future<List<NewsArticleEntity>> loadNewsArticles({int limit = _defaultLimit}) async {
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

      throw Exception('No news sources available');
    } catch (e) {
      AppLogger.log('NewsLoaderService.loadNewsArticles error: $e');
      return [];
    }
  }

  @override
  Future<List<NewsArticleEntity>> loadArticlesByCategory(String category, {bool isRightSwipe = false}) async {
    try {
      // PRIORITY 1: Try Supabase category filter
      try {
        final allCategoryArticles = await SupabaseService.getNewsByCategory(category, limit: 1000);
        if (allCategoryArticles.isNotEmpty) {
          return await _processAndFilterArticles(allCategoryArticles, _defaultLimit);
        }
      } catch (e) {
        AppLogger.log('Supabase category loading failed: $e');
      }

      // PRIORITY 2: Try local cache with category filter
      try {
        final cachedArticles = await LocalStorageService.loadUnreadArticles();
        final categoryArticles = cachedArticles.where((article) => 
          _newsProcessor.detectArticleCategory(article, category) == category
        ).toList();
        
        if (categoryArticles.isNotEmpty) {
          return await _processAndFilterArticles(categoryArticles, _defaultLimit);
        }
      } catch (e) {
        AppLogger.log('Local cache category loading failed: $e');
      }

      throw Exception('No articles found for category: $category');
    } catch (e) {
      AppLogger.log('NewsLoaderService.loadArticlesByCategory error: $e');
      return [];
    }
  }

  @override
  Future<List<NewsArticleEntity>> refreshNews() async {
    try {
      // Force refresh from Supabase
      final allArticles = await SupabaseService.getNews(limit: _defaultLimit * 2);
      return await _processAndFilterArticles(allArticles, _defaultLimit);
    } catch (e) {
      AppLogger.log('NewsLoaderService.refreshNews error: $e');
      return [];
    }
  }

  @override
  Future<List<NewsArticleEntity>> loadRandomMixArticles() async {
    try {
      // Load articles from multiple categories and mix them
      final categories = ['Technology', 'Business', 'Sports', 'Entertainment', 'Health'];
      final allArticles = <NewsArticleEntity>[];

      for (final category in categories) {
        try {
          final categoryArticles = await SupabaseService.getNewsByCategory(category, limit: 10);
          allArticles.addAll(categoryArticles);
        } catch (e) {
          AppLogger.log('Failed to load category $category: $e');
        }
      }

      // Shuffle for random mix
      allArticles.shuffle();
      
      return await _processAndFilterArticles(allArticles, _defaultLimit);
    } catch (e) {
      AppLogger.log('NewsLoaderService.loadRandomMixArticles error: $e');
      return [];
    }
  }

  /// Load articles progressively - yields updates as content becomes available
  Stream<List<NewsArticleEntity>> loadArticlesProgressively() async* {
    final List<NewsArticleEntity> allProgressiveArticles = [];
    List<NewsArticleEntity> firstBatchArticles = [];
    bool hasShownFirstBatch = false;
    
    // Define categories to load from
    final categories = [
      'Technology', 'Business', 'Sports', 'Health', 'Science', 
      'Entertainment', 'World', 'Top', 'Travel', 'Politics'
    ];
    
    AppLogger.info('🚀 PROGRESSIVE: Starting progressive load from ${categories.length} categories');
    
    final readIds = await _articleStateManager.getReadArticleIds();
    
    // Load categories one by one
    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      
      try {
        final categoryArticles = await SupabaseService.getUnreadNewsByCategory(
          category, readIds.toList(), limit: 100
        );
        
        if (categoryArticles.isNotEmpty) {
          allProgressiveArticles.addAll(categoryArticles);
          
          // Remove duplicates but MAINTAIN ORDER
          final uniqueArticles = <String, NewsArticleEntity>{};
          final stableOrderedArticles = <NewsArticleEntity>[];
          
          for (final article in allProgressiveArticles) {
            if (!uniqueArticles.containsKey(article.id)) {
              uniqueArticles[article.id] = article;
              stableOrderedArticles.add(article);
            }
          }
          
          // Emit first batch immediately
          if (!hasShownFirstBatch && (stableOrderedArticles.length >= 5 || i >= 2)) {
            AppLogger.success('🚀 PROGRESSIVE: Yielding FIRST BATCH - ${stableOrderedArticles.length} articles');
            firstBatchArticles = List.from(stableOrderedArticles);
            hasShownFirstBatch = true;
            yield stableOrderedArticles;
          }
        }
        
        // Small delay to prevent overwhelming DB
        if (i < categories.length - 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
      } catch (e) {
        AppLogger.error('🚀 PROGRESSIVE: Error loading $category: $e');
      }
    }
    
    // Final Mix
    if (allProgressiveArticles.isNotEmpty) {
      final uniqueArticles = <String, NewsArticleEntity>{};
      for (final article in allProgressiveArticles) {
        uniqueArticles[article.id] = article;
      }
      final finalArticles = uniqueArticles.values.toList();
      
      List<NewsArticleEntity> mixedFeed;
      
      if (firstBatchArticles.isNotEmpty) {
        // Preserve first batch order
        final firstBatchIds = firstBatchArticles.map((a) => a.id).toSet();
        final restArticles = finalArticles.where((a) => !firstBatchIds.contains(a.id)).toList();
        
        // Mix the rest
        restArticles.shuffle(); // Simple shuffle for now, or use balanced mix if needed
        
        mixedFeed = [...firstBatchArticles, ...restArticles];
      } else {
        mixedFeed = List.from(finalArticles)..shuffle();
      }
      
      AppLogger.success('🚀 PROGRESSIVE: Yielding FINAL MIXED FEED - ${mixedFeed.length} articles');
      yield mixedFeed;
    }
  }

  /// Internal method to process and filter articles
  Future<List<NewsArticleEntity>> _processAndFilterArticles(
    List<NewsArticleEntity> articles, 
    int limit
  ) async {
    try {
      // Filter out already read articles
      final unreadArticles = await _articleStateManager.filterUnreadArticles(articles);
      
      // Validate articles and get invalid ones
      final validArticles = await _articleValidator.filterValidArticles(unreadArticles);
      final invalidArticles = await _articleValidator.getInvalidArticles(unreadArticles);
      
      // Mark invalid articles as read automatically
      if (invalidArticles.isNotEmpty) {
        await _articleStateManager.markInvalidArticlesAsRead(invalidArticles);
      }
      
      // Apply limit
      final limitedArticles = validArticles.take(limit).toList();
      
      AppLogger.log('Processed ${articles.length} total -> ${unreadArticles.length} unread -> ${validArticles.length} valid -> ${limitedArticles.length} final');
      
      return limitedArticles;
    } catch (e) {
      AppLogger.log('_processAndFilterArticles error: $e');
      return [];
    }
  }

  /// Debug method to check database categories
  Future<void> debugDatabaseCategories() async {
    try {
      final categories = ['Technology', 'Business', 'Sports', 'Entertainment', 'Health', 'Science', 'World'];
      
      for (final category in categories) {
        try {
          final articles = await SupabaseService.getNewsByCategory(category, limit: 1);
          AppLogger.log('Category $category: ${articles.length} articles available');
        } catch (e) {
          AppLogger.log('Category $category: Error - $e');
        }
      }
    } catch (e) {
      AppLogger.log('debugDatabaseCategories error: $e');
    }
  }
}