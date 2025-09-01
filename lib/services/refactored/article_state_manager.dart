import '../../core/interfaces/article_interface.dart';
import '../../domain/entities/news_article_entity.dart';
import '../read_articles_service.dart';
import '../../utils/app_logger.dart';

/// Article state management service that handles read/unread state
/// This service is responsible for managing article read states
class ArticleStateManager implements IArticleStateManager {
  static final ArticleStateManager _instance = ArticleStateManager._internal();
  factory ArticleStateManager() => _instance;
  ArticleStateManager._internal();

  @override
  Future<void> markAsRead(String articleId) async {
    try {
      await ReadArticlesService.markAsRead(articleId);
      AppLogger.log('ArticleStateManager: Marked article $articleId as read');
    } catch (e) {
      AppLogger.log('ArticleStateManager.markAsRead error: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isArticleRead(String articleId) async {
    try {
      return await ReadArticlesService.isRead(articleId);
    } catch (e) {
      AppLogger.log('ArticleStateManager.isArticleRead error: $e');
      return false;
    }
  }

  @override
  Future<Set<String>> getReadArticleIds() async {
    try {
      final readIds = await ReadArticlesService.getReadArticleIds();
      return readIds.toSet();
    } catch (e) {
      AppLogger.log('ArticleStateManager.getReadArticleIds error: $e');
      return <String>{};
    }
  }

  @override
  Future<int> getReadArticleCount() async {
    try {
      final readIds = await getReadArticleIds();
      return readIds.length;
    } catch (e) {
      AppLogger.log('ArticleStateManager.getReadArticleCount error: $e');
      return 0;
    }
  }

  /// Mark invalid articles as read automatically
  @override
  Future<void> markInvalidArticlesAsRead(List<NewsArticleEntity> invalidArticles) async {
    for (final article in invalidArticles) {
      try {
        await markAsRead(article.id);
        AppLogger.log('Auto-marked as read (invalid): "${article.title}"');
      } catch (e) {
        AppLogger.log('Failed to mark invalid article as read: $e');
      }
    }
  }

  /// Filter out already read articles from a list
  @override
  Future<List<NewsArticleEntity>> filterUnreadArticles(List<NewsArticleEntity> articles) async {
    try {
      final readIds = await getReadArticleIds();
      return articles.where((article) => !readIds.contains(article.id)).toList();
    } catch (e) {
      AppLogger.log('ArticleStateManager.filterUnreadArticles error: $e');
      return articles; // Return all articles if filtering fails
    }
  }
}