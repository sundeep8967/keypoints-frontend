import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/news_article.dart';
import '../services/supabase_service.dart';
import '../services/color_extraction_service.dart';
import '../services/read_articles_service.dart';
import '../services/category_scroll_service.dart';
import '../services/news_ui_service.dart';
import '../services/article_management_service.dart';
import '../services/category_loading_service.dart';
import '../services/category_management_service.dart';
import '../services/dynamic_category_discovery_service.dart';
import '../widgets/news_feed_page_builder.dart';
import '../services/image_preloader_service.dart';
import '../services/optimized_image_service.dart';
import '../services/error_message_service.dart';
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
  final Map<String, bool> _categoryDiscoveryInProgress = {};
  
  // Animation controllers for swipe
  late AnimationController _animationController;
  late PageController _categoryPageController;
  late ScrollController _categoryScrollController;
  
  // Store category pill positions for accurate scrolling
  final List<GlobalKey> _categoryKeys = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeCategories();
    // Initialize optimized image cache
    OptimizedImageService.initializeCache();
    // Load "All" category immediately and simply
    _loadAllCategorySimple();
    
  }

  void _initializeCategories() {
    // Initialize with just 'All' category
    final initialCategories = ['All'];
    
    // Initialize category page controller
    _categoryPageController = PageController(initialPage: 0);
    
    // Initialize category scroll controller for horizontal pills
    _categoryScrollController = ScrollController();
    
    // Start dynamic category discovery in background
    _startDynamicCategoryDiscovery();
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
      
      // Shuffle to create random mix from all categories
      validArticles.shuffle();
      
      setState(() {
        _articles = validArticles;
        _isLoading = false;
        _isInitialLoad = false;
        _error = validArticles.isEmpty ? 'All articles have been read! You have caught up with all the news. Check back later for new articles.' : '';
      });
      
      if (validArticles.isNotEmpty) {
        _preloadColors();
        // Use optimized image preloading for faster loading
        OptimizedImageService.preloadImagesAggressively(validArticles, 0, preloadCount: 5);
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
          
          // Special handling for "All" category - check cache first
          if (newCategory == 'All') {
            if (_categoryArticles['All']?.isNotEmpty == true) {
              // Use cached articles immediately
              _articles = _categoryArticles['All']!;
              _isLoading = false;
              _error = '';
              print('🚀 SWIPE TO ALL: Using cached articles (${_articles.length} articles)');
            } else {
              // No cache, load fresh
              print('🚀 SWIPE TO ALL: No cache, loading fresh');
              _loadAllCategorySimple();
            }
          } else if (_categoryArticles[newCategory]?.isNotEmpty == true) {
            _articles = _categoryArticles[newCategory]!;
            _isLoading = false;
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
                        print('ScrollController error on tap: $e');
                      }
                    }
                  });
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
        print('🚀 QUICK SWITCH: Using cached All articles (${_articles.length} articles)');
      } else {
        // No cache available, load fresh
        print('🚀 FRESH LOAD: No All cache available, loading fresh');
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
      
      // Always update the main articles if this is for the current category
      if (category == _selectedCategory) {
        setState(() {
          _articles = unreadArticles;
          _isLoading = false;
        });
        
        // Use optimized preloading for this category
        if (unreadArticles.isNotEmpty) {
          OptimizedImageService.preloadCategoryImages(unreadArticles, maxImages: 8);
        }
      }
    } catch (e) {
      _categoryLoading[category] = false;
      print('Error pre-loading $category: $e');
    }
  }

  Future<void> _loadMoreArticlesForCategory(String category) async {
    // Prevent multiple simultaneous loads
    if (_categoryLoading[category] == true) {
      print('🔄 LOAD MORE: Already loading $category, skipping...');
      return;
    }
    
    try {
      _categoryLoading[category] = true;
      print('🔄 LOAD MORE: Loading additional articles for $category');
      
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
        
        newArticles.shuffle();
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
        
        print('🔄 LOAD MORE: Added ${newArticles.length} new articles to $category (total: ${updatedArticles.length})');
        
        // Update UI if this is the current category
        if (category == _selectedCategory) {
          setState(() {
            _articles = updatedArticles;
          });
        }
      } else {
        print('🔄 LOAD MORE: No new articles found for $category');
      }
      
      _categoryLoading[category] = false;
    } catch (e) {
      _categoryLoading[category] = false;
      print('🔄 LOAD MORE ERROR: $e');
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
      
      print('UI Category: "$category" -> DB Category: "$dbCategory"');
      
      // Use the new method that directly fetches unread articles - get more to ensure enough unread
      final unreadCategoryArticles = await SupabaseService.getUnreadNewsByCategory(dbCategory, readIds, limit: 50);
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
      final validCategoryArticles = unreadCategoryArticles;
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
    print('🚀 SIMPLE LOAD: Starting All category load');
    
    // Show loading immediately
    setState(() {
      _isLoading = true;
      _error = '';
      _articles = []; // Clear any existing articles
    });

    try {
      // Get all articles from database (simple approach)
      final allArticles = await SupabaseService.getNews(limit: 50);
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
        _error = ErrorMessageService.getUserFriendlyMessage(e.toString());
        _isLoading = false;
        _isInitialLoad = false;
      });
    }
  }

  void _startDynamicCategoryDiscovery() {
    print('🔍 DISCOVERY: Starting dynamic category discovery...');
    
    DynamicCategoryDiscoveryService.discoverCategoriesInParallel(
      onCategoryDiscovered: (String dbCategory, List<NewsArticle> articles) {
        final uiCategory = DynamicCategoryDiscoveryService.getUIFriendlyName(dbCategory);
        
        print('✅ DISCOVERY: Found $uiCategory ($dbCategory) with ${articles.length} articles');
        
        if (mounted) {
          setState(() {
            _discoveredCategories.add(uiCategory);
            _categoryArticles[uiCategory] = articles;
            _categoryLoading[uiCategory] = false;
          });
          
          print('🎯 DISCOVERY: Added $uiCategory to UI. Total categories: ${_discoveredCategories.length}');
        }
      },
      onCategoryEmpty: (String category) {
        print('❌ DISCOVERY: $category is empty, skipping');
      },
      onDiscoveryComplete: () {
        print('🎯 DISCOVERY: Complete! Found ${_discoveredCategories.length} total categories');
        print('🎯 DISCOVERY: Categories: ${_discoveredCategories.toList()}');
      },
    );
  }

  void _startBackgroundPreloading() {
    // Start preloading individual categories in background after main content loads
    Future.delayed(Duration(milliseconds: 2000), () {
      print('🔄 Starting background preloading of individual categories');
      _preloadPopularCategories();
      _preloadAllCategories();
    });
  }

  /// Refresh the current category by clearing cache and fetching fresh data
  Future<void> _refreshCurrentCategory() async {
    print('🔄 REFRESH: Refreshing $_selectedCategory category');
    
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
      
      print('✅ REFRESH: Successfully refreshed $_selectedCategory');
      
    } catch (e) {
      print('❌ REFRESH ERROR: $e');
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