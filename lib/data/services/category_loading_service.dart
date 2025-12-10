import '../../domain/entities/news_article_entity.dart';
import '../services/supabase_service.dart';
import '../services/read_articles_service.dart';

import '../../core/utils/app_logger.dart';
class CategoryLoadingService {
  static Future<List<NewsArticleEntity>> loadNewsArticlesForCategory(String category) async {
    try {
      final allArticles = await SupabaseService.getNews(limit: 2000);
      if (allArticles.isNotEmpty) {
        final readIds = await ReadArticlesService.getReadArticleIds();
        final unreadArticles = allArticles.where((article) => 
          !readIds.contains(article.id)
        ).toList();
        
        AppLogger.log('Pre-loaded $category: ${unreadArticles.length} articles');
        return unreadArticles;
      }
      return [];
    } catch (e) {
      AppLogger.log('Error pre-loading $category: $e');
      return [];
    }
  }
}