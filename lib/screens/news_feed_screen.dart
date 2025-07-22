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
import 'settings_screen.dart';

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
  bool _isInitialLoad = true; // Track if this is the first load
  
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
    // Load "All" category immediately and simply
    _loadAllCategorySimple();
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
      print('DEBUG: LOADING ALL CATEGORY - Starting...');
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // For "All" category, load random mix from all categories
      final readIds = await ReadArticlesService.getReadArticleIds();
      print('DEBUG: Read articles count: ${readIds.length}');
      
      // Define all available categories to fetch from
      final allCategories = [
        'Technology', 'Business', 'Sports', 'Health', 'Science', 
        'Entertainment', 'World', 'Top', 'Travel', 'Politics', 
        'National', 'India', 'Education'
      ];
      
      final List<NewsArticle> allCombinedArticles = [];
      
      // Fetch articles from each category in parallel for faster loading
      final futures = allCategories.map((cat) async {
        try {
          final categoryArticles = await SupabaseService.getUnreadNewsByCategory(cat, readIds, limit: 20);
          print('DEBUG: Fetched ${categoryArticles.length} unread articles from $cat');
          return categoryArticles;
        } catch (e) {
          print('DEBUG: Error fetching $cat articles: $e');
          return <NewsArticle>[];
        }
      });
      
      final results = await Future.wait(futures);
      for (final articles in results) {
        allCombinedArticles.addAll(articles);
      }
      
      print('DEBUG: Total combined articles from all categories: ${allCombinedArticles.length}');
      
      // Remove duplicates based on article ID
      final uniqueArticles = <String, NewsArticle>{};
      for (final article in allCombinedArticles) {
        uniqueArticles[article.id] = article;
      }
      final validArticles = uniqueArticles.values.toList();
      print('DEBUG: After deduplication: ${validArticles.length} unique articles');
      
      // Shuffle to create random mix from all categories
      validArticles.shuffle();
      print('DEBUG: Shuffled ${validArticles.length} articles from all categories');
      
      setState(() {
        _articles = validArticles;
        _isLoading = false;
        _isInitialLoad = false;
        // Only show error if we have no articles AND this is not the initial load
        _error = validArticles.isEmpty ? 'All articles have been read! You have caught up with all the news. Check back later for new articles.' : '';
      });
      print('DEBUG: Set _articles to ${_articles.length} articles from all categories');
      
      if (validArticles.isNotEmpty) {
        _preloadColors();
        print('DEBUG SUCCESS: Loaded ${validArticles.length} mixed articles from ALL categories for All feed');
      } else {
        print('DEBUG: No valid articles - showing error message');
      }
    } catch (e) {
      print('DEBUG ERROR in _loadNewsArticles: $e');
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
    print('🎨 BUILD: _isLoading=$_isLoading, _articles.length=${_articles.length}, _error="$_error"');
    
    // Show loading shimmer during initial load
    if (_isInitialLoad && _isLoading && _articles.isEmpty) {
      print('🎨 BUILD: Showing loading shimmer');
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.black,
        child: Stack(
          children: [
            _buildLoadingShimmer(),
            _buildCleanHeader(),
          ],
        ),
      );
    }

    // Show error if no articles and not loading
    if (_articles.isEmpty && !_isLoading && _error.isNotEmpty) {
      print('🎨 BUILD: Showing error state');
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.black,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.news,
                    size: 64,
                    color: CupertinoColors.systemGrey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            _buildCleanHeader(),
          ],
        ),
      );
    }

    print('🎨 BUILD: Showing main content with ${_articles.length} articles');
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
    final categories = NewsUIService.getInitializeCategories();
    
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
        print('DEBUG: Switching to category: $newCategory');
        setState(() {
          _selectedCategory = newCategory;
          
          // Special handling for "All" category - use simple reload
          if (newCategory == 'All') {
            print('DEBUG: All category selected - using simple reload');
            _loadAllCategorySimple();
          } else if (_categoryArticles[newCategory]?.isNotEmpty == true) {
            print('DEBUG: Using cached articles for $newCategory: ${_categoryArticles[newCategory]!.length} articles');
            _articles = _categoryArticles[newCategory]!;
            _isLoading = false;
          } else {
            print('DEBUG: No cached articles for $newCategory - loading...');
            _isLoading = true;
            _loadArticlesByCategoryForCache(newCategory);
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
      _loadAllCategorySimple,  // Use simple load for "All" category
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
              // Settings button
              _buildSettingsButton(),
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
    final categories = NewsUIService.getInitializeCategories();
    
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
    
    // Special handling for "All" category when tapped
    if (category == 'All') {
      print('DEBUG TAP: All category tapped - clearing cache and forcing fresh load');
      // Clear ALL cached articles to force fresh load
      _categoryArticles.clear();
      _categoryLoading.clear();
      // Trigger fresh load for "All" category
      _loadArticlesByCategoryForCache('All');
    } else {
      _preloadCategoryIfNeeded(category);
    }
    
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
      // Set loading state immediately for current category
      if (category == _selectedCategory) {
        setState(() {
          _isLoading = true;
          _error = '';
        });
      }
      
      final readIds = await ReadArticlesService.getReadArticleIds();
      
      print('=== LOADING CATEGORY: $category ===');
      print('Read articles count: ${readIds.length}');
      
      // Special handling for "All" category - load random mix from all categories
      if (category == 'All') {
        print('DEBUG ALL: Loading ALL categories - fetching from all available categories');
        
        // Define all available categories to fetch from
        final allCategories = [
          'Technology', 'Business', 'Sports', 'Health', 'Science', 
          'Entertainment', 'World', 'Top', 'Travel', 'Politics', 
          'National', 'India', 'Education'
        ];
        
        final List<NewsArticle> allCombinedArticles = [];
        
        // Fetch articles from each category in parallel for faster loading
        final futures = allCategories.map((cat) async {
          try {
            final categoryArticles = await SupabaseService.getUnreadNewsByCategory(cat, readIds, limit: 30);
            print('DEBUG ALL: Fetched ${categoryArticles.length} unread articles from $cat');
            return categoryArticles;
          } catch (e) {
            print('DEBUG ALL: Error fetching $cat articles: $e');
            return <NewsArticle>[];
          }
        });
        
        final results = await Future.wait(futures);
        for (final articles in results) {
          allCombinedArticles.addAll(articles);
        }
        
        print('DEBUG ALL: Total combined articles from all categories: ${allCombinedArticles.length}');
        
        // Remove duplicates based on article ID
        final uniqueArticles = <String, NewsArticle>{};
        for (final article in allCombinedArticles) {
          uniqueArticles[article.id] = article;
        }
        final deduplicatedArticles = uniqueArticles.values.toList();
        print('DEBUG ALL: After deduplication: ${deduplicatedArticles.length} unique articles');
        
        // Simple validation - just check for basic content
        final validArticles = deduplicatedArticles.where((article) => 
          article.title.trim().isNotEmpty && 
          article.description.trim().isNotEmpty
        ).toList();
        print('DEBUG ALL: Valid articles after basic filtering: ${validArticles.length}');
        
        // Shuffle to create random mix from all categories
        validArticles.shuffle();
        print('DEBUG ALL: Shuffled ${validArticles.length} articles from all categories');
        
        _categoryArticles[category] = validArticles;
        _categoryLoading[category] = false;
        
        // Always update the main articles if this is for the current category
        if (category == _selectedCategory) {
          setState(() {
            _articles = validArticles;
            _isLoading = false;
            _isInitialLoad = false;
            // Only show error if we have no articles AND this is not the initial load
            _error = validArticles.isEmpty && !_isInitialLoad ? 'No unread articles available. Check back later for new content!' : '';
          });
          print('DEBUG ALL: Updated UI for ALL: ${validArticles.length} mixed articles from all categories displayed');
          
          // Preload colors for immediate display
          if (validArticles.isNotEmpty) {
            _preloadColors();
          }
        }
        
        print('DEBUG ALL: Pre-loaded All: ${validArticles.length} articles from all categories');
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

  void _preloadPopularCategoriesInBackground() {
    // Run in background without blocking UI
    Future.delayed(Duration(milliseconds: 500), () {
      _preloadPopularCategories();
    });
  }

  void _preloadAllCategoriesInBackground() {
    // Run in background without blocking UI
    Future.delayed(Duration(milliseconds: 1000), () {
      _preloadAllCategories();
    });
  }

  Future<void> _loadAllCategorySimple() async {
    print('🚀 SIMPLE LOAD: Starting All category load');
    
    // Show loading immediately
    setState(() {
      _isLoading = true;
      _error = '';
      _articles = []; // Clear any existing articles
    });

    try {
      // Get all articles from database (simple approach)
      final allArticles = await SupabaseService.getNews(limit: 200);
      print('🚀 SIMPLE LOAD: Got ${allArticles.length} total articles from database');
      
      if (allArticles.isNotEmpty) {
        // Get read article IDs
        final readIds = await ReadArticlesService.getReadArticleIds();
        
        // Filter unread articles
        final unreadArticles = allArticles.where((article) => 
          !readIds.contains(article.id)
        ).toList();
        
        // Shuffle for variety
        unreadArticles.shuffle();
        
        print('🚀 SIMPLE LOAD: Filtered to ${unreadArticles.length} unread articles');
        
        // Cache for "All" category FIRST - THIS IS CRITICAL!
        _categoryArticles['All'] = unreadArticles;
        _categoryLoading['All'] = false;
        
        // Update UI immediately
        setState(() {
          _articles = unreadArticles;
          _isLoading = false;
          _isInitialLoad = false;
          _error = unreadArticles.isEmpty ? 'All articles have been read!' : '';
        });
        
        // FORCE UPDATE: Make sure the page builder sees the articles
        print('🚀 SIMPLE LOAD: Setting _categoryArticles["All"] = ${unreadArticles.length} articles');
        print('🚀 SIMPLE LOAD: _categoryArticles["All"].length = ${_categoryArticles["All"]?.length ?? 0}');
        
        print('🚀 SIMPLE LOAD: SUCCESS - Displaying ${unreadArticles.length} articles');
        print('🚀 SIMPLE LOAD: _articles.length = ${_articles.length}');
        print('🚀 SIMPLE LOAD: _isLoading = $_isLoading');
        print('🚀 SIMPLE LOAD: _error = "$_error"');
        
        // Debug: Print first few article titles
        if (unreadArticles.isNotEmpty) {
          print('🚀 SIMPLE LOAD: First 3 articles:');
          for (int i = 0; i < unreadArticles.length && i < 3; i++) {
            print('  ${i+1}. "${unreadArticles[i].title}"');
          }
        }
        
        // Preload colors in background
        if (unreadArticles.isNotEmpty) {
          _preloadColors();
        }
        
        // Start background preloading of individual categories
        _startBackgroundPreloading();
      } else {
        setState(() {
          _isLoading = false;
          _isInitialLoad = false;
          _error = 'No articles available';
        });
      }
    } catch (e) {
      print('🚀 SIMPLE LOAD ERROR: $e');
      setState(() {
        _error = 'Failed to load articles: $e';
        _isLoading = false;
        _isInitialLoad = false;
      });
    }
  }

  void _startBackgroundPreloading() {
    // Start preloading individual categories in background after main content loads
    Future.delayed(Duration(milliseconds: 2000), () {
      print('🔄 Starting background preloading of individual categories');
      _preloadPopularCategories();
      _preloadAllCategories();
    });
  }

  Widget _buildSettingsButton() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 0,
      onPressed: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => const SettingsScreen(),
          ),
        );
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          CupertinoIcons.settings,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Container(
      color: CupertinoColors.black,
      child: Column(
        children: [
          const SizedBox(height: 100), // Space for header
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Image placeholder
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title placeholders
                  Container(
                    width: double.infinity,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 200,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Loading indicator
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoActivityIndicator(
                        radius: 15,
                        color: CupertinoColors.white,
                      ),
                      SizedBox(width: 16),
                      Text(
                        'Loading latest news...',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}