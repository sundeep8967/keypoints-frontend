import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../domain/entities/news_article_entity.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';
import '../utils/app_logger.dart';
import '../services/read_articles_service.dart';
import '../services/category_scroll_service.dart';
import '../services/category_loading_service.dart';
import '../services/dynamic_category_discovery_service.dart';
import '../widgets/news_feed_page_builder.dart';
import '../services/admob_service.dart';
import '../models/native_ad_model.dart';
import '../services/optimized_image_service.dart';
import '../services/error_message_service.dart';
import '../services/scroll_state_service.dart';
import '../services/infinite_scroll_service.dart';
import 'settings_screen.dart';
import '../widgets/news_feed_widgets.dart';
import '../injection_container.dart';
import '../services/refactored/service_coordinator.dart';
import '../services/refactored/category_manager_service.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> with TickerProviderStateMixin {
  // Track on-demand ad requests to avoid duplicate loads for the same slot
  final Set<String> _pendingOnDemandAds = {};
  void _logArticleOrder(String label, List<dynamic> list, {int maxItems = 100}) {
    try {
      AppLogger.info('ORDER [$label]: count=${list.length}');
      for (int i = 0; i < list.length && i < maxItems; i++) {
        final item = list[i];
        if (item is NewsArticleEntity) {
          final title = item.title.length > 80 ? item.title.substring(0, 80) + '…' : item.title;
          AppLogger.info('${i + 1}. ${item.id} | ' + title);
        } else {
          AppLogger.info('${i + 1}. [AD ITEM]');
        }
      }
    } catch (e) {
      AppLogger.log('Order logging failed: $e');
    }
  }
  List<dynamic> _feedItems = [];
  bool _isLoading = true;
  String _error = '';
  int _currentIndex = 0;
  String _selectedCategory = 'All'; // Track selected category
  bool _isInitialLoad = true; // Track if this is the first load
  
  // Cache for category articles (dynamic to support ads)
  final Map<String, List<dynamic>> _categoryArticles = {};
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
          _feedItems = articlesToShow;
          _logArticleOrder('QuickLoad cache->UI', _feedItems);
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

  // _loadNewsArticleEntitys removed as unused


  @override
  Widget build(BuildContext context) {
    // Show loading screen during initial load
    if (_isInitialLoad && _isLoading && _feedItems.isEmpty) {
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.black,
        child: Stack(
          children: [
            NewsFeedWidgets.buildLoadingPage(),
            _buildCleanHeader(),
          ],
        ),
      );
    }

    // Show error if no articles and not loading
    if (_feedItems.isEmpty && !_isLoading && _error.isNotEmpty) {
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
          _buildCategoryPageViewWithOnDemandAds(),
          _buildCleanHeader(),
        ],
      ),
    );
  }

  Widget _buildCategoryPageViewWithOnDemandAds() {
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
              // Use cached articles immediately (with ads if present)
              _feedItems = _categoryArticles['All']!;
              _isLoading = false;
              _error = '';
              AppLogger.info(' SWIPE TO ALL: Using cached articles (${_feedItems.length} items)');
            } else {
              // No cache, load fresh
              AppLogger.info(' SWIPE TO ALL: No cache, loading fresh');
              _loadAllCategorySimple();
            }
          } else if (_categoryArticles[newCategory]?.isNotEmpty == true) {
            // CRITICAL FIX: Only update if not actively scrolling
            if (!ScrollStateService.isActivelyScrolling) {
              _feedItems = _categoryArticles[newCategory]!;
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
      _articlePageControllers, // Pass PageControllers for bidirectional scrolling
      _onDemandAdAtIndex,
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
      height: 40, // Slightly taller
      child: ListView.builder(
        controller: _categoryScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == _selectedCategory;
          
          return Padding(
            padding: const EdgeInsets.only(right: 10), // More spacing
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? Colors.white 
                      : Colors.white.withValues(alpha: 0.15), // slightly more visible unselected
                    borderRadius: BorderRadius.circular(20), // Rounder
                    border: Border.all(
                      color: isSelected 
                        ? Colors.white 
                        : Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    boxShadow: isSelected 
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ] 
                      : null,
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.black : Colors.white,
                      letterSpacing: 0.5,
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
          _feedItems = _categoryArticles['All']!;
          _isLoading = false;
          _error = '';
        });
        AppLogger.info(' QUICK SWITCH: Using cached All articles (${_feedItems.length} articles)');
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
    final coordinator = sl<ServiceCoordinator>();
    
    // Check if already loaded or loading
    if (_categoryArticles[category]?.isEmpty == true && !_categoryLoading.containsKey(category)) {
      _categoryLoading[category] = true;
      
      if (category == 'All') {
        _loadNewsArticlesForCategory(category);
      } else {
        // Use coordinator but keep local state update callback
        coordinator.loadCategoryFeed(category).then((articles) {
          if (mounted) {
            setState(() {
              _categoryArticles[category] = articles;
              _categoryLoading[category] = false;
            });
          }
        });
      }
    }
  }

  // On-demand ad creator: image-first preference
  Future<void> _onDemandAdAtIndex(String category, int afterIndex) async {
    try {
      final slotKey = '$category|$afterIndex';
      if (_pendingOnDemandAds.contains(slotKey)) return; // already loading for this slot
      _pendingOnDemandAds.add(slotKey);

      // Prefer a quick-loading banner fallback if native not immediately available
      NativeAdModel? adModel;

      // 1) Try banner fallback first (image/static) for speed
      adModel = await AdMobService.createBannerFallback();

      // 2) If banner not available, try native ad (can be image or video; we already allow image via mediaAspectRatio.any)
      adModel ??= await AdMobService.createNativeAd();

      if (adModel != null) {
        // Insert ad into the current category list right after afterIndex
        final items = _categoryArticles[category] ?? [];
        final insertIndex = (afterIndex + 1).clamp(0, items.length);
        items.insert(insertIndex, adModel);
        _categoryArticles[category] = items;

        // If user is on this category, update feed immediately (only if not actively scrolling to avoid jank)
        if (category == _selectedCategory && !ScrollStateService.isActivelyScrolling) {
          setState(() {
            _feedItems = List<dynamic>.from(items);
          });
        }

        AppLogger.success('📣 ON-DEMAND AD: Inserted ad after index $afterIndex in $category');
      } else {
        AppLogger.warning('⚠️ ON-DEMAND AD: No ad available immediately for $category at $afterIndex');
      }
    } catch (e) {
      AppLogger.error('❌ ON-DEMAND AD ERROR: $e');
    } finally {
      _pendingOnDemandAds.remove('$category|$afterIndex');
    }
  }

  void _preloadAllCategories() {
    final coordinator = sl<ServiceCoordinator>();
    // Trigger background preload via coordinator
    // This mimics the fire-and-forget behavior of the legacy method
    Future.microtask(() async {
      if (coordinator.categoryManager is CategoryManagerService) {
        await (coordinator.categoryManager as CategoryManagerService).preloadPopularCategories();
      }
    });
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
          _feedItems = unreadArticles;
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
    
    // Check if we already have enough articles (buffer of 200+)
    final currentArticles = _categoryArticles[category] ?? [];
    if (currentArticles.length >= 500) {
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
      
      // Filter out ads for logic that requires entities
      final currentEntities = currentArticles.whereType<NewsArticleEntity>().toList();
      
      // ENHANCED: Use the new infinite scroll service for better article loading
      final enhancedNewArticles = await InfiniteScrollService.loadMoreArticlesEnhanced(
        category: category,
        currentArticles: currentEntities,
        readIds: readIds,
      );
      
      if (enhancedNewArticles.isNotEmpty) {
        // Append new articles to existing ones
        final updatedArticles = [...currentArticles, ...enhancedNewArticles];
        
        // Optimize buffer if it gets too large
        List<dynamic> optimizedArticles;
        if (category == 'All') {
           // Simple slicing for dynamic list (All category)
           if (updatedArticles.length > 1000) {
              optimizedArticles = updatedArticles.sublist(updatedArticles.length - 1000);
           } else {
              optimizedArticles = updatedArticles;
           }
        } else {
           // Use service for entity lists
           optimizedArticles = InfiniteScrollService.optimizeBuffer(updatedArticles.cast<NewsArticleEntity>(), _currentIndex);
        }

        _categoryArticles[category] = optimizedArticles;
        
        AppLogger.info(' ENHANCED LOAD MORE: Added ${enhancedNewArticles.length} new articles to $category (total: ${optimizedArticles.length})');
        
        // CRITICAL FIX: DON'T update UI during active scrolling to prevent article changes
        if (category == _selectedCategory && !ScrollStateService.isActivelyScrolling) {
          setState(() {
            _feedItems = optimizedArticles;
          });
          AppLogger.success('📖 ENHANCED LOAD MORE: Updated UI with ${optimizedArticles.length} articles (user not scrolling)');
        } else if (category == _selectedCategory) {
          AppLogger.info('📖 ENHANCED LOAD MORE: Articles loaded but UI not updated (user actively scrolling)');
        }
      } else {
        AppLogger.info(' ENHANCED LOAD MORE: No new articles found for $category');
        
        // IMPROVED: Try alternative strategies when no new articles are found
        await _handleNoMoreArticles(category, currentEntities);
      }
      
      _categoryLoading[category] = false;
    } catch (e) {
      _categoryLoading[category] = false;
      AppLogger.error(': $e');
    }
  }

  // _mapUIToDatabaseCategory removed as unused (logic handled in service)

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
        
        final List<NewsArticleEntity> allCombinedArticles = [];
        
        // Fetch articles from each category in parallel for faster loading
        final futures = allCategories.map((cat) async {
          try {
            final categoryArticles = await SupabaseService.getUnreadNewsByCategory(cat, readIds, limit: 300);
            AppLogger.debug(' ALL: Fetched ${categoryArticles.length} unread articles from $cat');
            return categoryArticles;
          } catch (e) {
            AppLogger.debug(' ALL: Error fetching $cat articles: $e');
            return <NewsArticleEntity>[];
          }
        });
        
        final results = await Future.wait(futures);
        for (final articles in results) {
          allCombinedArticles.addAll(articles);
        }
        
        AppLogger.debug(' ALL: Total combined articles from all categories: ${allCombinedArticles.length}');
        
        // Remove duplicates based on article ID
        final uniqueArticles = <String, NewsArticleEntity>{};
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
            _feedItems = validArticles;
            _isLoading = false;
            _isInitialLoad = false;
            // Only show error if we have no articles AND this is not the initial load
            _error = validArticles.isEmpty && !_isInitialLoad ? 'No unread articles available. Check back later for new content!' : '';
          });
          AppLogger.debug(' ALL: Updated UI for ALL: ${validArticles.length} mixed articles from all categories displayed');
          
          // Preload colors for immediate display
          if (validArticles.isNotEmpty) {
            // Color preloading removed
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
      final unreadCategoryArticles = await SupabaseService.getUnreadNewsByCategory(dbCategory, readIds, limit: 1000);
      AppLogger.log('Found ${unreadCategoryArticles.length} unread articles for "$dbCategory"');
      
      // Debug: Also try the old method to compare
      final allCategoryArticles = await SupabaseService.getNewsByCategory(dbCategory, limit: 1000);
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
          _feedItems = validCategoryArticles;
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


  // Color preloading functionality removed

  // Article loading functionality simplified

  // void _showToast(String message) removed as unused

  void _preloadPopularCategories() {
    final coordinator = sl<ServiceCoordinator>();
    // Delegate to coordinator's background preload
     Future.microtask(() async {
      if (coordinator.categoryManager is CategoryManagerService) {
        await (coordinator.categoryManager as CategoryManagerService).preloadPopularCategories();
      }
    });
  }


  Future<void> _loadAllCategorySimple() async {
    AppLogger.info('🚀 PROGRESSIVE LOAD: Starting progressive article loading');
    
    // Show loading immediately
    setState(() {
      _isLoading = true;
      _error = '';
      _feedItems = []; // Clear any existing articles
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
  Future<void> _loadArticlesProgressively(List<String> readIds) async {
    try {
      AppLogger.info('🚀 PROGRESSIVE STABLE: Starting progressive load via Coordinator');
      
      final stream = ServiceCoordinator().loadFeedProgressivelyWithAds();
      bool hasShownFirstBatch = false;
      
      await for (final feed in stream) {
        if (!mounted) break;
        
        if (!hasShownFirstBatch) {
          // First batch - show immediately
          setState(() {
            _feedItems = feed;
            _logArticleOrder('Progressive first batch -> UI', _feedItems);
            _isLoading = false;
            _isInitialLoad = false;
            _error = '';
          });
          
          // Cache FULL feed including ads
          _categoryArticles['All'] = feed;
          _categoryLoading['All'] = false;
          hasShownFirstBatch = true;
          
          // Extract articles for preloading/tracking
          final articlesOnly = feed.whereType<NewsArticleEntity>().toList();
          
          // Async preloading
          _startAsyncPreloading(articlesOnly);
          
          // Mark first article as read
          if (articlesOnly.isNotEmpty) {
            ReadArticlesService.markAsRead(articlesOnly.first.id);
          }
          
          AppLogger.success('🚀 PROGRESSIVE STABLE: UI updated with first batch (${feed.length} items)');
        } else {
          // Subsequent updates (Mixed Feed)
          _categoryArticles['All'] = feed;
          
          if (_feedItems.isEmpty || _error.isNotEmpty) {
             setState(() {
              _feedItems = feed;
              _isLoading = false;
              _isInitialLoad = false;
              _error = feed.isEmpty ? 'All articles have been read!' : '';
            });
          }
          
          AppLogger.info('🚀 PROGRESSIVE STABLE: Background cache update - ${feed.length} items');
          
          // Async preloading for full list
          final articlesOnly = feed.whereType<NewsArticleEntity>().toList();
          _startAsyncPreloading(articlesOnly);
          _startBackgroundPreloading();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialLoad = false;
          if (_feedItems.isEmpty) {
            _error = 'Unable to load articles. Please check your connection.';
          }
        });
      }
      AppLogger.error('🚀 PROGRESSIVE STABLE: Error: $e');
    }
  }

  void _startDynamicCategoryDiscovery() {
    AppLogger.debug(' DISCOVERY: Starting dynamic category discovery...');
    
    DynamicCategoryDiscoveryService.discoverCategoriesInParallel(
      onCategoryDiscovered: (String dbCategory, List<NewsArticleEntity> articles) {
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
  void _startAsyncPreloading(List<dynamic> items) {
    final articles = items.whereType<NewsArticleEntity>().toList();
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
  void _preloadImagesAsync(List<NewsArticleEntity> articles) {
    Future.microtask(() async {
      try {
        AppLogger.info('🖼️ ASYNC IMAGES: Starting image preloading for ${articles.length} articles...');
        
        // Start multiple image preloading strategies simultaneously
        Future.microtask(() => OptimizedImageService.preloadImagesAggressively(articles, 0, preloadCount: 25));
        
        AppLogger.success('🖼️ ASYNC IMAGES: Image preloading started!');
      } catch (e) {
        AppLogger.error('🖼️ ASYNC IMAGES: Image preload error (continuing): $e');
      }
    });
  }
  
  /// Preload colors completely asynchronously
  void _preloadColorsAsync(List<NewsArticleEntity> articles) {
    Future.microtask(() async {
      try {
        
        
        AppLogger.success('🎨 ASYNC COLORS: Color extraction started!');
      } catch (e) {
        AppLogger.error('🎨 ASYNC COLORS: Color extraction error (continuing): $e');
      }
    });
  }
  
  /// Start instant preloader asynchronously
  void _startInstantPreloaderAsync(List<NewsArticleEntity> articles) {
    Future.microtask(() async {
      try {
        AppLogger.info('⚡ ASYNC INSTANT: Starting instant preloader...');
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
  Future<void> _handleNoMoreArticles(String category, List<NewsArticleEntity> currentArticles) async {
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
              _feedItems = updatedArticles;
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
      final allArticles = await SupabaseService.getNews(limit: 3000); // Much larger limit
      
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
              _feedItems = unreadArticles;
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
  /// Create a balanced mixed feed from all categories for "All" section
  // _createBalancedMixedFeed removed as unused (moved to ServiceCoordinator/NewsLoader)

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
      
      final List<NewsArticleEntity> allFreshArticles = [];
      
      // Fetch fresh articles from each category in parallel
      final futures = allCategories.map((cat) async {
        try {
          final categoryArticles = await SupabaseService.getUnreadNewsByCategory(cat, freshReadIds, limit: 20);
          return categoryArticles;
        } catch (e) {
          AppLogger.error('🔄 SMART REFRESH: Error loading $cat: $e');
          return <NewsArticleEntity>[];
        }
      });
      
      final results = await Future.wait(futures);
      for (final articles in results) {
        allFreshArticles.addAll(articles);
      }
      
      // Remove duplicates
      final uniqueArticles = <String, NewsArticleEntity>{};
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
        width: 40, // Match category height
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: const Icon(
          CupertinoIcons.settings,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  // _buildLoadingShimmer removed as unused
}