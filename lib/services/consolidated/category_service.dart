import 'package:flutter/cupertino.dart';
import '../../models/news_article.dart';
import '../local_storage_service.dart';
import '../category_scroll_service.dart';
import 'news_service.dart';

/// Consolidated service that merges:
/// - category_loading_service.dart
/// - category_management_service.dart
/// - category_preference_service.dart
class CategoryService {
  static const List<String> _baseCategories = [
    'All', 'Technology', 'Business', 'Sports', 'Entertainment', 
    'Health', 'Science', 'World'
  ];

  static const List<String> _popularCategories = [
    'Technology', 'Business', 'Sports', 'Entertainment'
  ];

  // Cache for category articles
  static final Map<String, List<NewsArticle>> _categoryCache = {};
  static final Map<String, bool> _categoryLoading = {};
  static final Map<String, DateTime> _categoryLastLoaded = {};

  /// Get all available categories
  static List<String> getAllCategories() {
    return List.from(_baseCategories);
  }

  /// Get popular categories for quick access
  static List<String> getPopularCategories() {
    return List.from(_popularCategories);
  }

  /// Get user's preferred categories
  static Future<List<String>> getUserPreferredCategories() async {
    try {
      final preferences = await LocalStorageService.getCategoryPreferences();
      return preferences.isNotEmpty ? preferences : _popularCategories;
    } catch (e) {
      print('CategoryService.getUserPreferredCategories error: $e');
      return _popularCategories;
    }
  }

  /// Save user's category preferences
  static Future<void> saveUserPreferences(List<String> categories) async {
    try {
      await LocalStorageService.setCategoryPreferences(categories);
      print('CategoryService: Saved ${categories.length} category preferences');
    } catch (e) {
      print('CategoryService.saveUserPreferences error: $e');
      rethrow;
    }
  }

  /// Load articles for a specific category with caching
  static Future<List<NewsArticle>> loadCategoryArticles(
    String category, {
    bool forceRefresh = false,
    int limit = 50,
  }) async {
    try {
      // Check cache first (unless force refresh)
      if (!forceRefresh && _categoryCache.containsKey(category)) {
        final cachedArticles = _categoryCache[category]!;
        final lastLoaded = _categoryLastLoaded[category];
        
        // Use cache if it's less than 10 minutes old and has articles
        if (lastLoaded != null && 
            DateTime.now().difference(lastLoaded).inMinutes < 10 &&
            cachedArticles.isNotEmpty) {
          print('CategoryService: Using cached $category articles (${cachedArticles.length})');
          return cachedArticles;
        }
      }

      // Set loading state
      _categoryLoading[category] = true;

      List<NewsArticle> articles;
      if (category == 'All') {
        articles = await NewsService.loadRandomMixArticles(limit: limit);
      } else {
        articles = await NewsService.loadNewsByCategory(category, limit: limit);
      }

      // Update cache
      _categoryCache[category] = articles;
      _categoryLastLoaded[category] = DateTime.now();
      _categoryLoading[category] = false;

      print('CategoryService: Loaded ${articles.length} articles for $category');
      return articles;

    } catch (e) {
      _categoryLoading[category] = false;
      print('CategoryService.loadCategoryArticles error for $category: $e');
      rethrow;
    }
  }

  /// Preload popular categories in background
  static Future<void> preloadPopularCategories() async {
    try {
      final categories = await getUserPreferredCategories();
      
      for (final category in categories) {
        if (!_categoryCache.containsKey(category) || 
            _categoryCache[category]!.isEmpty) {
          
          // Load in background without blocking
          loadCategoryArticles(category).catchError((e) {
            print('Background preload failed for $category: $e');
            return <NewsArticle>[];
          });
          
          // Small delay between requests
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
    } catch (e) {
      print('CategoryService.preloadPopularCategories error: $e');
    }
  }

  /// Check if category is currently loading
  static bool isCategoryLoading(String category) {
    return _categoryLoading[category] ?? false;
  }

  /// Get cached article count for category
  static int getCachedArticleCount(String category) {
    return _categoryCache[category]?.length ?? 0;
  }

  /// Clear cache for specific category
  static void clearCategoryCache(String category) {
    _categoryCache.remove(category);
    _categoryLastLoaded.remove(category);
    _categoryLoading.remove(category);
  }

  /// Clear all category caches
  static void clearAllCaches() {
    _categoryCache.clear();
    _categoryLastLoaded.clear();
    _categoryLoading.clear();
  }

  /// Get category display name (for UI)
  static String getCategoryDisplayName(String category) {
    switch (category.toLowerCase()) {
      case 'tech':
      case 'technology':
        return 'Technology';
      case 'sports':
        return 'Sports';
      case 'business':
        return 'Business';
      case 'entertainment':
        return 'Entertainment';
      case 'health':
        return 'Health';
      case 'science':
        return 'Science';
      case 'world':
        return 'World';
      case 'all':
        return 'All';
      default:
        return category;
    }
  }

  /// Scroll to selected category in horizontal list
  static void scrollToCategory(
    BuildContext context,
    ScrollController scrollController,
    int categoryIndex,
    List<String> categories,
  ) {
    try {
      CategoryScrollService.scrollToSelectedCategoryAccurate(
        context, scrollController, categoryIndex, categories);
    } catch (e) {
      print('CategoryService.scrollToCategory error: $e');
    }
  }

  /// Get category statistics
  static Map<String, dynamic> getCategoryStats() {
    final stats = <String, dynamic>{};
    
    for (final category in _categoryCache.keys) {
      stats[category] = {
        'articleCount': _categoryCache[category]?.length ?? 0,
        'isLoading': _categoryLoading[category] ?? false,
        'lastLoaded': _categoryLastLoaded[category]?.toIso8601String(),
      };
    }
    
    return stats;
  }

  /// Initialize categories with empty caches
  static void initializeCategories() {
    for (final category in _baseCategories) {
      if (!_categoryCache.containsKey(category)) {
        _categoryCache[category] = [];
        _categoryLoading[category] = false;
      }
    }
  }
}