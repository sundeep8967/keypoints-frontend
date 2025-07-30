import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/news_article.dart';
import '../services/consolidated/news_facade.dart';
import '../services/color_extraction_service.dart';
import '../services/error_message_service.dart';

/// Controller for managing news feed state and operations.
/// 
/// This controller handles loading, caching, and state management for news articles
/// across different categories. It provides reactive updates through ChangeNotifier
/// and includes comprehensive error handling and caching strategies.
/// 
/// Features:
/// * Article loading and caching by category
/// * Color palette preloading for smooth UI transitions
/// * Reactive state updates for UI components
/// * Error handling with user-friendly messages
/// * Category-specific article management
class NewsFeedController extends ChangeNotifier {
  /// List of currently displayed articles.
  List<NewsArticle> _articles = [];
  
  /// Loading state indicator.
  bool _isLoading = true;
  
  /// Current error message, empty if no error.
  String _error = '';
  
  /// Index of the currently viewed article.
  int _currentIndex = 0;
  
  /// Cache for preloaded color palettes to improve UI performance.
  final Map<String, ColorPalette> _colorCache = {};
  
  /// Cache for articles organized by category.
  final Map<String, List<NewsArticle>> _categoryArticles = {};
  
  /// Loading state for each category.
  final Map<String, bool> _categoryLoading = {};

  /// Gets the list of currently displayed articles.
  List<NewsArticle> get articles => _articles;
  
  /// Gets the current loading state.
  bool get isLoading => _isLoading;
  
  /// Gets the current error message, or empty string if no error.
  String get error => _error;
  
  /// Gets the index of the currently viewed article.
  int get currentIndex => _currentIndex;
  
  /// Gets the cache of preloaded color palettes.
  Map<String, ColorPalette> get colorCache => _colorCache;
  
  /// Gets the cache of articles organized by category.
  Map<String, List<NewsArticle>> get categoryArticles => _categoryArticles;

  /// Loads news articles for the "All" category.
  /// 
  /// Fetches a mixed collection of articles from all available categories
  /// using the NewsFacade. Updates the loading state and notifies listeners
  /// of changes. Includes comprehensive error handling with user-friendly messages.
  /// 
  /// The method will:
  /// 1. Set loading state and clear any existing errors
  /// 2. Fetch articles through the facade
  /// 3. Update internal state and caches
  /// 4. Notify listeners of state changes
  /// 
  /// Throws: This method handles all exceptions internally and updates
  /// the error state instead of throwing.
  Future<void> loadAllCategoryArticles() async {
    try {
      _setLoading(true);
      _clearError();
      _articles = [];
      notifyListeners();

      // Load articles using the facade
      final articles = await NewsFacade().loadMainFeed();
      
      if (articles.isNotEmpty) {
        _articles = articles;
        _categoryArticles['All'] = articles;
        _categoryLoading['All'] = false;
        
        // Colors are already preloaded by the facade
      } else {
        _error = 'No articles available. Please check your internet connection and try again.';
      }
      
      _setLoading(false);
      notifyListeners();
      
    } on SocketException catch (e) {
      _error = 'Network connection failed. Please check your internet connection and try again.';
      _setLoading(false);
      notifyListeners();
    } on TimeoutException catch (e) {
      _error = 'Request timed out. Please try again.';
      _setLoading(false);
      notifyListeners();
    } on FormatException catch (e) {
      _error = ErrorMessageService.getUserFriendlyMessage('Invalid data received from server');
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _error = ErrorMessageService.getUserFriendlyMessage(e.toString());
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Load articles for a specific category
  Future<void> loadCategoryArticles(String category) async {
    if (category.trim().isEmpty) {
      _error = 'Invalid category selected';
      notifyListeners();
      return;
    }

    try {
      // Check facade cache first
      final cachedArticles = NewsFacade().getCachedArticles(category);
      if (cachedArticles.isNotEmpty) {
        _articles = cachedArticles;
        _currentIndex = 0;
        _clearError();
        notifyListeners();
        return;
      }

      _setLoading(true);
      _clearError();
      notifyListeners();

      // Load using facade
      final validArticles = await NewsFacade().loadCategoryFeed(category);
      
      _categoryArticles[category] = validArticles;
      _categoryLoading[category] = false;
      _articles = validArticles;
      _currentIndex = 0;
      
      _setLoading(false);
      notifyListeners();
      
    } on SocketException catch (e) {
      _error = 'Network connection failed. Please check your internet connection and try again.';
      _setLoading(false);
      notifyListeners();
    } on TimeoutException catch (e) {
      _error = 'Request timed out. Please try again.';
      _setLoading(false);
      notifyListeners();
    } on ArgumentError catch (e) {
      _error = 'Invalid category: ${e.message}';
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load $category articles. Please try again later.';
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Mark article as read and move to next
  Future<void> markArticleAsRead(NewsArticle article) async {
    try {
      await NewsFacade().markArticleAsRead(article);
      
      // Remove from current articles list
      _articles.removeWhere((a) => a.id == article.id);
      
      // Also remove from category cache
      for (final categoryList in _categoryArticles.values) {
        categoryList.removeWhere((a) => a.id == article.id);
      }
      
      // Adjust current index if needed
      if (_currentIndex >= _articles.length && _articles.isNotEmpty) {
        _currentIndex = _articles.length - 1;
      }
      
      notifyListeners();
      print('✅ CONTROLLER: Marked article as read: ${article.title}');
      
    } catch (e) {
      print('❌ CONTROLLER: Error marking article as read: $e');
    }
  }

  /// Update current index
  void updateCurrentIndex(int index) {
    if (index >= 0 && index < _articles.length) {
      _currentIndex = index;
      notifyListeners();
      
      // Preload colors for nearby articles
      _preloadColors();
    }
  }

  /// Preload colors for current and nearby articles
  Future<void> _preloadColors() async {
    if (_articles.isEmpty) return;
    
    final startIndex = (_currentIndex - 1).clamp(0, _articles.length - 1);
    final endIndex = (_currentIndex + 2).clamp(0, _articles.length - 1);
    
    for (int i = startIndex; i <= endIndex; i++) {
      final article = _articles[i];
      if (!_colorCache.containsKey(article.imageUrl)) {
        try {
          final palette = await ColorExtractionService.extractColorsFromImage(article.imageUrl);
          _colorCache[article.imageUrl] = palette;
        } catch (e) {
          print('Error preloading color for article $i: $e');
        }
      }
    }
  }


  void _setLoading(bool loading) {
    _isLoading = loading;
  }

  void _clearError() {
    _error = '';
  }

  /// Clear all caches
  void clearCaches() {
    _categoryArticles.clear();
    _categoryLoading.clear();
    _colorCache.clear();
    notifyListeners();
  }
}