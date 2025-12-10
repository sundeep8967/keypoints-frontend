import '../entities/news_article_entity.dart';

/// Repository interface for article data access
/// Provides clean abstraction over article data sources
abstract class IArticleRepository {
  /// Get unread articles, optionally filtered by category
  Future<List<NewsArticleEntity>> getUnreadArticles({String? category});
  
  /// Load more articles for infinite scroll
  Future<List<NewsArticleEntity>> loadMoreArticles({
    required String category,
    required List<NewsArticleEntity> currentArticles,
  });
  
  /// Mark an article as read
  Future<void> markAsRead(String articleId);
  
  /// Get set of all read article IDs
  Future<Set<String>> getReadArticleIds();
  
  /// Cache articles to local storage
  Future<void> cacheArticles(List<NewsArticleEntity> articles);
  
  /// Load articles from cache
  Future<List<NewsArticleEntity>> loadCachedArticles();
}
