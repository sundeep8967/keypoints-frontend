import '../models/news_article.dart';
import '../services/read_articles_service.dart';

class NewsFeedHelper {
  // Article validation functions
  static Future<List<NewsArticle>> filterValidArticles(List<NewsArticle> articles) async {
    final validArticles = <NewsArticle>[];
    final invalidArticles = <NewsArticle>[];
    
    for (final article in articles) {
      if (hasValidContent(article)) {
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
    
    // If URL has query parameters, check before the '?'
    // final urlWithoutQuery = lowercaseUrl.split('?')[0]; // Not used currently
    
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
  static List<String> getDetectedStatesFromArticles(List<NewsArticle> articles) {
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

  static String? detectStateInContent(NewsArticle article) {
    final content = '${article.title} ${article.description} ${article.keypoints ?? ''}'.toLowerCase();
    
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
  static String detectArticleCategory(NewsArticle article, String selectedCategory) {
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