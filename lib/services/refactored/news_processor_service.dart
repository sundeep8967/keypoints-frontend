import '../../core/interfaces/news_interface.dart';
import '../../core/interfaces/article_interface.dart';
import '../../domain/entities/news_article_entity.dart';
import '../../utils/app_logger.dart';
import 'article_validator_service.dart';

/// News processing service that handles article processing without circular dependencies
class NewsProcessorService implements INewsProcessor {
  static final NewsProcessorService _instance = NewsProcessorService._internal();
  factory NewsProcessorService() => _instance;
  NewsProcessorService._internal();

  final IArticleValidator _articleValidator = ArticleValidatorService();

  @override
  Future<List<NewsArticleEntity>> processAndFilterArticles(
    List<NewsArticleEntity> articles, 
    int limit
  ) async {
    try {
      // First, validate articles
      final validArticles = await _articleValidator.filterValidArticles(articles);
      
      // Apply limit
      final limitedArticles = validArticles.take(limit).toList();
      
      AppLogger.log('Processed ${articles.length} articles -> ${validArticles.length} valid -> ${limitedArticles.length} final');
      
      return limitedArticles;
    } catch (e) {
      AppLogger.log('NewsProcessorService.processAndFilterArticles error: $e');
      return [];
    }
  }

  @override
  String detectArticleCategory(NewsArticleEntity article, String selectedCategory) {
    // Try to detect category from article content
    final content = '${article.title} ${article.description}'.toLowerCase();
    
    // Category keywords mapping
    final categoryKeywords = {
      'Technology': ['technology', 'software', 'app', 'digital', 'ai', 'tech', 'startup', 'coding'],
      'Sports': ['football', 'basketball', 'soccer', 'sports', 'game', 'player', 'team', 'match'],
      'Health': ['health', 'medical', 'doctor', 'medicine', 'fitness', 'wellness', 'disease'],
      'Business': ['business', 'company', 'market', 'economy', 'finance', 'stock', 'investment'],
      'Science': ['science', 'research', 'study', 'discovery', 'scientist', 'experiment'],
      'Entertainment': ['movie', 'music', 'celebrity', 'entertainment', 'film', 'actor', 'singer'],
      'World': ['world', 'international', 'global', 'country', 'nation', 'foreign'],
    };
    
    // Check which category has most keyword matches
    String bestCategory = selectedCategory;
    int maxMatches = 0;
    
    for (final entry in categoryKeywords.entries) {
      int matches = 0;
      for (final keyword in entry.value) {
        if (content.contains(keyword)) matches++;
      }
      if (matches > maxMatches) {
        maxMatches = matches;
        bestCategory = entry.key;
      }
    }
    
    return bestCategory;
  }

  @override
  String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  /// Detect states mentioned in articles
  List<String> getDetectedStatesFromArticles(List<NewsArticleEntity> articles) {
    final states = <String>{};
    
    for (final article in articles) {
      final detectedState = _detectStateInContent(article);
      if (detectedState != null) {
        states.add(detectedState);
      }
    }
    
    return states.toList()..sort();
  }

  String? _detectStateInContent(NewsArticleEntity article) {
    final content = '${article.title} ${article.description}'.toLowerCase();
    
    // US States (major ones)
    final usStates = {
      'california': 'California',
      'texas': 'Texas', 
      'florida': 'Florida',
      'new york': 'New York',
      'illinois': 'Illinois',
    };
    
    // Indian States (major ones)
    final indianStates = {
      'maharashtra': 'Maharashtra',
      'uttar pradesh': 'Uttar Pradesh',
      'tamil nadu': 'Tamil Nadu',
      'karnataka': 'Karnataka',
      'delhi': 'Delhi'
    };
    
    final allStates = {...usStates, ...indianStates};
    
    // Check for state mentions in content
    for (final entry in allStates.entries) {
      if (content.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return null;
  }

  /// Category width estimation for scrolling
  double estimateCategoryWidth(String categoryName) {
    // Estimate width based on text length and padding
    const double charWidth = 8.0; // Average character width
    const double horizontalPadding = 24.0; // 12px on each side
    
    // Calculate based on actual text length
    final double textWidth = categoryName.length * charWidth;
    return textWidth + horizontalPadding;
  }
}