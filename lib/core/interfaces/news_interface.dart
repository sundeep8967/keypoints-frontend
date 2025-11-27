import '../../domain/entities/news_article_entity.dart';

/// Interface for news loading operations
abstract class INewsLoader {
  Future<List<NewsArticleEntity>> loadNewsArticles({int limit});
  Future<List<NewsArticleEntity>> loadArticlesByCategory(String category, {bool isRightSwipe});
  Future<List<NewsArticleEntity>> refreshNews();
  Future<List<NewsArticleEntity>> loadRandomMixArticles();
  Stream<List<NewsArticleEntity>> loadArticlesProgressively();
}

/// Interface for news data source operations
abstract class INewsDataSource {
  Future<List<NewsArticleEntity>> getNews({int limit});
  Future<List<NewsArticleEntity>> getNewsByCategory(String category, {int limit});
  Future<List<NewsArticleEntity>> searchNews(String query);
}

/// Interface for news processing operations
abstract class INewsProcessor {
  Future<List<NewsArticleEntity>> processAndFilterArticles(
    List<NewsArticleEntity> articles, 
    int limit
  );
  String detectArticleCategory(NewsArticleEntity article, String selectedCategory);
  String formatTimestamp(DateTime timestamp);
  double estimateCategoryWidth(String categoryName);
}