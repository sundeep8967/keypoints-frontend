import '../models/news_article.dart';
import '../services/supabase_service.dart';
import '../services/read_articles_service.dart';
import '../services/news_feed_helper.dart';
import '../services/color_extraction_service.dart';

class ArticleManagementService {
  static Future<void> preloadColors(
    List<NewsArticle> articles, 
    int currentIndex, 
    Map<String, ColorPalette> colorCache
  ) async {
    // Only preload if we have articles and haven't preloaded recently
    if (articles.isEmpty) return;
    
    final startIndex = currentIndex;
    final endIndex = (currentIndex + 5).clamp(0, articles.length); // Reduced from 10 to 5
    
    print('Preloading colors for articles $startIndex to $endIndex');
    
    for (int i = startIndex; i < endIndex; i++) {
      if (i < articles.length && !colorCache.containsKey(articles[i].imageUrl)) {
        try {
          final palette = await ColorExtractionService.extractColorsFromImage(articles[i].imageUrl);
          colorCache[articles[i].imageUrl] = palette;
        } catch (e) {
          colorCache[articles[i].imageUrl] = ColorPalette.defaultPalette();
        }
      }
    }
  }

  static Future<void> tryLoadMoreArticles(
    List<NewsArticle> articles,
    int currentIndex,
    String selectedCategory,
    Function loadNewsArticles,
    Function loadArticlesByCategory,
  ) async {
    // Only try to load more if we're actually at the end
    if (currentIndex >= articles.length - 2) {
      print('INFO: Near end of articles, trying to load more...');
      
      if (selectedCategory == 'All') {
        await loadNewsArticles();
      } else {
        await loadArticlesByCategory(selectedCategory);
      }
    }
  }

  static Future<void> loadAllOtherUnreadArticles(
    Function setSelectedCategory,
    Function loadNewsArticles,
  ) async {
    print('INFO: Loading all other unread articles...');
    
    try {
      // Reset to "All" category and load all unread articles
      setSelectedCategory('All');
      await loadNewsArticles();
    } catch (e) {
      print('ERROR: Failed to load other unread articles: $e');
      throw Exception('Failed to load other articles: $e');
    }
  }

  static Future<List<NewsArticle>> filterValidArticles(List<NewsArticle> articles) async {
    final validArticles = <NewsArticle>[];
    final invalidArticles = <NewsArticle>[];
    
    for (final article in articles) {
      if (NewsFeedHelper.hasValidContent(article)) {
        validArticles.add(article);
      } else {
        invalidArticles.add(article);
        // Mark invalid articles as read automatically
        await ReadArticlesService.markAsRead(article.id);
        
        print('Auto-marked as read (no content): "${article.title}"');
      }
    }
    
    if (invalidArticles.isNotEmpty) {
      print('Filtered out ${invalidArticles.length} articles with no content');
    }
    
    return validArticles;
  }

  static bool hasValidContent(NewsArticle article) {
    // Check if article has valid image URL
    if (!hasValidImage(article.imageUrl)) {
      print('Invalid image for article: "${article.title}" - URL: "${article.imageUrl}"');
      return false;
    }
    
    // Check if article has keypoints
    if (article.keypoints != null && article.keypoints!.trim().isNotEmpty) {
      return true;
    }
    
    // Check if article has description/summary
    if (article.description.trim().isNotEmpty) {
      return true;
    }
    
    // No valid content found
    return false;
  }

  static bool hasValidImage(String imageUrl) {
    // Check if image URL is not empty
    if (imageUrl.trim().isEmpty) {
      return false;
    }
    
    // Check if it's a valid URL format
    try {
      final uri = Uri.parse(imageUrl);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        return false;
      }
    } catch (e) {
      return false;
    }
    
    // Check if URL ends with common image extensions
    final lowercaseUrl = imageUrl.toLowerCase();
    
    // Allow URLs without extensions (many news sites use dynamic image URLs)
    // But reject obviously invalid ones
    if (lowercaseUrl.contains('placeholder') || 
        lowercaseUrl.contains('default') ||
        lowercaseUrl.contains('no-image') ||
        lowercaseUrl.contains('missing')) {
      return false;
    }
    
    return true;
  }
}