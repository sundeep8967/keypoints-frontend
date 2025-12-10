import '../../domain/entities/news_article_entity.dart';
import '../../domain/repositories/i_article_repository.dart';
import '../services/supabase_service.dart';
import '../services/read_articles_service.dart';
import '../services/infinite_scroll_service.dart';
import '../services/mixed_category_feed_service.dart';
import '../services/local_storage_service.dart';

/// Article repository implementation
/// Wraps existing services to provide clean data access layer
class ArticleRepository implements IArticleRepository {
  final SupabaseService _supabaseService;
  final ReadArticlesService _readArticlesService;

  ArticleRepository({
    required SupabaseService supabaseService,
    required ReadArticlesService readArticlesService,
  })  : _supabaseService = supabaseService,
        _readArticlesService = readArticlesService;

  @override
  Future<List<NewsArticleEntity>> getUnreadArticles({String? category}) async {
    final readIds = await getReadArticleIds();
    
    if (category == null || category == 'All') {
      // Get mixed feed from multiple categories!
      return await MixedCategoryFeedService.createMixedFeed(
        articlesPerCategory: 20,
      );
    } else {
      // Get articles for specific category
      return await SupabaseService.getUnreadNewsByCategory(category, readIds.toList(), limit: 100);
    }
  }

  @override
  Future<List<NewsArticleEntity>> loadMoreArticles({
    required String category,
    required List<NewsArticleEntity> currentArticles,
  }) async {
    final readIds = await getReadArticleIds();
    
    return await InfiniteScrollService.loadMoreArticlesEnhanced(
      category: category,
      currentArticles: currentArticles,
      readIds: readIds.toList(),
    );
  }

  @override
  Future<void> markAsRead(String articleId) async {
    await ReadArticlesService.markAsRead(articleId);
  }

  @override
  Future<Set<String>> getReadArticleIds() async {
    return await ReadArticlesService.getReadArticleIds();
  }

  @override
  Future<void> cacheArticles(List<NewsArticleEntity> articles) async {
    await LocalStorageService.saveArticles(articles);
  }

  @override
  Future<List<NewsArticleEntity>> loadCachedArticles() async {
    return await LocalStorageService.loadUnreadArticles();
  }
}
