import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/news_article.dart';
import '../services/supabase_service.dart';
import '../services/color_extraction_service.dart';
import '../services/read_articles_service.dart';
import '../services/local_storage_service.dart';
import '../services/news_feed_helper.dart';
import '../services/category_preference_service.dart';
import '../services/news_loading_service.dart';
import '../services/category_scroll_service.dart';
import '../services/news_ui_service.dart';
import '../services/article_management_service.dart';
import '../services/category_loading_service.dart';
import '../services/category_management_service.dart';
import '../widgets/news_feed_widgets.dart';
import '../widgets/news_feed_page_builder.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> with TickerProviderStateMixin {
  List<NewsArticle> _articles = [];
  bool _isLoading = true;
  String _error = '';
  int _currentIndex = 0;
  String _selectedCategory = 'All'; // Track selected category
  
  // Cache for preloaded color palettes
  final Map<String, ColorPalette> _colorCache = {};
  
  // Cache for category articles - pre-load all categories
  final Map<String, List<NewsArticle>> _categoryArticles = {};
  final Map<String, bool> _categoryLoading = {};
  
  // Animation controllers for swipe
  late AnimationController _animationController;
  late PageController _categoryPageController;
  late ScrollController _categoryScrollController;
  
  // Store category pill positions for accurate scrolling
  final List<GlobalKey> _categoryKeys = [];
  final Map<int, double> _categoryPositions = {};

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeCategories();
    _loadNewsArticles();
    _preloadAllCategories();
    // Debug: Show categories in database
    NewsLoadingService.showSupabaseCategories();
    // Pre-load popular categories for instant switching
    _preloadPopularCategories();
    // Smart read tracking enabled
    // Initialize preference tracking
    CategoryPreferenceService.initializeCategoryTracking();
  }

  void _initializeCategories() {
    final categories = NewsUIService.getInitializeCategories();
    
    // Initialize category page controller
    final currentCategoryIndex = categories.indexOf(_selectedCategory);
    _categoryPageController = PageController(initialPage: currentCategoryIndex >= 0 ? currentCategoryIndex : 0);
    
    // Initialize category scroll controller for horizontal pills
    _categoryScrollController = ScrollController();
    
    // Pre-load all categories
    CategoryManagementService.initializeCategories(categories, _categoryArticles, _categoryLoading);
  }
  
  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _categoryPageController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNewsArticles() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // For "All" category, load random mix from all categories
      final readIds = await ReadArticlesService.getReadArticleIds();
      
      // Get all articles from all categories and shuffle them
      final allArticles = await SupabaseService.getNews(limit: 200);
      final unreadArticles = allArticles.where((article) => 
        !readIds.contains(article.id)
      ).toList();
      
      // Shuffle to create random mix
      unreadArticles.shuffle();
      
      // Filter out articles with no content and mark them as read
      final validArticles = await _filterValidArticles(unreadArticles);
      
      setState(() {
        _articles = validArticles;
        _isLoading = false;
      });
      
      if (validArticles.isEmpty) {
        setState(() {
          _error = 'All articles have been read! You\'ve caught up with all the news. Check back later for new articles.';
        });
      } else {
        _preloadColors();
        print('Loaded ${validArticles.length} mixed articles from ALL categories for "All" feed');
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load articles: $e';
        _isLoading = false;
      });
    }
  }

  // Add all the missing methods from the backup
  Future<void> _loadArticlesByCategory(String category) async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // Get read articles to filter them out
      final readIds = await ReadArticlesService.getReadArticleIds();

      // PRIORITY 1: Try Supabase category filter
      try {
        final allCategoryArticles = await SupabaseService.getNewsByCategory(category, limit: 100);
        if (allCategoryArticles.isNotEmpty) {
          final unreadCategoryArticles = allCategoryArticles.where((article) => 
            !readIds.contains(article.id)
          ).toList();
          
          setState(() {
            _articles = unreadCategoryArticles;
            _isLoading = false;
          });
          
          if (unreadCategoryArticles.isEmpty) {
            // Show toast and load all other unread articles
            _showToast('You have read all articles in $category category');
            await _loadAllOtherUnreadArticles();
            return;
          } else {
            _preloadColors();
          }
          
          print('SUCCESS: Loaded ${allCategoryArticles.length} total $category articles, ${unreadCategoryArticles.length} unread from Supabase');
          return;
        }
      } catch (e) {
        print('ERROR: Supabase category filter failed: $e');
      }

      // PRIORITY 2: Try filtering all Supabase articles locally
      try {
        final allSupabaseArticles = await SupabaseService.getNews(limit: 100);
        if (allSupabaseArticles.isNotEmpty) {
          final filteredArticles = allSupabaseArticles.where((article) => 
            article.category.toLowerCase() == category.toLowerCase()
          ).toList();
          
          final unreadFilteredArticles = filteredArticles.where((article) => 
            !readIds.contains(article.id)
          ).toList();
          
          if (unreadFilteredArticles.isNotEmpty) {
            setState(() {
              _articles = unreadFilteredArticles;
              _isLoading = false;
            });
            print('SUCCESS: Filtered ${unreadFilteredArticles.length} unread $category articles from ${filteredArticles.length} total');
            _preloadColors();
            return;
          } else if (filteredArticles.isNotEmpty) {
            // Show toast and load all other unread articles
            _showToast('You have read all articles in $category category');
            await _loadAllOtherUnreadArticles();
            return;
          } else {
            // Show toast and switch back to All category
            setState(() {
              _articles = [];
              _error = 'No $category articles found.';
              _isLoading = false;
            });
            _showToast('No $category articles found. Switching back to All categories.');
            return;
          }
        }
      } catch (e) {
        print('ERROR: Failed to filter Supabase articles: $e');
      }

      // PRIORITY 3: If Supabase completely fails, show toast and prepare to switch back to All
      setState(() {
        _articles = [];
        _error = 'Unable to load $category articles.';
        _isLoading = false;
      });
      _showToast('Unable to load $category articles. Switching back to All categories.');
      print('ERROR: Supabase completely unavailable for $category');
    } catch (e) {
      setState(() {
        _error = 'Failed to load articles for $category: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Stack(
        children: [
          _buildCategoryPageView(),
          _buildCleanHeader(),
        ],
      ),
    );
  }

  Widget _buildCategoryPageView() {
    final categories = NewsUIService.getHorizontalCategories();
    
    return NewsFeedPageBuilder.buildCategoryPageView(
      context,
      categories,
      _categoryPageController,
      _selectedCategory,
      _currentIndex,
      _categoryArticles,
      _categoryLoading,
      _error,
      (newCategory) {
        setState(() {
          _selectedCategory = newCategory;
          if (_categoryArticles[newCategory]?.isNotEmpty == true) {
            _articles = _categoryArticles[newCategory]!;
            _isLoading = false;
          } else {
            _isLoading = true;
          }
        });
        
        // Auto-scroll category pills to keep selected category visible
        final categoryIndex = categories.indexOf(newCategory);
        if (categoryIndex != -1) {
          CategoryScrollService.scrollToSelectedCategoryAccurate(
            context, _categoryScrollController, categoryIndex, categories);
        }
      },
      (index) => setState(() => _currentIndex = index),
      _loadArticlesByCategoryForCache,
      _loadNewsArticles,
      _colorCache,
    );
  }

  Widget _buildCleanHeader() {
    return Positioned(
      top: MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: Container(
        height: 60,
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              // Horizontal categories - takes most of the space
              Expanded(
                child: _buildHorizontalCategories(),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalCategories() {
    // Base categories + dynamically detected states
    final baseCategories = NewsUIService.getHorizontalCategories();
    
    // Add detected states from current articles
    final detectedStates = NewsFeedHelper.getDetectedStatesFromArticles(_articles);
    final categories = [...baseCategories, ...detectedStates];

    return SizedBox(
      height: 44,
      child: ListView.builder(
        controller: _categoryScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == _selectedCategory;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              key: index < _categoryKeys.length ? _categoryKeys[index] : null,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 0,
                onPressed: () {
                  _selectCategory(category);
                  // Also scroll to tapped category
                  CategoryScrollService.scrollToSelectedCategoryAccurate(
                    context, _categoryScrollController, index, categories);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? Colors.white 
                      : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _selectCategory(String category) {
    final categories = NewsUIService.getHorizontalCategories();
    
    final categoryIndex = categories.indexOf(category);
    if (categoryIndex != -1) {
      _categoryPageController.animateToPage(
        categoryIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    
    setState(() {
      _selectedCategory = category;
      _currentIndex = 0;
    });
    
    _preloadCategoryIfNeeded(category);
    
    print('Switched to $category');
  }

  void _preloadCategoryIfNeeded(String category) {
    CategoryManagementService.preloadCategoryIfNeeded(
      category, 
      _categoryArticles, 
      _categoryLoading, 
      _loadArticlesByCategoryForCache,
      () => _loadNewsArticlesForCategory(category),
    );
  }

  void _preloadAllCategories() {
    final categories = NewsUIService.getPreloadCategories();
    
    CategoryManagementService.preloadAllCategories(
      categories,
      _categoryArticles,
      _categoryLoading,
      _loadArticlesByCategoryForCache,
      () => _loadNewsArticlesForCategory('All'),
    );
  }

  Future<void> _loadNewsArticlesForCategory(String category) async {
    try {
      _categoryLoading[category] = true;
      final unreadArticles = await CategoryLoadingService.loadNewsArticlesForCategory(category);
      
      _categoryArticles[category] = unreadArticles;
      _categoryLoading[category] = false;
      
      // Always update the main articles if this is for the current category
      if (category == _selectedCategory) {
        setState(() {
          _articles = unreadArticles;
          _isLoading = false;
        });
      }
    } catch (e) {
      _categoryLoading[category] = false;
      print('Error pre-loading $category: $e');
    }
  }

  Future<void> _loadArticlesByCategoryForCache(String category) async {
    try {
      final readIds = await ReadArticlesService.getReadArticleIds();
      
      print('=== LOADING CATEGORY: $category ===');
      print('Read articles count: ${readIds.length}');
      
      // Special handling for "All" category - load random mix from all categories
      if (category == 'All') {
        print('Loading ALL categories - random mix from all sources');
        
        // Get all articles from all categories and shuffle them
        final allArticles = await SupabaseService.getNews(limit: 200);
        final unreadArticles = allArticles.where((article) => 
          !readIds.contains(article.id)
        ).toList();
        
        // Shuffle to create random mix
        unreadArticles.shuffle();
        
        // Filter out articles with no content and mark them as read
        final validArticles = await _filterValidArticles(unreadArticles);
        print('Loaded ${validArticles.length} valid articles from ALL categories (shuffled)');
        
        _categoryArticles[category] = validArticles;
        _categoryLoading[category] = false;
        
        // Always update the main articles if this is for the current category
        if (category == _selectedCategory) {
          setState(() {
            _articles = validArticles;
            _isLoading = false;
          });
          print('Updated UI for ALL: ${validArticles.length} mixed articles displayed');
        }
        return;
      }
      
      // For specific categories, map UI category names to database category names
      String dbCategory = category;
      if (category == 'Tech') {
        dbCategory = 'Technology';
      } else if (category == 'Entertainment') {
        dbCategory = 'Entertainment';
      } else if (category == 'Business') {
        dbCategory = 'Business';
      } else if (category == 'Health') {
        dbCategory = 'Health';
      } else if (category == 'Sports') {
        dbCategory = 'Sports';
      } else if (category == 'Science') {
        dbCategory = 'Science';
      } else if (category == 'World') {
        dbCategory = 'World';
      } else if (category == 'Top') {
        dbCategory = 'Top';
      } else if (category == 'Travel') {
        dbCategory = 'Travel';
      } else if (category == 'Startups') {
        dbCategory = 'Startups';
      } else if (category == 'Politics') {
        dbCategory = 'Politics';
      } else if (category == 'National') {
        dbCategory = 'National';
      } else if (category == 'India') {
        dbCategory = 'India';
      } else if (category == 'Education') {
        dbCategory = 'Education';
      } else if (category == 'Celebrity') {
        dbCategory = 'Celebrity';
      } else if (category == 'Scandal') {
        dbCategory = 'Scandal';
      } else if (category == 'Viral') {
        dbCategory = 'Viral';
      } else if (category == 'State') {
        dbCategory = 'State';
      } else {
        // For detected state names, use them as-is
        dbCategory = category;
      }
      
      print('UI Category: "$category" -> DB Category: "$dbCategory"');
      
      // Use the new method that directly fetches unread articles - get more to ensure enough unread
      final unreadCategoryArticles = await SupabaseService.getUnreadNewsByCategory(dbCategory, readIds, limit: 200);
      print('Found ${unreadCategoryArticles.length} unread articles for "$dbCategory"');
      
      // Debug: Also try the old method to compare
      final allCategoryArticles = await SupabaseService.getNewsByCategory(dbCategory, limit: 100);
      print('DEBUG: Total articles in "$dbCategory" category: ${allCategoryArticles.length}');
      
      if (allCategoryArticles.isNotEmpty) {
        final readCount = allCategoryArticles.where((article) => readIds.contains(article.id)).length;
        print('DEBUG: $dbCategory breakdown - Total: ${allCategoryArticles.length}, Read: $readCount, Should be unread: ${allCategoryArticles.length - readCount}');
        
        // Show first few article titles for debugging
        print('DEBUG: First 3 articles in $dbCategory:');
        for (int i = 0; i < allCategoryArticles.length && i < 3; i++) {
          final article = allCategoryArticles[i];
          final isRead = readIds.contains(article.id);
          print('  ${i+1}. "${article.title}" (ID: ${article.id}) - ${isRead ? "READ" : "UNREAD"}');
        }
      }
      
      // Filter out articles with no content and mark them as read
      final validCategoryArticles = await _filterValidArticles(unreadCategoryArticles);
      print('Filtered to ${validCategoryArticles.length} valid articles for $dbCategory');
      
      _categoryArticles[category] = validCategoryArticles;
      _categoryLoading[category] = false;
      
      // Always update the main articles if this is for the current category
      if (category == _selectedCategory) {
        setState(() {
          _articles = validCategoryArticles;
          _isLoading = false;
        });
        print('Updated UI for $category: ${validCategoryArticles.length} articles displayed');
      }
      
      if (validCategoryArticles.isNotEmpty) {
        print('Pre-loaded $category: ${validCategoryArticles.length} valid articles available');
      } else {
        print('No unread $category articles found - checking if category exists...');
        // Check if category exists at all by getting a small sample
        final sampleCategoryArticles = await SupabaseService.getNewsByCategory(dbCategory, limit: 5);
        if (sampleCategoryArticles.isNotEmpty) {
          print('$category exists in database but all articles have been read');
        } else {
          print('No $category articles found in database at all');
        }
      }
    } catch (e) {
      _categoryLoading[category] = false;
      print('Error pre-loading $category: $e');
    }
  }

  Future<List<NewsArticle>> _filterValidArticles(List<NewsArticle> articles) async {
    return await NewsFeedHelper.filterValidArticles(articles);
  }

  Future<void> _preloadColors() async {
    await ArticleManagementService.preloadColors(_articles, _currentIndex, _colorCache);
  }

  Future<void> _loadAllOtherUnreadArticles() async {
    try {
      await ArticleManagementService.loadAllOtherUnreadArticles(
        (category) => setState(() => _selectedCategory = category),
        _loadNewsArticles,
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showToast(String message) {
    NewsUIService.showToast(context, message, onDismiss: () {
      // If we're showing a "no articles" message and not on "All" category,
      // automatically switch back to "All"
      if (_selectedCategory != 'All' && _articles.isEmpty) {
        _selectCategory('All');
      }
    });
  }

  void _preloadPopularCategories() {
    final popularCategories = NewsUIService.getPopularCategories();
    
    CategoryManagementService.preloadPopularCategories(
      popularCategories,
      _categoryArticles,
      _loadArticlesByCategoryForCache,
    );
  }
}