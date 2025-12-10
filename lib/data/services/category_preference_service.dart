import '../../domain/entities/news_article_entity.dart';
import '../services/local_storage_service.dart';
import '../services/refactored/service_coordinator.dart';

import '../../core/utils/app_logger.dart';
class CategoryPreferenceService {
  // Smart category preference tracking
  static final Map<String, int> _categoryViewTime = {}; // Time spent in each category
  static final Map<String, int> _categoryArticlesRead = {}; // Articles read per category
  static final Map<String, int> _categoryVisitCount = {}; // How often user visits category
  static DateTime? _categoryStartTime; // When user entered current category

  static void trackCategorySwitch(String fromCategory, String toCategory) {
    // Track time spent in previous category
    if (_categoryStartTime != null && fromCategory.isNotEmpty) {
      final timeSpent = DateTime.now().difference(_categoryStartTime!).inSeconds;
      _categoryViewTime[fromCategory] = (_categoryViewTime[fromCategory] ?? 0) + timeSpent;
    }
    
    // Track visit to new category
    _categoryVisitCount[toCategory] = (_categoryVisitCount[toCategory] ?? 0) + 1;
    _categoryStartTime = DateTime.now();
    
    AppLogger.log('User preference: Spent ${_categoryViewTime[fromCategory] ?? 0}s in $fromCategory, visiting $toCategory (${_categoryVisitCount[toCategory]} times)');
    
    // Update category preferences periodically
    updateCategoryPreferences();
  }

  static void trackArticleRead(NewsArticleEntity article, String selectedCategory) {
    // Determine article category (could be from title/content analysis or database category)
    String articleCategory = ServiceCoordinator().newsProcessor.detectArticleCategory(article, selectedCategory);
    
    _categoryArticlesRead[articleCategory] = (_categoryArticlesRead[articleCategory] ?? 0) + 1;
    _categoryArticlesRead[selectedCategory] = (_categoryArticlesRead[selectedCategory] ?? 0) + 1;
    
    AppLogger.log('User preference: Read article in $articleCategory (${_categoryArticlesRead[articleCategory]} total)');
  }

  static void updateCategoryPreferences() {
    // Calculate preference scores based on multiple factors
    final Map<String, double> preferenceScores = {};
    
    for (String category in ['All', 'Sports', 'Top', 'Trending', 'Science', 'World', 'Health', 'Business', 'Tech', 'Entertainment']) {
      double score = 0.0;
      
      // Factor 1: Time spent in category (40% weight)
      final timeSpent = _categoryViewTime[category] ?? 0;
      score += (timeSpent / 60.0) * 0.4; // Convert to minutes
      
      // Factor 2: Articles read in category (35% weight)
      final articlesRead = _categoryArticlesRead[category] ?? 0;
      score += articlesRead * 0.35;
      
      // Factor 3: Visit frequency (25% weight)
      final visitCount = _categoryVisitCount[category] ?? 0;
      score += visitCount * 0.25;
      
      preferenceScores[category] = score;
    }
    
    // Sort categories by preference score
    final sortedPreferences = preferenceScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    AppLogger.log('=== USER CATEGORY PREFERENCES ===');
    for (int i = 0; i < sortedPreferences.length && i < 5; i++) {
      final entry = sortedPreferences[i];
      AppLogger.log('${i + 1}. ${entry.key}: ${entry.value.toStringAsFixed(1)} points');
    }
    AppLogger.log('=== END PREFERENCES ===');
    
    // Store preferences for future use
    saveUserPreferences(sortedPreferences);
  }

  static Future<void> saveUserPreferences(List<MapEntry<String, double>> preferences) async {
    // Save to local storage for persistence
    final topCategories = preferences.take(5).map((e) => e.key).toList();
    try {
      await LocalStorageService.setCategoryPreferences(topCategories);
      AppLogger.log('Saved user preferences: ${topCategories.join(", ")}');
    } catch (e) {
      AppLogger.log('Error saving preferences: $e');
    }
    
    // Reorder category list based on preferences for better UX
    reorderCategoriesByPreference(topCategories);
  }

  static void reorderCategoriesByPreference(List<String> preferredCategories) {
    // This could reorder the horizontal category pills to show preferred ones first
    AppLogger.log('Top preferred categories: ${preferredCategories.join(", ")}');
    
    // Future enhancement: Dynamically reorder the category pills
    // to show user's favorite categories first
  }

  static void initializeCategoryTracking() {
    _categoryStartTime = DateTime.now();
  }

  static void removeReadArticleFromCaches(String articleId, Map<String, List<NewsArticleEntity>> categoryArticles) {
    // DON'T remove articles from active session cache
    // This prevents the "articles changing while viewing" issue
    // Articles will be filtered out on next app launch or manual refresh
    AppLogger.log('📖 CategoryPreferenceService: Article marked as read (kept in session): $articleId');
  }
}