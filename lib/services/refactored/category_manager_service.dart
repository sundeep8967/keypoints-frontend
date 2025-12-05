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
    // Return cached categories if available (synchronous for performance)
    // Background sync will update them periodically
    return List.from(_popularCategories);
  }

  /// Get popular categories with caching and background sync
  Future<List<String>> getPopularCategoriesAsync() async {
    try {
      // 1. Try loading from local cache first (instant!)
      final cachedCategories = await LocalStorageService.getAvailableCategories();
      final lastSync = await LocalStorageService.getCategoriesLastSync();
      
      // 2. Check if cache is valid (less than 24 hours old)
      final now = DateTime.now();
      final cacheValid = lastSync != null && 
                        now.difference(lastSync).inHours < 24;
      
      if (cachedCategories != null && cacheValid) {
        AppLogger.success('📦 Using cached categories (${cachedCategories.length} categories, synced ${now.difference(lastSync).inHours}h ago)');
        return cachedCategories;
      }
      
      // 3. Cache expired or doesn't exist - fetch from backend
      AppLogger.info('🔄 Fetching fresh categories from backend...');
      
      // For now, return popular categories
      // TODO: If you have a Supabase endpoint to fetch available categories, use it here
      final freshCategories = List<String>.from(_popularCategories);
      
      // 4. Save to cache for next time
      await LocalStorageService.setAvailableCategories(freshCategories);
      
      return freshCategories;
    } catch (e) {
      AppLogger.error('❌ Error fetching categories: $e');
      // Fallback to default popular categories
      return List.from(_popularCategories);
    }
  }

  /// Background sync: Check for new categories without blocking UI
  Future<void> syncCategoriesInBackground() async {
    try {
      final lastSync = await LocalStorageService.getCategoriesLastSync();
      final now = DateTime.now();
      
      // Only sync if last sync was > 24 hours ago
      if (lastSync != null && now.difference(lastSync).inHours < 24) {
        AppLogger.info('📦 Categories sync skipped (last synced ${now.difference(lastSync).inHours}h ago)');
        return;
      }
      
      AppLogger.info('🔄 Background sync: Checking for new categories...');
      
      // Fetch from backend (non-blocking)
      // TODO: Replace with actual Supabase category fetch if available
      final freshCategories = List<String>.from(_popularCategories);
      
      // Update cache
      await LocalStorageService.setAvailableCategories(freshCategories);
      
      AppLogger.success('✅ Categories synced successfully');
    } catch (e) {
      AppLogger.warning('⚠️ Background category sync failed: $e');
      // Don't throw - it's background work
    }
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
      
      // Load cached available categories (instant!)
      final cachedCategories = await LocalStorageService.getAvailableCategories();
      if (cachedCategories != null && cachedCategories.isNotEmpty) {
        AppLogger.success('📦 Loaded ${cachedCategories.length} cached categories');
      } else {
        // First time - cache default categories
        await LocalStorageService.setAvailableCategories(_popularCategories);
        AppLogger.info('📦 Cached default categories for first time');
      }
      
      // Trigger background sync (non-blocking)
      syncCategoriesInBackground().catchError((error) {
        AppLogger.warning('⚠️ Background sync failed: $error');
      });
      
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