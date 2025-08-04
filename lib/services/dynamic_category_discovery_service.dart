import '../models/news_article.dart';
import '../services/supabase_service.dart';
import '../services/read_articles_service.dart';

/// Service for dynamically discovering categories from the backend
class DynamicCategoryDiscoveryService {
  
  /// Discover categories by checking what's available in the backend
  /// This runs in parallel and updates the UI as categories are found
  static Future<void> discoverCategoriesInParallel({
    required Function(String category, List<NewsArticle> articles) onCategoryDiscovered,
    required Function(String category) onCategoryEmpty,
    required Function() onDiscoveryComplete,
  }) async {
    print('🔍 DISCOVERY: Starting parallel category discovery...');
    
    // List of potential categories to check
    final potentialCategories = [
      'Technology', 'Business', 'Sports', 'Health', 'Science', 
      'Entertainment', 'World', 'Top', 'Travel', 'Politics', 
      'National', 'India', 'Education', 'Startups', 'Celebrity',
      'Scandal', 'Viral', 'Environment', 'Trending'
    ];
    
    final readIds = await ReadArticlesService.getReadArticleIds();
    
    // Create parallel futures for each category
    final futures = potentialCategories.map((category) async {
      try {
        print('🔍 DISCOVERY: Checking $category...');
        
        // Check if category has articles
        final articles = await SupabaseService.getUnreadNewsByCategory(
          category, 
          readIds, 
          limit: 10 // Small limit for discovery
        );
        
        if (articles.isNotEmpty) {
          print('✅ DISCOVERY: Found $category with ${articles.length} articles');
          onCategoryDiscovered(category, articles);
          return category;
        } else {
          print('❌ DISCOVERY: $category is empty');
          onCategoryEmpty(category);
          return null;
        }
      } catch (e) {
        print('❌ DISCOVERY: Error checking $category: $e');
        onCategoryEmpty(category);
        return null;
      }
    });
    
    // Wait for all discoveries to complete
    final results = await Future.wait(futures);
    final foundCategories = results.where((cat) => cat != null).cast<String>().toList();
    
    print('🎯 DISCOVERY: Complete! Found ${foundCategories.length} categories: $foundCategories');
    onDiscoveryComplete();
  }
  
  /// Discover categories one by one with immediate UI updates
  static Future<void> discoverCategoriesSequentially({
    required Function(String category, List<NewsArticle> articles) onCategoryDiscovered,
    required Function(String category) onCategoryEmpty,
    required Function() onDiscoveryComplete,
  }) async {
    print('🔍 DISCOVERY: Starting sequential category discovery...');
    
    final potentialCategories = [
      'Technology', 'Business', 'Sports', 'Health', 'Science', 
      'Entertainment', 'World', 'Top', 'Travel', 'Politics', 
      'National', 'India', 'Education', 'Startups', 'Celebrity',
      'Scandal', 'Viral', 'Environment', 'Trending'
    ];
    
    final readIds = await ReadArticlesService.getReadArticleIds();
    final foundCategories = <String>[];
    
    for (final category in potentialCategories) {
      try {
        print('🔍 DISCOVERY: Checking $category...');
        
        final articles = await SupabaseService.getUnreadNewsByCategory(
          category, 
          readIds, 
          limit: 10
        );
        
        if (articles.isNotEmpty) {
          print('✅ DISCOVERY: Found $category with ${articles.length} articles');
          foundCategories.add(category);
          onCategoryDiscovered(category, articles);
          
          // Small delay to show progressive discovery
          await Future.delayed(const Duration(milliseconds: 100));
        } else {
          print('❌ DISCOVERY: $category is empty');
          onCategoryEmpty(category);
        }
      } catch (e) {
        print('❌ DISCOVERY: Error checking $category: $e');
        onCategoryEmpty(category);
      }
    }
    
    print('🎯 DISCOVERY: Complete! Found ${foundCategories.length} categories: $foundCategories');
    onDiscoveryComplete();
  }
  
  /// Get a UI-friendly category name from database category name
  static String getUIFriendlyName(String dbCategory) {
    switch (dbCategory) {
      case 'Technology': return 'Tech';
      case 'Entertainment': return 'Entertainment';
      case 'Business': return 'Business';
      case 'Health': return 'Health';
      case 'Sports': return 'Sports';
      case 'Science': return 'Science';
      case 'World': return 'World';
      case 'Top': return 'Top';
      case 'Travel': return 'Travel';
      case 'Politics': return 'Politics';
      case 'National': return 'National';
      case 'India': return 'India';
      case 'Education': return 'Education';
      case 'Startups': return 'Startups';
      case 'Celebrity': return 'Celebrity';
      case 'Scandal': return 'Scandal';
      case 'Viral': return 'Viral';
      case 'Environment': return 'Environment';
      case 'Trending': return 'Trending';
      default: return dbCategory;
    }
  }
  
  /// Check if a specific category exists in the backend
  static Future<bool> doesCategoryExist(String category) async {
    try {
      final articles = await SupabaseService.getNewsByCategory(category, limit: 1);
      return articles.isNotEmpty;
    } catch (e) {
      print('Error checking category $category: $e');
      return false;
    }
  }
}