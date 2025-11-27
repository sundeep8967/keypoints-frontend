import '../../domain/entities/news_article_entity.dart';

/// Interface for ad management operations
abstract class IAdManager {
  Future<void> initialize();
  Future<List<dynamic>> integrateAdsIntoFeed({
    required List<NewsArticleEntity> articles,
    required String category,
    int maxAds = 999,
  });
  void clearAllAds();
  void dispose();
  Future<void> preloadAdsForCategories(List<String> categories);
  void trackUserReading({
    required int articlesRead,
    required double averageTimePerArticle,
    required String currentCategory,
  });
  Map<String, dynamic> getAdStats();
}