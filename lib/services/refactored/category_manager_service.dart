import '../../core/interfaces/category_interface.dart';
import '../../core/interfaces/news_interface.dart';
import '../../domain/entities/news_article_entity.dart';
import '../local_storage_service.dart';
import 'news_loader_service.dart';
import '../../utils/app_logger.dart';

/// Category management service that implements ICategoryManager without circular dependencies
class CategoryManagerService implements ICategoryManager, ICategoryLoader, ICategoryPreferences {
  static final CategoryManagerService _instance = CategoryManagerService._internal();
  factory CategoryManagerService() => _instance;
  CategoryManagerService._internal();

  final INewsLoader _newsLoader = NewsLoaderService();

  static const List<String> _baseCategories = [
    'All', 'Technology', 'Business', 'Sports', 'Entertainment', 
    'Health', 'Science', 'World'
  ];

  static const List<String> _popularCategories = [
    'Technology', 'Business', 'Sports', 'Entertainment'
  ];

  // Cache for category articles
  final Map<String, List<NewsArticleEntity>> _categoryCache = {};
  final Map<String, bool> _categoryLoading = {};
  final Map<String, DateTime> _categoryLastLoaded = {};

  @override
  List<String> getAllCategories() {
    return List.from(_baseCategories);
  }

  @override
  List<String> getPopularCategories() {
    return List.from(_popularCategories);
  }

  @override
  Future<List<String>> getUserPreferredCategories() async {
    try {
      final preferences = await LocalStorageService.getCategoryPreferences();
      return preferences.isNotEmpty ? preferences : _popularCategories;
    } catch (e) {
      AppLogger.log('CategoryManagerService.getUserPreferredCategories error: $e');
      return _popularCategories;
    }
  }

  @override
  Future<void> saveUserPreferences(List<String> categories) async {
    try {
      await LocalStorageService.setCategoryPreferences(categories);
      AppLogger.log('CategoryManagerService: Saved user preferences: $categories');
    } catch (e) {
      AppLogger.log('CategoryManagerService.saveUserPreferences error: $e');
      rethrow;
    }
  }

  @override
  Future<void> addCategoryPreference(String category) async {
    try {
      final currentPreferences = await getUserPreferredCategories();
      if (!currentPreferences.contains(category)) {
        currentPreferences.add(category);
        await saveUserPreferences(currentPreferences);
      }
    } catch (e) {
      AppLogger.log('CategoryManagerService.addCategoryPreference error: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeCategoryPreference(String category) async {
    try {
      final currentPreferences = await getUserPreferredCategories();
      currentPreferences.remove(category);
      await saveUserPreferences(currentPreferences);
    } catch (e) {
      AppLogger.log('CategoryManagerService.removeCategoryPreference error: $e');
      rethrow;
    }
  }

  @override
  Future<List<NewsArticleEntity>> loadCategoryArticles(String category) async {
    try {
      // Check if already loading
      if (_categoryLoading[category] == true) {
        AppLogger.log('Category $category is already loading, waiting...');
        // Wait a bit and return cached if available
        await Future.delayed(const Duration(milliseconds: 500));
        return _categoryCache[category] ?? [];
      }

      // Check cache first
      if (_categoryCache.containsKey(category) && 
          _categoryCache[category]!.isNotEmpty &&
          _isCacheValid(category)) {
        AppLogger.log('Returning cached articles for category: $category');
        return _categoryCache[category]!;
      }

      // Load from data source
      _categoryLoading[category] = true;
      
      List<NewsArticleEntity> articles;
      if (category == 'All') {
        articles = await _newsLoader.loadNewsArticles();
      } else {
        articles = await _newsLoader.loadArticlesByCategory(category);
      }

      // Cache the results
      _categoryCache[category] = articles;
      _categoryLastLoaded[category] = DateTime.now();
      _categoryLoading[category] = false;

      AppLogger.log('Loaded ${articles.length} articles for category: $category');
      return articles;
    } catch (e) {
      _categoryLoading[category] = false;
      AppLogger.log('CategoryManagerService.loadCategoryArticles error for $category: $e');
      return [];
    }
  }

  @override
  Future<void> preloadPopularCategories() async {
    try {
      AppLogger.log('Preloading popular categories...');
      
      // Preload in background with delays to avoid overwhelming the system
      for (final category in _popularCategories) {
        try {
          if (!_categoryCache.containsKey(category) || _categoryCache[category]!.isEmpty) {
            AppLogger.log('Preloading category: $category');
            await loadCategoryArticles(category);
            await Future.delayed(const Duration(milliseconds: 300)); // Small delay between loads
          }
        } catch (e) {
          AppLogger.log('Failed to preload category $category: $e');
        }
      }
      
      AppLogger.log('Popular categories preloaded successfully');
    } catch (e) {
      AppLogger.log('CategoryManagerService.preloadPopularCategories error: $e');
    }
  }

  @override
  Future<void> initializeCategories() async {
    try {
      // Initialize cache for all categories
      for (final category in _baseCategories) {
        _categoryCache[category] = [];
        _categoryLoading[category] = false;
      }
      
      AppLogger.log('CategoryManagerService: Initialized categories');
    } catch (e) {
      AppLogger.log('CategoryManagerService.initializeCategories error: $e');
    }
  }

  /// Check if cached data is still valid (within 10 minutes)
  bool _isCacheValid(String category) {
    final lastLoaded = _categoryLastLoaded[category];
    if (lastLoaded == null) return false;
    
    final now = DateTime.now();
    const cacheValidDuration = Duration(minutes: 10);
    
    return now.difference(lastLoaded) < cacheValidDuration;
  }

  /// Clear cache for a specific category
  void clearCategoryCache(String category) {
    _categoryCache.remove(category);
    _categoryLastLoaded.remove(category);
    _categoryLoading[category] = false;
  }

  /// Clear all category caches
  void clearAllCaches() {
    _categoryCache.clear();
    _categoryLastLoaded.clear();
    for (final category in _baseCategories) {
      _categoryLoading[category] = false;
    }
  }

  /// Get cached articles for a category (if available)
  List<NewsArticleEntity>? getCachedArticles(String category) {
    return _categoryCache[category];
  }

  /// Check if a category is currently loading
  bool isCategoryLoading(String category) {
    return _categoryLoading[category] ?? false;
  }
}