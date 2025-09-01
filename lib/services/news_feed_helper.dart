import '../domain/entities/news_article_entity.dart';
import '../injection_container.dart' as di;
import 'refactored/service_coordinator.dart';

import '../utils/app_logger.dart';

/// Legacy NewsFeedHelper - now delegates to refactored services
/// @deprecated Use ServiceCoordinator instead
class NewsFeedHelper {
  // Article validation functions - now delegates to refactored services
  @deprecated
  static Future<List<NewsArticleEntity>> filterValidArticles(List<NewsArticleEntity> articles) async {
    try {
      final coordinator = di.sl<ServiceCoordinator>();
      final validArticles = await coordinator.articleValidator.filterValidArticles(articles);
      final invalidArticles = await coordinator.articleValidator.getInvalidArticles(articles);
      
      // Mark invalid articles as read
      await coordinator.articleStateManager.markInvalidArticlesAsRead(invalidArticles);
      
      return validArticles;
    } catch (e) {
      AppLogger.log('NewsFeedHelper.filterValidArticles error: $e');
      return articles; // Fallback to original list
    }
  }

  @deprecated
  static bool hasValidContent(NewsArticleEntity article) {
    try {
      final coordinator = di.sl<ServiceCoordinator>();
      return coordinator.articleValidator.hasValidContent(article);
    } catch (e) {
      AppLogger.log('NewsFeedHelper.hasValidContent error: $e');
      return true; // Fallback to valid
    }
  }

  @deprecated
  static bool hasValidImage(String imageUrl) {
    try {
      final coordinator = di.sl<ServiceCoordinator>();
      return coordinator.articleValidator.hasValidImage(imageUrl);
    } catch (e) {
      AppLogger.log('NewsFeedHelper.hasValidImage error: $e');
      return true; // Fallback to valid
    }
  }

  // Time formatting
  static String formatTimestamp(DateTime timestamp) {
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

  // State detection functions
  static List<String> getDetectedStatesFromArticles(List<NewsArticleEntity> articles) {
    final states = <String>{};
    
    // Check current articles for state mentions
    for (final article in articles) {
      final detectedState = detectStateInContent(article);
      if (detectedState != null) {
        states.add(detectedState);
      }
    }
    
    return states.toList()..sort();
  }

  static String? detectStateInContent(NewsArticleEntity article) {
    final content = '${article.title} ${article.description} ${article.description ?? ''}'.toLowerCase();
    
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

  // Category detection
  static String detectArticleCategory(NewsArticleEntity article, String selectedCategory) {
    // Try to detect category from article content
    final content = '${article.title} ${article.description}'.toLowerCase();
    
    // Category keywords mapping
    final categoryKeywords = {
      'Tech': ['technology', 'software', 'app', 'digital', 'ai', 'tech', 'startup', 'coding'],
      'Sports': ['football', 'basketball', 'soccer', 'sports', 'game', 'player', 'team', 'match'],
      'Health': ['health', 'medical', 'doctor', 'medicine', 'fitness', 'wellness', 'disease'],
      'Business': ['business', 'company', 'market', 'economy', 'finance', 'stock', 'investment'],
      'Science': ['science', 'research', 'study', 'discovery', 'scientist', 'experiment'],
      'Entertainment': ['movie', 'music', 'celebrity', 'entertainment', 'film', 'actor', 'singer'],
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

  // Category width estimation for scrolling
  static double estimateCategoryWidth(String categoryName) {
    // Estimate width based on text length and padding
    const double charWidth = 8.0; // Average character width
    const double horizontalPadding = 24.0; // 12px on each side
    
    // Calculate based on actual text length
    final double textWidth = categoryName.length * charWidth;
    return textWidth + horizontalPadding;
  }
}