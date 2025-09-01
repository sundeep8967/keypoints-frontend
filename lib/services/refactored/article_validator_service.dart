import '../../core/interfaces/article_interface.dart';
import '../../domain/entities/news_article_entity.dart';
import '../../utils/app_logger.dart';

/// Pure article validation service without dependencies on other services
/// This breaks the circular dependency by not depending on ReadArticlesService
class ArticleValidatorService implements IArticleValidator {
  static final ArticleValidatorService _instance = ArticleValidatorService._internal();
  factory ArticleValidatorService() => _instance;
  ArticleValidatorService._internal();

  @override
  bool hasValidContent(NewsArticleEntity article) {
    // Check if article has title
    if (article.title.trim().isEmpty) {
      AppLogger.log('Invalid article: no title');
      return false;
    }
    
    // Check if article has description/summary
    if (article.description.trim().isEmpty) {
      AppLogger.log('Invalid article: no description - "${article.title}"');
      return false;
    }
    
    // Check if article has valid image URL
    if (!hasValidImage(article.imageUrl)) {
      AppLogger.log('Invalid article: no valid image URL - "${article.title}"');
      return false;
    }
    
    return true;
  }

  @override
  bool hasValidImage(String imageUrl) {
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
    
    // Check if URL contains obviously invalid patterns
    final lowercaseUrl = imageUrl.toLowerCase();
    if (lowercaseUrl.contains('placeholder') || 
        lowercaseUrl.contains('default') ||
        lowercaseUrl.contains('no-image') ||
        lowercaseUrl.contains('missing')) {
      return false;
    }
    
    return true;
  }

  @override
  Future<List<NewsArticleEntity>> filterValidArticles(List<NewsArticleEntity> articles) async {
    final validArticles = <NewsArticleEntity>[];
    final invalidArticles = <NewsArticleEntity>[];
    
    for (final article in articles) {
      if (hasValidContent(article)) {
        validArticles.add(article);
      } else {
        invalidArticles.add(article);
        AppLogger.log('Invalid article filtered: "${article.title}"');
      }
    }
    
    if (invalidArticles.isNotEmpty) {
      AppLogger.log('Filtered out ${invalidArticles.length} articles with invalid content');
    }
    
    return validArticles;
  }

  /// Get list of invalid articles for external processing
  @override
  Future<List<NewsArticleEntity>> getInvalidArticles(List<NewsArticleEntity> articles) async {
    final invalidArticles = <NewsArticleEntity>[];
    
    for (final article in articles) {
      if (!hasValidContent(article)) {
        invalidArticles.add(article);
      }
    }
    
    return invalidArticles;
  }
}