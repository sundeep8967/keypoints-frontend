import '../domain/entities/news_article_entity.dart';
import '../injection_container.dart' as di;
import 'refactored/service_coordinator.dart';

import '../utils/app_logger.dart';

/// Legacy CategoryManagementService - now delegates to refactored services
/// @deprecated Use ServiceCoordinator instead
class CategoryManagementService {
  static void preloadCategoryIfNeeded(
    String category,
    Map<String, List<NewsArticleEntity>> categoryArticles,
    Map<String, bool> categoryLoading,
    Function(String) loadArticlesByCategoryForCache,
    Function() loadNewsArticlesForCategory,
  ) {
    if (categoryArticles[category]?.isEmpty == true && categoryLoading[category] != true) {
      categoryLoading[category] = true;
      
      if (category == 'All') {
        loadNewsArticlesForCategory();
      } else {
        loadArticlesByCategoryForCache(category);
      }
    }
  }

  static void preloadAllCategories(
    List<String> categories,
    Map<String, List<NewsArticleEntity>> categoryArticles,
    Map<String, bool> categoryLoading,
    Function(String) loadArticlesByCategoryForCache,
    Function() loadNewsArticlesForCategory,
  ) {
    // Delegate to refactored service for database debugging
    _debugDatabaseCategoriesAsync();
    
    // Pre-load all categories in background
    for (String category in categories) {
      preloadCategoryIfNeeded(
        category, 
        categoryArticles, 
        categoryLoading, 
        loadArticlesByCategoryForCache, 
        loadNewsArticlesForCategory
      );
    }
  }

  static void preloadPopularCategories(
    List<String> popularCategories,
    Map<String, List<NewsArticleEntity>> categoryArticles,
    Function(String) loadArticlesByCategoryForCache,
  ) {
    Future.delayed(const Duration(milliseconds: 1000), () async {
      for (String category in popularCategories) {
        if (categoryArticles[category]?.isEmpty != false) {
          AppLogger.log('Pre-loading popular category: $category');
          await loadArticlesByCategoryForCache(category);
          await Future.delayed(const Duration(milliseconds: 300)); // Small delay between loads
        }
      }
      AppLogger.log('Popular categories pre-loaded successfully');
    });
  }

  static void initializeCategories(
    List<String> categories,
    Map<String, List<NewsArticleEntity>> categoryArticles,
    Map<String, bool> categoryLoading,
  ) {
    // Pre-load all categories
    for (String category in categories) {
      categoryArticles[category] = [];
      categoryLoading[category] = false;
    }
  }

  /// Helper method to debug database categories asynchronously
  static void _debugDatabaseCategoriesAsync() {
    Future.microtask(() async {
      try {
        final coordinator = di.sl<ServiceCoordinator>();
        await (coordinator.newsLoader as dynamic).debugDatabaseCategories();
      } catch (e) {
        AppLogger.log('CategoryManagementService: Debug categories error: $e');
      }
    });
  }
}