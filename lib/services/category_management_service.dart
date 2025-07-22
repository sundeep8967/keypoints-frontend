import '../models/news_article.dart';
import '../services/news_loading_service.dart';

class CategoryManagementService {
  static void preloadCategoryIfNeeded(
    String category,
    Map<String, List<NewsArticle>> categoryArticles,
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
    Map<String, List<NewsArticle>> categoryArticles,
    Map<String, bool> categoryLoading,
    Function(String) loadArticlesByCategoryForCache,
    Function() loadNewsArticlesForCategory,
  ) {
    // First, let's see what categories exist in the database
    NewsLoadingService.debugDatabaseCategories();
    
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
    Map<String, List<NewsArticle>> categoryArticles,
    Function(String) loadArticlesByCategoryForCache,
  ) {
    Future.delayed(const Duration(milliseconds: 1000), () async {
      for (String category in popularCategories) {
        if (categoryArticles[category]?.isEmpty != false) {
          print('Pre-loading popular category: $category');
          await loadArticlesByCategoryForCache(category);
          await Future.delayed(const Duration(milliseconds: 300)); // Small delay between loads
        }
      }
      print('Popular categories pre-loaded successfully');
    });
  }

  static void initializeCategories(
    List<String> categories,
    Map<String, List<NewsArticle>> categoryArticles,
    Map<String, bool> categoryLoading,
  ) {
    // Pre-load all categories
    for (String category in categories) {
      categoryArticles[category] = [];
      categoryLoading[category] = false;
    }
  }
}