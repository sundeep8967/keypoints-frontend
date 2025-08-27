import '../models/news_article.dart';
import '../services/supabase_service.dart';
import '../services/read_articles_service.dart';
import '../services/news_feed_helper.dart';

import '../utils/app_logger.dart';
class NewsLoadingService {
  static Future<List<NewsArticle>> loadNewsArticles() async {
    try {
      // PRIORITY 1: Try to load from Supabase first
      try {
        final allArticles = await SupabaseService.getNews(limit: 100);
        if (allArticles.isNotEmpty) {
          // Filter out already read articles
          final readIds = await ReadArticlesService.getReadArticleIds();
          final unreadArticles = allArticles.where((article) => 
            !readIds.contains(article.id)
          ).toList();
          
          // Filter out articles with no content and mark them as read
          final validArticles = await NewsFeedHelper.filterValidArticles(unreadArticles);
          
          AppLogger.log('SUCCESS: Loaded ${allArticles.length} total articles, ${unreadArticles.length} unread, ${validArticles.length} valid from Supabase');
          AppLogger.log('INFO: ${readIds.length} articles already read, ${unreadArticles.length - validArticles.length} auto-marked as read (no content)');
          
          return validArticles;
        } else {
          AppLogger.log('WARNING: No articles found in Supabase');
        }
      } catch (e) {
        AppLogger.error(': Supabase failed: $e');
      }

      // No fallback - show error if no Supabase articles
      AppLogger.error(': No articles found in Supabase and no fallback used');
      throw Exception('NO_ARTICLES_IN_DATABASE');
    } catch (e) {
      AppLogger.error(': Failed to load articles: $e');
      return [];
    }
  }

  static Future<List<NewsArticle>> loadArticlesByCategory(String category, {bool isRightSwipe = false}) async {
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
          
          AppLogger.log('SUCCESS: Loaded ${allCategoryArticles.length} total $category articles, ${unreadCategoryArticles.length} unread from Supabase');
          return unreadCategoryArticles;
        }
      } catch (e) {
        AppLogger.error(': Supabase category filter failed: $e');
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
            AppLogger.log('SUCCESS: Filtered ${unreadFilteredArticles.length} unread $category articles from ${filteredArticles.length} total');
            return unreadFilteredArticles;
          }
        }
      } catch (e) {
        AppLogger.error(': Failed to filter Supabase articles: $e');
      }

      AppLogger.error(': Supabase completely unavailable for $category');
      return [];
    } catch (e) {
      AppLogger.error(': Failed to load articles for $category: $e');
      return [];
    }
  }

  static Future<List<NewsArticle>> loadArticlesByCategoryForCache(String category) async {
    try {
      final readIds = await ReadArticlesService.getReadArticleIds();
      
      // Map UI category names to database category names
      String dbCategory = _mapCategoryName(category);
      
      AppLogger.log('=== LOADING CATEGORY: $category ===');
      AppLogger.log('UI Category: "$category" -> DB Category: "$dbCategory"');
      AppLogger.log('Read articles count: ${readIds.length}');
      
      // Use the new method that directly fetches unread articles - get more to ensure enough unread
      final unreadCategoryArticles = await SupabaseService.getUnreadNewsByCategory(dbCategory, readIds, limit: 200);
      AppLogger.log('Found ${unreadCategoryArticles.length} unread articles for "$dbCategory"');
      
      // Debug: Also try the old method to compare
      final allCategoryArticles = await SupabaseService.getNewsByCategory(dbCategory, limit: 100);
      AppLogger.debug(': Total articles in "$dbCategory" category: ${allCategoryArticles.length}');
      
      if (allCategoryArticles.isNotEmpty) {
        final readCount = allCategoryArticles.where((article) => readIds.contains(article.id)).length;
        AppLogger.debug(': $dbCategory breakdown - Total: ${allCategoryArticles.length}, Read: $readCount, Should be unread: ${allCategoryArticles.length - readCount}');
        
        // Show first few article titles for debugging
        AppLogger.debug(': First 3 articles in $dbCategory:');
        for (int i = 0; i < allCategoryArticles.length && i < 3; i++) {
          final article = allCategoryArticles[i];
          final isRead = readIds.contains(article.id);
          AppLogger.log('  ${i+1}. "${article.title}" (ID: ${article.id}) - ${isRead ? "READ" : "UNREAD"}');
        }
      }
      
      // Filter out articles with no content and mark them as read
      final validCategoryArticles = await NewsFeedHelper.filterValidArticles(unreadCategoryArticles);
      AppLogger.log('Filtered to ${validCategoryArticles.length} valid articles for $dbCategory');
      
      if (validCategoryArticles.isNotEmpty) {
        AppLogger.log('Pre-loaded $category: ${validCategoryArticles.length} valid articles available');
      } else {
        AppLogger.log('No unread $category articles found - checking if category exists...');
        // Check if category exists at all by getting a small sample
        final sampleCategoryArticles = await SupabaseService.getNewsByCategory(dbCategory, limit: 5);
        if (sampleCategoryArticles.isNotEmpty) {
          AppLogger.log('$category exists in database but all articles have been read');
        } else {
          AppLogger.log('No $category articles found in database at all');
        }
      }
      
      return validCategoryArticles;
    } catch (e) {
      AppLogger.log('Error pre-loading $category: $e');
      return [];
    }
  }

  static String _mapCategoryName(String category) {
    final categoryMap = {
      'Tech': 'Technology',
      'Entertainment': 'Entertainment',
      'Business': 'Business',
      'Health': 'Health',
      'Sports': 'Sports',
      'Science': 'Science',
      'World': 'World',
      'Top': 'top', // Note: lowercase 'top' in database
      'Travel': 'Travel',
      'Startups': 'Startups',
      'Politics': 'Politics',
      'National': 'National',
      'India': 'India',
      'Education': 'Education',
      'Celebrity': 'Celebrity',
      'Scandal': 'Scandal',
      'Viral': 'Viral',
      'State': 'State',
    };
    
    return categoryMap[category] ?? category;
  }

  static Future<void> debugDatabaseCategories() async {
    try {
      final allArticles = await SupabaseService.getNews(limit: 200);
      final uniqueCategories = allArticles.map((article) => article.category).toSet().toList();
      AppLogger.log('=== DATABASE CATEGORIES FOUND ===');
      for (String cat in uniqueCategories) {
        final count = allArticles.where((a) => a.category == cat).length;
        AppLogger.log('Category: "$cat" - $count articles');
      }
      AppLogger.log('=== END DATABASE CATEGORIES ===');
    } catch (e) {
      AppLogger.log('Error debugging categories: $e');
    }
  }

  static Future<void> showAllSupabaseArticles() async {
    try {
      AppLogger.log('=== FETCHING ALL ARTICLES FROM SUPABASE ===');
      
      // Get all articles (increase limit to see more)
      final allArticles = await SupabaseService.getNews(limit: 200);
      
      AppLogger.log('TOTAL ARTICLES FOUND: ${allArticles.length}');
      AppLogger.log('');
      
      for (int i = 0; i < allArticles.length; i++) {
        final article = allArticles[i];
        
        AppLogger.log('--- ARTICLE ${i + 1} ---');
        AppLogger.log('ID: ${article.id}');
        AppLogger.log('Title: ${article.title}');
        AppLogger.log('Category: ${article.category}');
        AppLogger.log('Published: ${article.timestamp}');
        
        // Check keypoints
        if (article.keypoints != null && article.keypoints!.isNotEmpty) {
          AppLogger.log('Keypoints: ${article.keypoints!.substring(0, article.keypoints!.length > 100 ? 100 : article.keypoints!.length)}...');
        } else {
          AppLogger.log('Keypoints: [NONE]');
        }
        
        // Check description
        if (article.description.isNotEmpty) {
          AppLogger.log('Description: ${article.description.substring(0, article.description.length > 100 ? 100 : article.description.length)}...');
        } else {
          AppLogger.log('Description: [EMPTY]');
        }
        
        // Content validation
        final hasKeypoints = article.keypoints != null && article.keypoints!.trim().isNotEmpty;
        final hasDescription = article.description.trim().isNotEmpty;
        final isValid = hasKeypoints || hasDescription;
        
        AppLogger.log('Content Status: ${isValid ? "VALID" : "INVALID (would be auto-marked as read)"}');
        AppLogger.log('Image URL: ${article.imageUrl}');
        AppLogger.log('');
      }
      
      // Summary
      final validCount = allArticles.where((a) => 
        (a.keypoints != null && a.keypoints!.trim().isNotEmpty) || 
        a.description.trim().isNotEmpty
      ).length;
      
      AppLogger.log('=== SUMMARY ===');
      AppLogger.log('Total Articles: ${allArticles.length}');
      AppLogger.log('Valid Articles: $validCount');
      AppLogger.log('Invalid Articles: ${allArticles.length - validCount}');
      AppLogger.log('=== END ===');
      
    } catch (e) {
      AppLogger.error(' fetching articles: $e');
    }
  }

  static Future<void> showSupabaseCategories() async {
    try {
      AppLogger.log('=== CATEGORIES IN SUPABASE DATABASE ===');
      
      final allArticles = await SupabaseService.getNews(limit: 500);
      final categoryMap = <String, int>{};
      
      // Count articles per category
      for (var article in allArticles) {
        categoryMap[article.category] = (categoryMap[article.category] ?? 0) + 1;
      }
      
      // Sort by count (most articles first)
      final sortedCategories = categoryMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      AppLogger.log('AVAILABLE CATEGORIES (sorted by article count):');
      for (var entry in sortedCategories) {
        AppLogger.log('  "${entry.key}" -> ${entry.value} articles');
      }
      
      AppLogger.log('');
      AppLogger.log('CATEGORY LIST: ${sortedCategories.map((e) => e.key).join(", ")}');
      AppLogger.log('TOTAL CATEGORIES: ${sortedCategories.length}');
      AppLogger.log('=== END CATEGORIES ===');
      
    } catch (e) {
      AppLogger.error(' fetching categories: $e');
    }
  }
}