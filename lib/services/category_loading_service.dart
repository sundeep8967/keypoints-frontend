import '../models/news_article.dart';
import '../services/supabase_service.dart';
import '../services/read_articles_service.dart';

class CategoryLoadingService {
  static Future<List<NewsArticle>> loadNewsArticlesForCategory(String category) async {
    try {
      final allArticles = await SupabaseService.getNews(limit: 100);
      if (allArticles.isNotEmpty) {
        final readIds = await ReadArticlesService.getReadArticleIds();
        final unreadArticles = allArticles.where((article) => 
          !readIds.contains(article.id)
        ).toList();
        
        print('Pre-loaded $category: ${unreadArticles.length} articles');
        return unreadArticles;
      }
      return [];
    } catch (e) {
      print('Error pre-loading $category: $e');
      return [];
    }
  }

  static Future<List<NewsArticle>> loadArticlesByCategoryWithSwipeContext(
    String category, 
    bool isRightSwipe,
    Function showToast,
    Function loadAllOtherUnreadArticles,
  ) async {
    try {
      // Get read articles to filter them out
      final readIds = await ReadArticlesService.getReadArticleIds();

      // PRIORITY 1: Try Supabase category filter
      try {
        final allCategoryArticles = await SupabaseService.getNewsByCategory(category, limit: 100);
        if (allCategoryArticles.isNotEmpty) {
          final unreadCategoryArticles = allCategoryArticles.where((article) => 
            !readIds.contains(article.id)
          ).toList();
          
          if (unreadCategoryArticles.isEmpty) {
            if (isRightSwipe) {
              // Right swipe: Just show "You read all" in UI, no popup
              throw Exception('You have read all articles in $category category.');
            } else {
              // Left swipe: Show toast and load all other unread articles
              showToast('You have read all articles in $category category');
              await loadAllOtherUnreadArticles();
              return [];
            }
          }
          
          print('SUCCESS: Loaded ${allCategoryArticles.length} total $category articles, ${unreadCategoryArticles.length} unread from Supabase');
          return unreadCategoryArticles;
        }
      } catch (e) {
        print('ERROR: Supabase category filter failed: $e');
      }

      // PRIORITY 2: Try filtering all Supabase articles locally
      try {
        final allSupabaseArticles = await SupabaseService.getNews(limit: 100);
        if (allSupabaseArticles.isNotEmpty) {
          final filteredArticles = allSupabaseArticles.where((article) => 
            article.category.toLowerCase() == category.toLowerCase()
          ).toList();
          
          final unreadFilteredArticles = filteredArticles.where((article) => 
            !readIds.contains(article.id)
          ).toList();
          
          if (unreadFilteredArticles.isNotEmpty) {
            print('SUCCESS: Filtered ${unreadFilteredArticles.length} unread $category articles from ${filteredArticles.length} total');
            return unreadFilteredArticles;
          } else if (filteredArticles.isNotEmpty) {
            if (isRightSwipe) {
              // Right swipe: Just show "You read all" in UI, no popup
              throw Exception('You have read all articles in $category category.');
            } else {
              // Left swipe: Show toast and load all other unread articles
              showToast('You have read all articles in $category category');
              await loadAllOtherUnreadArticles();
              return [];
            }
          } else {
            if (isRightSwipe) {
              // Right swipe: Just show "No articles" in UI, no popup
              throw Exception('No $category articles found.');
            } else {
              // Left swipe: Show toast and switch back to All category
              showToast('No $category articles found. Switching back to All categories.');
              return [];
            }
          }
        }
      } catch (e) {
        print('ERROR: Failed to filter Supabase articles: $e');
      }

      // PRIORITY 3: If Supabase completely fails
      if (isRightSwipe) {
        // Right swipe: Just show error in UI, no popup
        throw Exception('Unable to load $category articles.');
      } else {
        // Left swipe: Show toast and prepare to switch back to All
        showToast('Unable to load $category articles. Switching back to All categories.');
        return [];
      }
    } catch (e) {
      if (e.toString().contains('You have read all articles') || 
          e.toString().contains('No $category articles found') ||
          e.toString().contains('Unable to load $category articles')) {
        rethrow;
      }
      throw Exception('Failed to load articles for $category: $e');
    }
  }

  static Future<List<NewsArticle>> loadArticlesByCategory(
    String category,
    Function showToast,
    Function loadAllOtherUnreadArticles,
  ) async {
    try {
      // Get read articles to filter them out
      final readIds = await ReadArticlesService.getReadArticleIds();

      // PRIORITY 1: Try Supabase category filter
      try {
        final allCategoryArticles = await SupabaseService.getNewsByCategory(category, limit: 100);
        if (allCategoryArticles.isNotEmpty) {
          final unreadCategoryArticles = allCategoryArticles.where((article) => 
            !readIds.contains(article.id)
          ).toList();
          
          if (unreadCategoryArticles.isEmpty) {
            // Show toast and load all other unread articles
            showToast('You have read all articles in $category category');
            await loadAllOtherUnreadArticles();
            return [];
          }
          
          print('SUCCESS: Loaded ${allCategoryArticles.length} total $category articles, ${unreadCategoryArticles.length} unread from Supabase');
          return unreadCategoryArticles;
        }
      } catch (e) {
        print('ERROR: Supabase category filter failed: $e');
      }

      // PRIORITY 2: Try filtering all Supabase articles locally
      try {
        final allSupabaseArticles = await SupabaseService.getNews(limit: 100);
        if (allSupabaseArticles.isNotEmpty) {
          final filteredArticles = allSupabaseArticles.where((article) => 
            article.category.toLowerCase() == category.toLowerCase()
          ).toList();
          
          final unreadFilteredArticles = filteredArticles.where((article) => 
            !readIds.contains(article.id)
          ).toList();
          
          if (unreadFilteredArticles.isNotEmpty) {
            print('SUCCESS: Filtered ${unreadFilteredArticles.length} unread $category articles from ${filteredArticles.length} total');
            return unreadFilteredArticles;
          } else if (filteredArticles.isNotEmpty) {
            // Show toast and load all other unread articles
            showToast('You have read all articles in $category category');
            await loadAllOtherUnreadArticles();
            return [];
          } else {
            // Show toast and switch back to All category
            showToast('No $category articles found. Switching back to All categories.');
            return [];
          }
        }
      } catch (e) {
        print('ERROR: Failed to filter Supabase articles: $e');
      }

      // PRIORITY 3: If Supabase completely fails, show toast and prepare to switch back to All
      showToast('Unable to load $category articles. Switching back to All categories.');
      print('ERROR: Supabase completely unavailable for $category');
      return [];
    } catch (e) {
      throw Exception('Failed to load articles for $category: $e');
    }
  }
}