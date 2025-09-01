import '../domain/entities/news_article_entity.dart';
import '../services/read_articles_service.dart';
import '../services/news_feed_helper.dart';
import '../services/color_extraction_service.dart';

import '../utils/app_logger.dart';
class ArticleManagementService {
  static Future<void> preloadColors(
    List<NewsArticleEntity> articles, 
    int currentIndex, 
    Map<String, ColorPalette> colorCache
  ) async {
    // Only preload if we have articles and haven't preloaded recently
    if (articles.isEmpty) return;
    
    final startIndex = currentIndex;
    final endIndex = (currentIndex + 5).clamp(0, articles.length); // Reduced from 10 to 5
    
    AppLogger.log('Preloading colors for articles $startIndex to $endIndex');
    
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
    List<NewsArticleEntity> articles,
    int currentIndex,
    String selectedCategory,
    Function loadNewsArticles,
    Function loadArticlesByCategory,
  ) async {
    // Only try to load more if we're actually at the end
    if (currentIndex >= articles.length - 2) {
      AppLogger.log('INFO: Near end of articles, trying to load more...');
      
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
    AppLogger.log('INFO: Loading all other unread articles...');
    
    try {
      // Reset to "All" category and load all unread articles
      setSelectedCategory('All');
      await loadNewsArticles();
    } catch (e) {
      AppLogger.error(': Failed to load other unread articles: $e');
      throw Exception('Failed to load other articles: $e');
    }
  }

  @deprecated
  static Future<List<NewsArticleEntity>> filterValidArticles(List<NewsArticleEntity> articles) async {
    // Delegate to refactored service
    return await NewsFeedHelper.filterValidArticles(articles);
  }

  @deprecated
  static bool hasValidContent(NewsArticleEntity article) {
    // Delegate to refactored service
    return NewsFeedHelper.hasValidContent(article);
  }

  @deprecated
  static bool hasValidImage(String imageUrl) {
    // Delegate to refactored service
    return NewsFeedHelper.hasValidImage(imageUrl);
  }
}