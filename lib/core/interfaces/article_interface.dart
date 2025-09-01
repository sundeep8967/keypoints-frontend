import '../../domain/entities/news_article_entity.dart';

/// Interface for article-related operations
abstract class IArticleService {
  Future<void> markAsRead(String articleId);
  Future<bool> isArticleRead(String articleId);
  Future<Set<String>> getReadArticleIds();
  Future<int> getReadArticleCount();
  Future<List<NewsArticleEntity>> filterValidArticles(List<NewsArticleEntity> articles);
  bool hasValidContent(NewsArticleEntity article);
  bool hasValidImage(String imageUrl);
}

/// Interface for article validation operations
abstract class IArticleValidator {
  bool hasValidContent(NewsArticleEntity article);
  bool hasValidImage(String imageUrl);
  Future<List<NewsArticleEntity>> filterValidArticles(List<NewsArticleEntity> articles);
  Future<List<NewsArticleEntity>> getInvalidArticles(List<NewsArticleEntity> articles);
}

/// Interface for article state management
abstract class IArticleStateManager {
  Future<void> markAsRead(String articleId);
  Future<bool> isArticleRead(String articleId);
  Future<Set<String>> getReadArticleIds();
  Future<int> getReadArticleCount();
  Future<List<NewsArticleEntity>> filterUnreadArticles(List<NewsArticleEntity> articles);
  Future<void> markInvalidArticlesAsRead(List<NewsArticleEntity> invalidArticles);
}