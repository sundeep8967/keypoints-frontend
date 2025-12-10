import '../entities/news_article_entity.dart';

/// Repository interface for category management
/// Handles category discovery, preferences, and category-based content
abstract class ICategoryRepository {
  /// Get all available categories from backend
  Future<List<String>> getAvailableCategories();
  
  /// Get user's preferred categories
  Future<List<String>> getUserPreferredCategories();
  
  /// Save user's category preferences
  Future<void> savePreferredCategories(List<String> categories);
  
  /// Get articles for a specific category
  Future<List<NewsArticleEntity>> getArticlesByCategory(String category);
  
  /// Preload popular categories in background
  Future<void> preloadPopularCategories();
}
