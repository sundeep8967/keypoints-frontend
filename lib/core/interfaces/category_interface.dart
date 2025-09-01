import '../../domain/entities/news_article_entity.dart';

/// Interface for category management operations
abstract class ICategoryManager {
  List<String> getAllCategories();
  List<String> getPopularCategories();
  Future<List<String>> getUserPreferredCategories();
  Future<void> saveUserPreferences(List<String> categories);
  Future<List<NewsArticleEntity>> loadCategoryArticles(String category);
  Future<void> preloadPopularCategories();
}

/// Interface for category loading operations
abstract class ICategoryLoader {
  Future<List<NewsArticleEntity>> loadCategoryArticles(String category);
  Future<void> preloadPopularCategories();
  Future<void> initializeCategories();
}

/// Interface for category scroll operations
abstract class ICategoryScrollManager {
  double estimateCategoryWidth(String categoryName);
  Future<void> scrollToCategory(String category, int index);
  void updateScrollPosition(double position);
}

/// Interface for category preferences
abstract class ICategoryPreferences {
  Future<List<String>> getUserPreferredCategories();
  Future<void> saveUserPreferences(List<String> categories);
  Future<void> addCategoryPreference(String category);
  Future<void> removeCategoryPreference(String category);
}