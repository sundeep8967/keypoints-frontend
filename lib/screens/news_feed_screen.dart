import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/news_article.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';
import '../utils/app_logger.dart';
import '../services/color_extraction_service.dart';
import '../services/read_articles_service.dart';
import '../services/category_scroll_service.dart';
import '../services/news_ui_service.dart';
import '../services/article_management_service.dart';
import '../services/category_loading_service.dart';
import '../services/category_management_service.dart';
import '../services/dynamic_category_discovery_service.dart';
import '../widgets/news_feed_page_builder.dart';
import '../services/optimized_image_service.dart';
import '../services/parallel_color_service.dart';
import '../services/instant_preloader_service.dart';
import '../services/error_message_service.dart';
import '../services/scroll_state_service.dart';
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
  
  // Dynamic categories discovered from backend
  final Set<String> _discoveredCategories = {'All'}; // Always start with 'All'
  
  // Animation controllers for swipe
  late AnimationController _animationController;
  late PageController _categoryPageController;
  late ScrollController _categoryScrollController;
  
  // PageControllers for each category to enable bidirectional scrolling
  final Map<String, PageController> _articlePageControllers = {};
  
  // Store category pill positions for accurate scrolling
  final List<GlobalKey> _categoryKeys = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeCategories();
    
    // Start with minimal loading - defer heavy operations
    _quickLoadInitialContent();
  }

  void _initializeCategories() {
    // Initialize category page controller
    _categoryPageController = PageController(initialPage: 0);
    
    // Initialize category scroll controller for horizontal pills
    _categoryScrollController = ScrollController();
    
    // Defer heavy operations to after initial load
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _startDynamicCategoryDiscovery();
      }
    });
  }

  /// Quick initial content load - minimal operations to get app showing content fast
  Future<void> _quickLoadInitialContent() async {
    try {
      // Show loading immediately
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // Try to load cached articles first (fastest)
      final cachedArticles = await LocalStorageService.loadUnreadArticles();
      
      if (cachedArticles.isNotEmpty) {
        // Show cached content immediately - even just 1 article is better than loading screen
        final articlesToShow = cachedArticles.take(10).toList(); // Show first 10 for instant display
        
        setState(() {
          _articles = articlesToShow;
          _isLoading = false; // Stop loading immediately
          _isInitialLoad = false;
        });
        
        // Cache for "All" category
        _categoryArticles['All'] = articlesToShow;
        _categoryLoading['All'] = false;
        
        AppLogger.success('⚡ INSTANT CACHE: Showing ${articlesToShow.length} cached articles IMMEDIATELY');
        
        // CRITICAL FIX: Mark first article as read immediately when app starts
        if (articlesToShow.isNotEmpty) {
          ReadArticlesService.markAsRead(articlesToShow.first.id);
          AppLogger.success('📖 FIRST ARTICLE MARKED: "${articlesToShow.first.title}" (ID: ${articlesToShow.first.id}) - user viewing first article');
        }
        
        // 🚀 ASYNC: Start all preloading asynchronously for cached articles
        _startAsyncPreloading(articlesToShow);
        
        // Start background initialization after showing cached content
        _initializeBackgroundServices();
        
        // Load fresh content in background to update cache - but don't disrupt user's reading
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            AppLogger.info('⚡ SMART BACKGROUND REFRESH: Loading fresh articles without disrupting user');
            _loadFreshArticlesInBackground();
          }
        });
      } else {
        // No cache available, use progressive loading
        AppLogger.info('⚡ NO CACHE: Starting progressive loading immediately');
        _loadAllCategorySimple();
        _initializeBackgroundServices();
      }
    } catch (e) {
      AppLogger.error('⚡ QUICK LOAD ERROR: $e');
      // Fallback to progressive loading
      _loadAllCategorySimple();
      _initializeBackgroundServices();
    }
  }

  /// Initialize heavy services in background after content loads
  void _initializeBackgroundServices() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        // Initialize optimized image cache
        OptimizedImageService.initializeCache();
        
        // Initialize parallel color extraction
        ParallelColorService.initializeParallelColorExtraction();
        
        AppLogger.success('Background services initialized');
      }
    });
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
    
    // Dispose all article PageControllers
    for (final controller in _articlePageControllers.values) {
      controller.dispose();
    }
    _articlePageControllers.clear();
    
    super.dispose();
  }

  Future<void> _loadNewsArticles() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // CRITICAL FIX: Always get fresh read IDs at the start
      final readIds = await ReadArticlesService.getReadArticleIds();
      AppLogger.debug('LOAD: Starting with ${readIds.length} read articles');
      
      // For "All" category, load random mix from all categories
      
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
          return categoryArticles;
        } catch (e) {
          // Log error but continue with other categories
          return <NewsArticle>[];
        }
      });
      
      final results = await Future.wait(futures);
      for (final articles in results) {
        allCombinedArticles.addAll(articles);
      }
      
      // Remove duplicates based on article ID
      final uniqueArticles = <String, NewsArticle>{};
      for (final article in allCombinedArticles) {
        uniqueArticles[article.id] = article;
      }
      final validArticles = uniqueArticles.values.toList();
      
      // 🎯 STABILIZED: Don't shuffle during initial load - maintain stable order
      // validArticles.shuffle(); // REMOVED: No shuffling during initial load
      
      setState(() {
        _articles = validArticles;
        _isLoading = false;
        _isInitialLoad = false;
        _error = validArticles.isEmpty ? 'All articles have been read! You have caught up with all the news. Check back later for new articles.' : '';
      });
      
      if (validArticles.isNotEmpty) {
        _preloadColors();
        // CRITICAL FIX: INSTANT preloading - start immediately, don't wait
        AppLogger.info(' INSTANT PRELOAD: Starting aggressive preloading of first 25 images');
        
        // Start preloading first 25 images immediately in background
        OptimizedImageService.preloadImagesAggressively(validArticles, 0, preloadCount: 25);
      }
    } catch (e) {
      setState(() {
        _error = ErrorMessageService.getUserFriendlyMessage(e.toString());
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    // Show loading shimmer during initial load
    if (_isInitialLoad && _isLoading && _articles.isEmpty) {
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
    final categories = _discoveredCategories.toList();
    
    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: _refreshCurrentCategory,
        ),
        SliverFillRemaining(
          child: NewsFeedPageBuilder.buildCategoryPageView(
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
          
          // Reset article PageController for new category to start from beginning
          if (_articlePageControllers.containsKey(newCategory)) {
            final controller = _articlePageControllers[newCategory]!;
            if (controller.hasClients) {
              controller.animateToPage(0, duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
            }
          }
          
          // Special handling for "All" category - check cache first
          if (newCategory == 'All') {
            if (_categoryArticles['All']?.isNotEmpty == true) {
              // Use cached articles immediately
              _articles = _categoryArticles['All']!;
              _isLoading = false;
              _error = '';
              AppLogger.info(' SWIPE TO ALL: Using cached articles (${_articles.length} articles)');
            } else {
              // No cache, load fresh
              AppLogger.info(' SWIPE TO ALL: No cache, loading fresh');
              _loadAllCategorySimple();
            }
          } else if (_categoryArticles[newCategory]?.isNotEmpty == true) {
            // CRITICAL FIX: Only update if not actively scrolling
            if (!ScrollStateService.isActivelyScrolling) {
              _articles = _categoryArticles[newCategory]!;
              _isLoading = false;
              AppLogger.success('📖 CATEGORY SWITCH: Updated UI for $newCategory (user not scrolling)');
            }
          } else {
            _isLoading = true;
            _loadArticlesByCategoryForCache(newCategory);
          }
        });
        
        // Auto-scroll category pills to keep selected category visible
        final categoryIndex = categories.indexOf(newCategory);
        if (categoryIndex != -1) {
          // Use a delayed call to ensure ScrollController is ready
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted && _categoryScrollController.hasClients) {
              try {
                CategoryScrollService.scrollToSelectedCategoryAccurate(
                  context, _categoryScrollController, categoryIndex, categories);
              } catch (e) {
                // Silently handle scroll controller errors
              }
            }
          });
        }
      },
      (index) => setState(() => _currentIndex = index),
      _loadMoreArticlesForCategory,  // Use the new load more function for infinite scrolling
      _loadAllCategorySimple,  // Use simple load for "All" category
      _colorCache,
      _articlePageControllers, // Pass PageControllers for bidirectional scrolling
    ),
        ),
      ],
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
    // Use dynamically discovered categories
    final categories = _discoveredCategories.toList();

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
                  // Also scroll to tapped category with delay
                  Future.delayed(const Duration(milliseconds: 50), () {
                    if (mounted && _categoryScrollController.hasClients) {
                      try {
                        CategoryScrollService.scrollToSelectedCategoryAccurate(
                          context, _categoryScrollController, index, categories);
                      } catch (e) {
                        AppLogger.log('ScrollController error on tap: $e');
                      }
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? Colors.white 
                      : Colors.white.withValues(alpha: 0.2),
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
    final categories = _discoveredCategories.toList();
    
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
      // Check if we already have "All" category articles cached
      if (_categoryArticles['All']?.isNotEmpty == true) {
        // Use cached articles immediately to avoid "no articles" flash
        setState(() {
          _articles = _categoryArticles['All']!;
          _isLoading = false;
          _error = '';
        });
        AppLogger.info(' QUICK SWITCH: Using cached All articles (${_articles.length} articles)');
      } else {
        // No cache available, load fresh
        AppLogger.info(' FRESH LOAD: No All cache available, loading fresh');
        _loadAllCategorySimple();
      }
    } else {
      _preloadCategoryIfNeeded(category);
    }
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
      
      // CRITICAL FIX: Only update UI if user is not actively scrolling
      if (category == _selectedCategory && !ScrollStateService.isActivelyScrolling) {
        setState(() {
          _articles = unreadArticles;
          _isLoading = false;
        });
        AppLogger.success('📖 CATEGORY LOAD: Updated UI for $category (user not scrolling)');
        
        // Use optimized preloading for this category
        if (unreadArticles.isNotEmpty) {
          OptimizedImageService.preloadCategoryImages(unreadArticles, maxImages: 8);
        }
      }
    } catch (e) {
      _categoryLoading[category] = false;
      AppLogger.log('Error pre-loading $category: $e');
    }
  }

  Future<void> _loadMoreArticlesForCategory(String category) async {
    // Prevent multiple simultaneous loads
    if (_categoryLoading[category] == true) {
      AppLogger.info(' LOAD MORE: Already loading $category, skipping...');
      return;
    }
    
    // Check if we already have enough articles (buffer of 30+)
    final currentArticles = _categoryArticles[category] ?? [];
    if (currentArticles.length >= 100) {
      AppLogger.info(' LOAD MORE: Already have ${currentArticles.length} articles for $category, sufficient buffer');
      return;
    }
    
    // CRITICAL FIX: Don't load more articles while user is actively scrolling
    // This prevents article list changes that cause "next article changes" issue
    if (ScrollStateService.isActivelyScrolling) {
      AppLogger.info(' LOAD MORE: User actively scrolling, delaying load to prevent article changes');
      // Retry after scrolling stops
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (!ScrollStateService.isActivelyScrolling) {
          _loadMoreArticlesForCategory(category);
        }
      });
      return;
    }
    
    try {
      _categoryLoading[category] = true;
      AppLogger.info(' LOAD MORE: Loading additional articles for $category');
      
      final readIds = await ReadArticlesService.getReadArticleIds();
      final currentArticles = _categoryArticles[category] ?? [];
      
      // Get IDs of articles we already have to avoid duplicates
      final existingIds = currentArticles.map((a) => a.id).toSet();
      
      List<NewsArticle> newArticles = [];
      
      if (category == 'All') {
        // For "All" category, fetch from all categories
        final allCategories = [
          'Technology', 'Business', 'Sports', 'Health', 'Science', 
          'Entertainment', 'World', 'Top', 'Travel', 'Politics', 
          'National', 'India', 'Education'
        ];
        
        final List<NewsArticle> allCombinedArticles = [];
        
        // Fetch more articles from each category
        final futures = allCategories.map((cat) async {
          try {
            // Fetch with higher limit and offset to get different articles
            final categoryArticles = await SupabaseService.getUnreadNewsByCategory(cat, readIds, limit: 20, offset: currentArticles.length ~/ allCategories.length);
            return categoryArticles;
          } catch (e) {
            return <NewsArticle>[];
          }
        });
        
        final results = await Future.wait(futures);
        for (final articles in results) {
          allCombinedArticles.addAll(articles);
        }
        
        // Remove duplicates and articles we already have
        final uniqueArticles = <String, NewsArticle>{};
        for (final article in allCombinedArticles) {
          if (!existingIds.contains(article.id)) {
            uniqueArticles[article.id] = article;
          }
        }
        
        newArticles = uniqueArticles.values.where((article) => 
          article.title.trim().isNotEmpty && 
          article.description.trim().isNotEmpty
        ).toList();
        
        // 🎯 STABILIZED: Don't shuffle new articles to prevent order changes
        // newArticles.shuffle(); // REMOVED: No shuffling during load more
      } else {
        // For specific categories
        String dbCategory = _mapUIToDatabaseCategory(category);
        
        // Fetch more articles with offset
        final moreArticles = await SupabaseService.getUnreadNewsByCategory(
          dbCategory, 
          readIds, 
          limit: 20, 
          offset: currentArticles.length
        );
        
        // Filter out articles we already have
        newArticles = moreArticles.where((article) => 
          !existingIds.contains(article.id) &&
          article.title.trim().isNotEmpty && 
          article.description.trim().isNotEmpty
        ).toList();
      }
      
      if (newArticles.isNotEmpty) {
        // Append new articles to existing ones
        final updatedArticles = [...currentArticles, ...newArticles];
        _categoryArticles[category] = updatedArticles;
        
        AppLogger.info(' LOAD MORE: Added ${newArticles.length} new articles to $category (total: ${updatedArticles.length})');
        
        // CRITICAL FIX: DON'T update UI during active scrolling to prevent article changes
        if (category == _selectedCategory && !ScrollStateService.isActivelyScrolling) {
          setState(() {
            _articles = updatedArticles;
          });
          AppLogger.success('📖 LOAD MORE: Updated UI with ${updatedArticles.length} articles (user not scrolling)');
        } else if (category == _selectedCategory) {
          AppLogger.info('📖 LOAD MORE: Articles loaded but UI not updated (user actively scrolling)');
        }
      } else {
        AppLogger.info(' LOAD MORE: No new articles found for $category');
        
        // IMPROVED: Try alternative strategies when no new articles are found
        await _handleNoMoreArticles(category, currentArticles);
      }
      
      _categoryLoading[category] = false;
    } catch (e) {
      _categoryLoading[category] = false;
      AppLogger.error(': $e');
    }
  }

  String _mapUIToDatabaseCategory(String category) {
    // Map UI category names to database category names
    switch (category) {
      case 'Tech': return 'Technology';
      case 'Entertainment': return 'Entertainment';
      case 'Business': return 'Business';
      case 'Health': return 'Health';
      case 'Sports': return 'Sports';
      case 'Science': return 'Science';
      case 'World': return 'World';
      case 'Top': return 'Top';
      case 'Travel': return 'Travel';
      case 'Startups': return 'Startups';
      case 'Politics': return 'Politics';
      case 'National': return 'National';
      case 'India': return 'India';
      case 'Education': return 'Education';
      case 'Celebrity': return 'Celebrity';
      case 'Scandal': return 'Scandal';
      case 'Viral': return 'Viral';
      case 'State': return 'State';
      default: return category;
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
      
      AppLogger.log('=== LOADING CATEGORY: $category ===');
      AppLogger.log('Read articles count: ${readIds.length}');
      
      // Special handling for "All" category - load random mix from all categories
      if (category == 'All') {
        AppLogger.debug(' ALL: Loading ALL categories - fetching from all available categories');
        
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
            AppLogger.debug(' ALL: Fetched ${categoryArticles.length} unread articles from $cat');
            return categoryArticles;
          } catch (e) {
            AppLogger.debug(' ALL: Error fetching $cat articles: $e');
            return <NewsArticle>[];
          }
        });
        
        final results = await Future.wait(futures);
        for (final articles in results) {
          allCombinedArticles.addAll(articles);
        }
        
        AppLogger.debug(' ALL: Total combined articles from all categories: ${allCombinedArticles.length}');
        
        // Remove duplicates based on article ID
        final uniqueArticles = <String, NewsArticle>{};
        for (final article in allCombinedArticles) {
          uniqueArticles[article.id] = article;
        }
        final deduplicatedArticles = uniqueArticles.values.toList();
        AppLogger.debug(' ALL: After deduplication: ${deduplicatedArticles.length} unique articles');
        
        // Simple validation - just check for basic content
        final validArticles = deduplicatedArticles.where((article) => 
          article.title.trim().isNotEmpty && 
          article.description.trim().isNotEmpty
        ).toList();
        AppLogger.debug(' ALL: Valid articles after basic filtering: ${validArticles.length}');
        
        // 🎯 STABILIZED: Don't shuffle during loading - maintain stable order
        // validArticles.shuffle(); // REMOVED: No shuffling during loading
        AppLogger.debug('🎯 ALL: Loaded ${validArticles.length} articles from all categories (STABLE ORDER)');
        
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
          AppLogger.debug(' ALL: Updated UI for ALL: ${validArticles.length} mixed articles from all categories displayed');
          
          // Preload colors for immediate display
          if (validArticles.isNotEmpty) {
            _preloadColors();
          }
        }
        
        AppLogger.debug(' ALL: Pre-loaded All: ${validArticles.length} articles from all categories');
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
      } else if (category == 'Celebrity') {
        dbCategory = 'Celebrity';
      } else if (category == 'Scandal') {
        dbCategory = 'Scandal';
      } else if (category == 'India') {
        dbCategory = 'India';
      } else if (category == 'State') {
        dbCategory = 'State';
      } else {
        // For detected state names, use them as-is
        dbCategory = category;
      }
      
      AppLogger.log('UI Category: "$category" -> DB Category: "$dbCategory"');
      
      // Use the new method that directly fetches unread articles - get more to ensure enough unread
      final unreadCategoryArticles = await SupabaseService.getUnreadNewsByCategory(dbCategory, readIds, limit: 50);
      AppLogger.log('Found ${unreadCategoryArticles.length} unread articles for "$dbCategory"');
      
      // Debug: Also try the old method to compare
      final allCategoryArticles = await SupabaseService.getNewsByCategory(dbCategory, limit: 100);
      AppLogger.debug(': Total articles in "$dbCategory" category: ${allCategoryArticles.length}');
      
      if (allCategoryArticles.isNotEmpty) {
        final readCount = allCategoryArticles.where((article) => readIds.contains(article.id)).length;
        AppLogger.debug(': $dbCategory breakdown - Total: ${allCategoryArticles.length}, Read: $readCount, Should be unread: ${allCategoryArticles.length - readCount}');
        
        // Show first few article titles for debugging
        AppLogger.debug(': First 3 articles in $dbCategory:');
        for (int i = 0; i < allCategoryArticles.length && i < 3; i++) {
          final article = allCategoryArticles[i];
          final isRead = readIds.contains(article.id);
          AppLogger.log('  ${i+1}. "${article.title}" (ID: ${article.id}) - ${isRead ? "READ" : "UNREAD"}');
        }
      }
      
      // Filter out articles with no content and mark them as read
      final validCategoryArticles = unreadCategoryArticles;
      AppLogger.log('Filtered to ${validCategoryArticles.length} valid articles for $dbCategory');
      
      _categoryArticles[category] = validCategoryArticles;
      _categoryLoading[category] = false;
      
      // Always update the main articles if this is for the current category
      if (category == _selectedCategory) {
        setState(() {
          _articles = validCategoryArticles;
          _isLoading = false;
        });
        AppLogger.log('Updated UI for $category: ${validCategoryArticles.length} articles displayed');
      }
      
      if (validCategoryArticles.isNotEmpty) {
        AppLogger.log('Pre-loaded $category: ${validCategoryArticles.length} valid articles available');
      } else {
        AppLogger.log('No unread $category articles found - checking if category exists...');
        // Check if category exists at all by getting a small sample
        final sampleCategoryArticles = await SupabaseService.getNewsByCategory(dbCategory, limit: 5);
        if (sampleCategoryArticles.isNotEmpty) {
          AppLogger.log('$category exists in database but all articles have been read');
        } else {
          AppLogger.log('No $category articles found in database at all');
        }
      }
    } catch (e) {
      _categoryLoading[category] = false;
      AppLogger.log('Error pre-loading $category: $e');
    }
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


  Future<void> _loadAllCategorySimple() async {
    AppLogger.info('🚀 PROGRESSIVE LOAD: Starting progressive article loading');
    
    // Show loading immediately
    setState(() {
      _isLoading = true;
      _error = '';
      _articles = []; // Clear any existing articles
    });

    try {
      // Get fresh read IDs first
      final freshReadIds = await ReadArticlesService.getReadArticleIds();
      AppLogger.info('🚀 PROGRESSIVE LOAD: Got ${freshReadIds.length} read article IDs');
      
      // Start progressive loading - load articles in small batches and show immediately
      await _loadArticlesProgressively(freshReadIds);
      
    } catch (e) {
      AppLogger.error('🚀 PROGRESSIVE LOAD ERROR: $e');
      setState(() {
        _error = ErrorMessageService.getUserFriendlyMessage(e.toString());
        _isLoading = false;
        _isInitialLoad = false;
      });
    }
  }

  /// Load articles progressively - show first batch immediately, then load more in background
  /// STABILIZED: No shuffling during progressive loading to prevent article order changes
  Future<void> _loadArticlesProgressively(List<String> readIds) async {
    final List<NewsArticle> allProgressiveArticles = [];
    bool hasShownFirstBatch = false;
    
    // Define categories to load from
    final categories = [
      'Technology', 'Business', 'Sports', 'Health', 'Science', 
      'Entertainment', 'World', 'Top', 'Travel', 'Politics'
    ];
    
    AppLogger.info('🚀 PROGRESSIVE STABLE: Loading from ${categories.length} categories with stable order');
    
    // Load categories one by one and show articles as they arrive
    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      
      try {
        // Load articles from this category
        final categoryArticles = await SupabaseService.getUnreadNewsByCategory(
          category, readIds, limit: 8 // Small batch size for speed
        );
        
        if (categoryArticles.isNotEmpty) {
          // Add to our progressive collection
          allProgressiveArticles.addAll(categoryArticles);
          
          // Remove duplicates but MAINTAIN ORDER - no shuffling during progressive loading
          final uniqueArticles = <String, NewsArticle>{};
          final stableOrderedArticles = <NewsArticle>[];
          
          for (final article in allProgressiveArticles) {
            if (!uniqueArticles.containsKey(article.id)) {
              uniqueArticles[article.id] = article;
              stableOrderedArticles.add(article); // Maintain insertion order
            }
          }
          
          AppLogger.info('🚀 PROGRESSIVE STABLE: Got ${categoryArticles.length} from $category (total: ${stableOrderedArticles.length})');
          
          // Show articles immediately after first successful category OR if we have enough articles
          if (!hasShownFirstBatch && (stableOrderedArticles.length >= 5 || i >= 2)) {
            AppLogger.success('🚀 PROGRESSIVE STABLE: SHOWING FIRST BATCH - ${stableOrderedArticles.length} articles (NO SHUFFLE)');
            
            // Update UI immediately with first batch - NO SHUFFLING
            setState(() {
              _articles = stableOrderedArticles;
              _isLoading = false; // Stop loading spinner
              _isInitialLoad = false;
              _error = '';
            });
            
            // Cache for "All" category
            _categoryArticles['All'] = stableOrderedArticles;
            _categoryLoading['All'] = false;
            
            hasShownFirstBatch = true;
            
            // 🚀 ASYNC: Start all preloading asynchronously - don't wait!
            _startAsyncPreloading(stableOrderedArticles);
            
            // CRITICAL FIX: Mark first article as read immediately when showing first batch
            if (stableOrderedArticles.isNotEmpty) {
              ReadArticlesService.markAsRead(stableOrderedArticles.first.id);
              AppLogger.success('📖 FIRST BATCH MARKED: "${stableOrderedArticles.first.title}" (ID: ${stableOrderedArticles.first.id}) - user viewing first article');
            }
            
            AppLogger.success('🚀 PROGRESSIVE STABLE: UI updated with first ${stableOrderedArticles.length} articles (STABLE ORDER)');
          } else if (hasShownFirstBatch) {
            // CRITICAL FIX: DON'T update UI during background loading - only update cache
            _categoryArticles['All'] = stableOrderedArticles;
            
            AppLogger.info('🚀 PROGRESSIVE STABLE: Background cache update - now ${stableOrderedArticles.length} articles (UI NOT CHANGED)');
          }
        }
        
        // Small delay between categories to prevent overwhelming the database
        if (i < categories.length - 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
      } catch (e) {
        AppLogger.error('🚀 PROGRESSIVE STABLE: Error loading $category: $e');
        // Continue with next category
      }
    }
    
    // Final update - ONLY NOW do we shuffle for variety
    if (allProgressiveArticles.isNotEmpty) {
      final uniqueArticles = <String, NewsArticle>{};
      for (final article in allProgressiveArticles) {
        uniqueArticles[article.id] = article;
      }
      final finalArticles = uniqueArticles.values.toList();
      
      // 🎯 CRITICAL FIX: Only shuffle ONCE at the very end
      finalArticles.shuffle();
      
      AppLogger.success('🚀 PROGRESSIVE STABLE: FINAL SHUFFLE - Shuffling ${finalArticles.length} articles ONCE at completion');
      
      // CRITICAL FIX: DON'T update UI if user is already viewing articles - only update cache
      if (!hasShownFirstBatch) {
        // Only update UI if we haven't shown anything yet
        setState(() {
          _articles = finalArticles;
          _isLoading = false;
          _isInitialLoad = false;
          _error = finalArticles.isEmpty ? 'All articles have been read!' : '';
        });
        AppLogger.success('🚀 PROGRESSIVE STABLE: Final UI update with ${finalArticles.length} articles');
      } else {
        // User is already viewing articles - just update cache silently
        AppLogger.info('🚀 PROGRESSIVE STABLE: Final cache update - user continues viewing current articles');
      }
      
      _categoryArticles['All'] = finalArticles;
      _categoryLoading['All'] = false;
      
      AppLogger.success('🚀 PROGRESSIVE STABLE: COMPLETE - Final count: ${finalArticles.length} articles (SHUFFLED ONCE)');
      
      // 🚀 ASYNC: Start all background services asynchronously
      _startAsyncPreloading(finalArticles);
      _startBackgroundPreloading();
      
    } else if (!hasShownFirstBatch) {
      // No articles found at all
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
        _error = 'No articles available';
      });
      AppLogger.info('🚀 PROGRESSIVE STABLE: No articles found in any category');
    }
  }

  void _startDynamicCategoryDiscovery() {
    AppLogger.debug(' DISCOVERY: Starting dynamic category discovery...');
    
    DynamicCategoryDiscoveryService.discoverCategoriesInParallel(
      onCategoryDiscovered: (String dbCategory, List<NewsArticle> articles) {
        final uiCategory = DynamicCategoryDiscoveryService.getUIFriendlyName(dbCategory);
        
        AppLogger.success(' DISCOVERY: Found $uiCategory ($dbCategory) with ${articles.length} articles');
        
        if (mounted) {
          setState(() {
            _discoveredCategories.add(uiCategory);
            _categoryArticles[uiCategory] = articles;
            _categoryLoading[uiCategory] = false;
          });
          
          AppLogger.log('🎯 DISCOVERY: Added $uiCategory to UI. Total categories: ${_discoveredCategories.length}');
        }
      },
      onCategoryEmpty: (String category) {
        AppLogger.error(' DISCOVERY: $category is empty, skipping');
      },
      onDiscoveryComplete: () {
        AppLogger.log('🎯 DISCOVERY: Complete! Found ${_discoveredCategories.length} total categories');
        AppLogger.log('🎯 DISCOVERY: Categories: ${_discoveredCategories.toList()}');
      },
    );
  }

  /// 🚀 ASYNC: Start all preloading asynchronously - NEVER BLOCKS UI
  void _startAsyncPreloading(List<NewsArticle> articles) {
    if (articles.isEmpty) return;
    
    AppLogger.info('🚀 ASYNC PRELOAD: Starting all preloading for ${articles.length} articles');
    
    // 🎯 ASYNC PRINCIPLE: Fire everything simultaneously, don't wait for anything!
    
    // 1. Images - Start immediately
    _preloadImagesAsync(articles);
    
    // 2. Colors - Start immediately  
    _preloadColorsAsync(articles);
    
    // 3. Instant preloader - Start immediately
    _startInstantPreloaderAsync(articles);
    
    AppLogger.success('🚀 ASYNC PRELOAD: All preloading started (running in background)');
  }
  
  /// Preload images completely asynchronously
  void _preloadImagesAsync(List<NewsArticle> articles) {
    Future.microtask(() async {
      try {
        AppLogger.info('🖼️ ASYNC IMAGES: Starting image preloading for ${articles.length} articles...');
        
        // Start multiple image preloading strategies simultaneously
        Future.microtask(() => OptimizedImageService.preloadImagesAggressively(articles, 0, preloadCount: 25));
        Future.microtask(() => InstantPreloaderService.startInstantPreloading(articles));
        
        AppLogger.success('🖼️ ASYNC IMAGES: Image preloading started!');
      } catch (e) {
        AppLogger.error('🖼️ ASYNC IMAGES: Image preload error (continuing): $e');
      }
    });
  }
  
  /// Preload colors completely asynchronously
  void _preloadColorsAsync(List<NewsArticle> articles) {
    Future.microtask(() async {
      try {
        AppLogger.info('🎨 ASYNC COLORS: Starting color extraction for ${articles.length} articles...');
        
        // Start color preloading for first batch
        Future.microtask(() => _preloadColors());
        Future.microtask(() => ParallelColorService.preloadColorsParallel(articles, 0, colorPreloadCount: 15));
        
        AppLogger.success('🎨 ASYNC COLORS: Color extraction started!');
      } catch (e) {
        AppLogger.error('🎨 ASYNC COLORS: Color extraction error (continuing): $e');
      }
    });
  }
  
  /// Start instant preloader asynchronously
  void _startInstantPreloaderAsync(List<NewsArticle> articles) {
    Future.microtask(() async {
      try {
        AppLogger.info('⚡ ASYNC INSTANT: Starting instant preloader...');
        InstantPreloaderService.startInstantPreloading(articles);
        AppLogger.success('⚡ ASYNC INSTANT: Instant preloader started!');
      } catch (e) {
        AppLogger.error('⚡ ASYNC INSTANT: Instant preloader error (continuing): $e');
      }
    });
  }

  void _startBackgroundPreloading() {
    // Start preloading individual categories in background after main content loads
    Future.delayed(Duration(milliseconds: 2000), () {
      AppLogger.info(' Starting background preloading of individual categories');
      _preloadPopularCategories();
      _preloadAllCategories();
    });
  }

  /// Handle the case when no more articles are available for a category
  Future<void> _handleNoMoreArticles(String category, List<NewsArticle> currentArticles) async {
    try {
      AppLogger.info(' NO MORE ARTICLES: Implementing fallback strategies for $category');
      
      // Strategy 1: If current category has very few articles, try loading from similar categories
      if (currentArticles.length < 10) {
        AppLogger.info(' FALLBACK 1: Loading from similar categories to supplement $category');
        await _loadFromSimilarCategories(category);
        return;
      }
      
      // Strategy 2: If this is a specific category, suggest switching to "All"
      if (category != 'All') {
        AppLogger.info(' FALLBACK 2: $category exhausted, preparing All category as fallback');
        // Preload "All" category in background so user can switch
        if (_categoryArticles['All']?.isEmpty != false) {
          _loadAllCategorySimple();
        }
        
        // Show a subtle hint to user (could be implemented as a toast or UI hint)
        if (mounted && category == _selectedCategory) {
          _showCategoryExhaustedHint(category);
        }
      } else {
        // Strategy 3: For "All" category, try refreshing with different parameters
        AppLogger.info(' FALLBACK 3: All category exhausted, trying extended refresh');
        await _extendedRefreshAllCategory();
      }
      
    } catch (e) {
      AppLogger.error(' FALLBACK ERROR: $e');
    }
  }
  
  /// Load articles from categories similar to the current one
  Future<void> _loadFromSimilarCategories(String category) async {
    final similarCategories = _getSimilarCategories(category);
    
    for (String similarCategory in similarCategories) {
      try {
        final readIds = await ReadArticlesService.getReadArticleIds();
        final similarArticles = await SupabaseService.getUnreadNewsByCategory(
          similarCategory, readIds, limit: 10
        );
        
        if (similarArticles.isNotEmpty) {
          // Add similar articles to current category
          final currentArticles = _categoryArticles[category] ?? [];
          final updatedArticles = [...currentArticles, ...similarArticles];
          _categoryArticles[category] = updatedArticles;
          
          if (category == _selectedCategory) {
            setState(() {
              _articles = updatedArticles;
            });
          }
          
          AppLogger.success(' FALLBACK SUCCESS: Added ${similarArticles.length} articles from $similarCategory to $category');
          break; // Stop after finding articles from one similar category
        }
      } catch (e) {
        AppLogger.error(' FALLBACK ERROR loading from $similarCategory: $e');
      }
    }
  }
  
  /// Get categories similar to the given category
  List<String> _getSimilarCategories(String category) {
    final categoryGroups = {
      'Technology': ['Science', 'Business', 'Startups'],
      'Science': ['Technology', 'Health', 'Education'],
      'Business': ['Technology', 'Politics', 'National'],
      'Sports': ['Entertainment', 'Health'],
      'Entertainment': ['Sports', 'Celebrity'],
      'Health': ['Science', 'Sports'],
      'World': ['Politics', 'National', 'India'],
      'Politics': ['World', 'National', 'Business'],
      'National': ['Politics', 'India', 'World'],
      'India': ['National', 'Politics', 'World'],
    };
    
    return categoryGroups[category] ?? ['Technology', 'Business', 'World'];
  }
  
  /// Show a hint that the current category is exhausted
  void _showCategoryExhaustedHint(String category) {
    // This could show a toast or subtle UI hint
    AppLogger.info(' HINT: $category category exhausted, user might want to try "All" or other categories');
    // Implementation could include showing a toast suggesting to try "All" category
  }
  
  /// Extended refresh for "All" category when exhausted
  Future<void> _extendedRefreshAllCategory() async {
    try {
      AppLogger.info(' EXTENDED REFRESH: Trying to get more articles for All category');
      
      // Try getting articles with a larger limit and different sorting
      final allArticles = await SupabaseService.getNews(limit: 200); // Increased limit
      
      if (allArticles.isNotEmpty) {
        final freshReadIds = await ReadArticlesService.getReadArticleIds();
        final unreadArticles = allArticles.where((article) => 
          !freshReadIds.contains(article.id)
        ).toList();
        
        // 🎯 STABILIZED: Don't shuffle during refresh - maintain stable order
        // unreadArticles.shuffle(); // REMOVED: No shuffling during refresh
        
        if (unreadArticles.isNotEmpty) {
          _categoryArticles['All'] = unreadArticles;
          
          if (_selectedCategory == 'All') {
            setState(() {
              _articles = unreadArticles;
              _error = '';
            });
          }
          
          AppLogger.success(' EXTENDED REFRESH: Found ${unreadArticles.length} articles for All category');
        }
      }
    } catch (e) {
      AppLogger.error(' EXTENDED REFRESH ERROR: $e');
    }
  }

  /// Load fresh articles in background without disrupting user's current reading
  /// SMART STRATEGY: Only update cache, don't change what user is currently viewing
  Future<void> _loadFreshArticlesInBackground() async {
    try {
      AppLogger.info('🔄 SMART REFRESH: Loading fresh articles in background (non-disruptive)');
      
      // Get fresh read IDs
      final freshReadIds = await ReadArticlesService.getReadArticleIds();
      
      // Load fresh articles from all categories
      final allCategories = [
        'Technology', 'Business', 'Sports', 'Health', 'Science', 
        'Entertainment', 'World', 'Top', 'Travel', 'Politics'
      ];
      
      final List<NewsArticle> allFreshArticles = [];
      
      // Fetch fresh articles from each category in parallel
      final futures = allCategories.map((cat) async {
        try {
          final categoryArticles = await SupabaseService.getUnreadNewsByCategory(cat, freshReadIds, limit: 20);
          return categoryArticles;
        } catch (e) {
          AppLogger.error('🔄 SMART REFRESH: Error loading $cat: $e');
          return <NewsArticle>[];
        }
      });
      
      final results = await Future.wait(futures);
      for (final articles in results) {
        allFreshArticles.addAll(articles);
      }
      
      // Remove duplicates
      final uniqueArticles = <String, NewsArticle>{};
      for (final article in allFreshArticles) {
        uniqueArticles[article.id] = article;
      }
      final freshArticles = uniqueArticles.values.toList();
      
      if (freshArticles.isNotEmpty) {
        // 🎯 CRITICAL: Only update cache, DON'T change what user is currently viewing
        _categoryArticles['All'] = freshArticles;
        
        // Save fresh articles to local storage for next app launch
        await LocalStorageService.saveArticles(freshArticles);
        
        AppLogger.success('🔄 SMART REFRESH: Updated cache with ${freshArticles.length} fresh articles (USER NOT DISRUPTED)');
        AppLogger.info('🔄 SMART REFRESH: User continues reading current articles, fresh ones ready for next session');
      } else {
        AppLogger.info('🔄 SMART REFRESH: No new articles found, cache unchanged');
      }
      
    } catch (e) {
      AppLogger.error('🔄 SMART REFRESH ERROR: $e (continuing silently)');
      // Fail silently - don't disrupt user experience
    }
  }

  /// Refresh the current category by clearing cache and fetching fresh data
  Future<void> _refreshCurrentCategory() async {
    AppLogger.info(' REFRESH: Refreshing $_selectedCategory category');
    
    try {
      // Clear cache for current category to force fresh fetch
      _categoryArticles.remove(_selectedCategory);
      _categoryLoading.remove(_selectedCategory);
      
      // Clear color cache to ensure fresh colors
      _colorCache.clear();
      
      // Reset current index
      setState(() {
        _currentIndex = 0;
        _isLoading = true;
        _error = '';
      });
      
      // Fetch fresh data based on category
      if (_selectedCategory == 'All') {
        await _loadAllCategorySimple();
      } else {
        await _loadArticlesByCategoryForCache(_selectedCategory);
      }
      
      AppLogger.success(' REFRESH: Successfully refreshed $_selectedCategory');
      
    } catch (e) {
      AppLogger.error(' REFRESH ERROR: $e');
      setState(() {
        _error = 'Failed to refresh: $e';
        _isLoading = false;
      });
    }
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
          color: Colors.white.withValues(alpha: 0.2),
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