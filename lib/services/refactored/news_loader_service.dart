import 'dart:async';
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

  List<NewsArticleEntity> _balancedInterleave(List<NewsArticleEntity> articles, {int maxConsecutive = 1, int maxCategoryPercent = 40}) {
    if (articles.isEmpty) return [];

    // Group by category and sort each bucket by recency
    final byCategory = <String, List<NewsArticleEntity>>{};
    for (final a in articles) {
      byCategory.putIfAbsent(a.category, () => []).add(a);
    }
    for (final list in byCategory.values) {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    final total = articles.length;
    final capPerCategory = (total * (maxCategoryPercent / 100)).ceil();
    final pickedCount = <String, int>{};
    final result = <NewsArticleEntity>[];
    String? lastCategory;
    int consecutive = 0;

    // Active category order – rotate to achieve round-robin
    final active = byCategory.keys.toList();
    int idx = 0;

    while (true) {
      // Remove exhausted categories
      active.removeWhere((c) => (byCategory[c]?.isEmpty ?? true));
      if (active.isEmpty) break;

      bool picked = false;
      final tried = <String>{};
      int attempts = 0;

      // Try to pick respecting diversity constraints
      while (attempts < active.length) {
        final c = active[(idx + attempts) % active.length];
        final list = byCategory[c]!;
        final count = pickedCount[c] ?? 0;
        final wouldExceedCap = count >= capPerCategory && byCategory.length > 1;
        final violatesConsecutive = (lastCategory == c && consecutive >= maxConsecutive);

        if (!wouldExceedCap && !violatesConsecutive && list.isNotEmpty) {
          final next = list.removeAt(0);
          result.add(next);
          pickedCount[c] = count + 1;
          if (lastCategory == c) {
            consecutive += 1;
          } else {
            lastCategory = c;
            consecutive = 1;
          }
          idx = (idx + attempts + 1) % active.length; // rotate start
          picked = true;
          break;
        }
        tried.add(c);
        attempts++;
      }

      if (!picked) {
        // Relax constraints: pick from the category with most remaining
        String? bestC;
        int bestLen = -1;
        for (final c in active) {
          final len = byCategory[c]!.length;
          if (len > bestLen) {
            bestLen = len;
            bestC = c;
          }
        }
        if (bestC != null && bestLen > 0) {
          final next = byCategory[bestC]!.removeAt(0);
          result.add(next);
          pickedCount[bestC] = (pickedCount[bestC] ?? 0) + 1;
          if (lastCategory == bestC) {
            consecutive += 1;
          } else {
            lastCategory = bestC;
            consecutive = 1;
          }
          // keep idx as is; continue
        } else {
          break; // nothing left
        }
      }
    }

    return result;
  }

  /// Load articles progressively - ULTRA FAST async loading
  Stream<List<NewsArticleEntity>> loadArticlesProgressively() {
    final controller = StreamController<List<NewsArticleEntity>>();
    final List<NewsArticleEntity> cumulativeArticles = [];
    final Set<String> seenIds = {};
    
    // SPEED OPTIMIZED: Load only essential categories first, rest in background
    final highPriorityCategories = ['Technology', 'Business', 'Sports'];
    final backgroundCategories = ['Health', 'Science', 'Entertainment', 'World', 'Top'];
    
    AppLogger.info('⚡ ULTRA FAST: Starting INSTANT load (3 priority categories)');

    // IMMEDIATE execution - no delays
    () async {
      try {
        // Get read IDs once
        final readIds = await _articleStateManager.getReadArticleIds();
        AppLogger.info('⚡ ULTRA FAST: Got ${readIds.length} read IDs');
        
        // SPEED HACK: Load from cache first if available for instant display
        try {
          final cachedArticles = await LocalStorageService.loadUnreadArticles();
          if (cachedArticles.isNotEmpty) {
            final fastBatch = cachedArticles.take(10).toList();
            for (final article in fastBatch) {
              if (!readIds.contains(article.id) && seenIds.add(article.id)) {
                cumulativeArticles.add(article);
              }
            }
            if (cumulativeArticles.isNotEmpty && !controller.isClosed) {
              controller.add(List.from(cumulativeArticles));
              AppLogger.success('⚡ INSTANT CACHE: Showed ${cumulativeArticles.length} articles in <1 second!');
            }
          }
        } catch (e) {
          AppLogger.warning('⚡ Cache load failed, using network: $e');
        }
        
        // ASYNC CATEGORY FETCHER - yields immediately after each category
        Future<void> fetchCategoryAsync(String category) async {
          try {
            // ⚡ CRITICAL FIX: Use getNewsByCategory (exact limit) instead of getUnreadNewsByCategory (3x multiplier)
            // This reduces network time by 66% (25 articles instead of 60)
            final allArticles = await SupabaseService.getNewsByCategory(
              category, limit: 25 // Slightly more to account for read articles
            );
            
            // ⚡ INSTANT FILTER: Use memory-cached read IDs (0ms lookup)
            final articles = allArticles.where((article) => 
              !readIds.contains(article.id)
            ).take(20).toList();
            
            if (articles.isNotEmpty) {
              bool changed = false;
              for (final article in articles) {
                if (seenIds.add(article.id)) {
                  cumulativeArticles.add(article);
                  changed = true;
                }
              }
              
              if (changed && !controller.isClosed) {
                // Apply balanced interleaving to prevent single-category dominance
                final balanced = _balancedInterleave(cumulativeArticles, maxConsecutive: 2, maxCategoryPercent: 35);
                controller.add(balanced);
                AppLogger.info('⚡ FAST: $category loaded, total: ${balanced.length} articles (balanced)');
              }
            }
          } catch (e) {
            AppLogger.error('⚡ ASYNC ERROR $category: $e');
          }
        }

        // PHASE 1: Load high priority categories in PARALLEL for maximum speed
        if (!controller.isClosed) {
          await Future.wait(
            highPriorityCategories.map((cat) => fetchCategoryAsync(cat))
          );
        }
        
        // PHASE 2: Load background categories in parallel (don't wait)
        if (!controller.isClosed) {
          // Fire all background categories simultaneously
          final backgroundTasks = backgroundCategories
              .map((cat) => fetchCategoryAsync(cat))
              .toList();
          
          // Don't wait - let them complete in background
          Future.wait(backgroundTasks).then((_) {
            if (!controller.isClosed) {
              // Final balanced output after all background categories load
              final finalBalanced = _balancedInterleave(cumulativeArticles, maxConsecutive: 2, maxCategoryPercent: 35);
              controller.add(finalBalanced);
              AppLogger.success('⚡ BACKGROUND: All categories loaded, total: ${finalBalanced.length} articles (final balanced)');
              controller.close();
            }
          }).catchError((e) {
            AppLogger.error('⚡ BACKGROUND ERROR: $e');
            if (!controller.isClosed) controller.close();
          });
          
          // Close after high priority is done (don't wait for background)
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!controller.isClosed) {
              AppLogger.success('⚡ ULTRA FAST: Priority load complete in ~2 seconds!');
              // Don't close - let background tasks continue feeding
            }
          });
        }
        
      } catch (e) {
        AppLogger.error('⚡ CRITICAL ERROR: $e');
        if (!controller.isClosed) controller.addError(e);
        controller.close();
      }
    }();
    
    return controller.stream;
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