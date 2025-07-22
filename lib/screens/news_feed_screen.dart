import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/news_article.dart';
import '../services/supabase_service.dart';
import '../services/color_extraction_service.dart';
import '../services/read_articles_service.dart';

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
    _showSupabaseCategories();
    // Pre-load popular categories for instant switching
    _preloadPopularCategories();
    // Smart read tracking enabled
  }

  void _initializeCategories() {
    final categories = [
      'All',
      'Tech',
      'Science',
      'Environment',
      'Energy',
      'Lifestyle',
      'Business',
      'Entertainment',
      'Health',
      'Sports',
      'World',
      'Trending'
    ];
    
    // Initialize category page controller
    final currentCategoryIndex = categories.indexOf(_selectedCategory);
    _categoryPageController = PageController(initialPage: currentCategoryIndex >= 0 ? currentCategoryIndex : 0);
    
    // Initialize category scroll controller for horizontal pills
    _categoryScrollController = ScrollController();
    
    // Pre-load all categories
    for (String category in categories) {
      _categoryArticles[category] = [];
      _categoryLoading[category] = false;
    }
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

      // PRIORITY 1: Try to load from Supabase first
      try {
        final allArticles = await SupabaseService.getNews(limit: 100);
        if (allArticles.isNotEmpty) {
          // Filter out already read articles
          final readIds = await ReadArticlesService.getReadArticleIds();
          final unreadArticles = allArticles.where((article) => 
            !readIds.contains(article.id)
          ).toList();
          
          // Filter out articles with no content and mark them as read
          final validArticles = await _filterValidArticles(unreadArticles);
          
          setState(() {
            _articles = validArticles;
            _isLoading = false;
          });
          
          print('SUCCESS: Loaded ${allArticles.length} total articles, ${unreadArticles.length} unread, ${validArticles.length} valid from Supabase');
          print('INFO: ${readIds.length} articles already read, ${unreadArticles.length - validArticles.length} auto-marked as read (no content)');
          
          if (validArticles.isEmpty) {
            setState(() {
              _error = 'All articles have been read! You\'ve caught up with all the news. Check back later for new articles.';
            });
          } else {
            _preloadColors();
          }
          return;
        } else {
          print('WARNING: No articles found in Supabase');
        }
      } catch (e) {
        print('ERROR: Supabase failed: $e');
      }

      // No fallback - show error if no Supabase articles
      setState(() {
        _articles = [];
        _isLoading = false;
        _error = 'No articles available. Please check your internet connection and try again.';
      });
      
      print('ERROR: No articles found in Supabase and no fallback used');
    } catch (e) {
      setState(() {
        _error = 'Failed to load articles: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadArticlesByCategoryWithSwipeContext(String category, bool isRightSwipe) async {
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
            if (isRightSwipe) {
              // Right swipe: Just show "You read all" in UI, no popup
              setState(() {
                _articles = [];
                _error = 'You have read all articles in $category category.';
                _isLoading = false;
              });
            } else {
              // Left swipe: Show toast and load all other unread articles
              _showToast('You have read all articles in $category category');
              await _loadAllOtherUnreadArticles();
            }
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
            if (isRightSwipe) {
              // Right swipe: Just show "You read all" in UI, no popup
              setState(() {
                _articles = [];
                _error = 'You have read all articles in $category category.';
                _isLoading = false;
              });
            } else {
              // Left swipe: Show toast and load all other unread articles
              _showToast('You have read all articles in $category category');
              await _loadAllOtherUnreadArticles();
            }
            return;
          } else {
            if (isRightSwipe) {
              // Right swipe: Just show "No articles" in UI, no popup
              setState(() {
                _articles = [];
                _error = 'No $category articles found.';
                _isLoading = false;
              });
            } else {
              // Left swipe: Show toast and switch back to All category
              setState(() {
                _articles = [];
                _error = 'No $category articles found.';
                _isLoading = false;
              });
              _showToast('No $category articles found. Switching back to All categories.');
            }
            return;
          }
        }
      } catch (e) {
        print('ERROR: Failed to filter Supabase articles: $e');
      }

      // PRIORITY 3: If Supabase completely fails
      if (isRightSwipe) {
        // Right swipe: Just show error in UI, no popup
        setState(() {
          _articles = [];
          _error = 'Unable to load $category articles.';
          _isLoading = false;
        });
      } else {
        // Left swipe: Show toast and prepare to switch back to All
        setState(() {
          _articles = [];
          _error = 'Unable to load $category articles.';
          _isLoading = false;
        });
        _showToast('Unable to load $category articles. Switching back to All categories.');
      }
      print('ERROR: Supabase completely unavailable for $category');
    } catch (e) {
      setState(() {
        _error = 'Failed to load articles for $category: $e';
        _isLoading = false;
      });
    }
  }

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
    final categories = [
      'All',
      'Sports',      // 58 articles
      'Top',         // 56 articles  
      'Trending',    // 53 articles
      'Science',     // 51 articles
      'World',       // 51 articles
      'Health',      // 49 articles
      'Business',    // 47 articles
      'Tech',        // 46 articles
      'Entertainment', // 35 articles
      'Travel',      // 9 articles
      'Startups',    // 6 articles
      'Politics',    // 5 articles
      'National',    // 5 articles
      'India',       // 5 articles
      'Education',   // 5 articles
      'Celebrity',   // New category
      'Scandal',     // New category
      'Viral',       // New category
    ];
    
    return PageView.builder(
      scrollDirection: Axis.horizontal,
      physics: const PageScrollPhysics(),
      itemCount: categories.length,
      controller: _categoryPageController,
      onPageChanged: (categoryIndex) {
        final newCategory = categories[categoryIndex];
        if (newCategory != _selectedCategory) {
          print('RIGHT SWIPE DETECTED: Switching from $_selectedCategory to $newCategory');
          setState(() {
            _selectedCategory = newCategory;
            _currentIndex = 0;
          });
          
          // Auto-scroll category pills to keep selected category visible
          _scrollToSelectedCategoryAccurate(categoryIndex);
          
          // Force load the specific category
          if (newCategory == 'All') {
            _loadNewsArticles();
          } else {
            print('Loading specific category: $newCategory');
            _loadArticlesByCategoryForCache(newCategory);
          }
          
          // Check if category is already pre-loaded
          if (_categoryArticles[newCategory]?.isNotEmpty == true) {
            // Category is ready - switch immediately
            setState(() {
              _selectedCategory = newCategory;
              _articles = _categoryArticles[newCategory]!;
              _currentIndex = 0;
              _isLoading = false;
            });
            print('Instant switch to $newCategory: ${_categoryArticles[newCategory]!.length} articles ready');
          } else {
            // Category not ready - show loading state
            setState(() {
              _selectedCategory = newCategory;
              _isLoading = true;
              _currentIndex = 0;
            });
            print('Loading $newCategory on-demand...');
          }
          
          // Update main articles list to match current category
          if (_categoryArticles[newCategory]?.isNotEmpty == true) {
            setState(() {
              _articles = _categoryArticles[newCategory]!;
            });
          }
        }
      },
      itemBuilder: (context, categoryIndex) {
        final category = categories[categoryIndex];
        return _buildCategoryContent(category);
      },
    );
  }

  void _preloadCategoryIfNeeded(String category) {
    if (_categoryArticles[category]?.isEmpty == true && _categoryLoading[category] != true) {
      _categoryLoading[category] = true;
      
      if (category == 'All') {
        _loadNewsArticlesForCategory(category);
      } else {
        _loadArticlesByCategoryForCache(category);
      }
    }
  }

  Widget _buildCategoryContent(String category) {
    final categoryArticles = _categoryArticles[category] ?? [];
    final isLoading = _categoryLoading[category] ?? false;
    
    // Always use category-specific articles, not the main _articles list
    final articlesToShow = categoryArticles;
    
    if (isLoading && articlesToShow.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(
              radius: 20,
              color: Colors.white,
            ),
            SizedBox(height: 16),
            Text(
              'Loading articles...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (articlesToShow.isEmpty) {
      return _buildNoArticlesPage();
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      physics: const PageScrollPhysics(),
      itemCount: articlesToShow.length + 1, // +1 for "end of articles" page
      pageSnapping: true,
      onPageChanged: (index) async {
        print('PAGE CHANGED: Moving to article $index in $category');
        
        // Mark previous article as read when moving to next article
        if (index > 0 && index <= articlesToShow.length && articlesToShow.isNotEmpty) {
          final previousArticle = articlesToShow[index - 1];
          await ReadArticlesService.markAsRead(previousArticle.id);
          
          // Smart read tracking: Remove this article from all category caches
          _removeReadArticleFromCaches(previousArticle.id);
          
          print('Marked article "${previousArticle.title}" as read and removed from all categories');
        }
        
        if (category == _selectedCategory) {
          setState(() {
            _currentIndex = index;
          });
        }
        
        // Only preload colors if we haven't done it recently
        if (index < articlesToShow.length && index % 5 == 0 && index > 0) {
          _preloadColors();
        }
      },
      itemBuilder: (context, index) {
        // Show "end of articles" page after last article
        if (index >= articlesToShow.length) {
          return _buildEndOfArticlesPage();
        }
        
        final article = articlesToShow[index];
        return Container(
          width: double.infinity,
          height: double.infinity,
          child: _buildFullScreenCard(article, index),
        );
      },
    );
  }

  Widget _buildFullScreenCard(NewsArticle article, int index) {
    final cachedPalette = _colorCache[article.imageUrl];
    
    if (cachedPalette != null) {
      return _buildCardWithPalette(article, index, cachedPalette);
    }
    
    return FutureBuilder<ColorPalette>(
      future: ColorExtractionService.extractColorsFromImage(article.imageUrl),
      builder: (context, snapshot) {
        final palette = snapshot.data ?? ColorPalette.defaultPalette();
        
        if (snapshot.data != null) {
          _colorCache[article.imageUrl] = snapshot.data!;
        }
        
        return _buildCardWithPalette(article, index, palette);
      },
    );
  }

  Widget _buildCardWithPalette(NewsArticle article, int index, ColorPalette palette) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: palette.primary,
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 70),
          Container(
            height: MediaQuery.of(context).size.height * 0.3,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.secondary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: CupertinoActivityIndicator(
                              color: palette.onPrimary,
                            ),
                          ),
                          Image.network(
                            article.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: palette.secondary,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Icon(
                                    CupertinoIcons.photo_fill,
                                    size: 60,
                                    color: palette.onPrimary.withOpacity(0.5),
                                  ),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                return child;
                              }
                              return Container(
                                color: Colors.transparent,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 15,
                  left: 15,
                  right: 15,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          article.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: palette.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: palette.onPrimary,
                      height: 1.3,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Text(
                      // Prioritize keypoints, fallback to description
                      article.keypoints?.isNotEmpty == true 
                        ? article.keypoints! 
                        : article.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: palette.onPrimary.withOpacity(0.9),
                        height: 1.5,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: palette.onPrimary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: palette.onPrimary.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _formatTimestamp(article.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.onPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildActionButton(
                                CupertinoIcons.share_up,
                                palette.onPrimary,
                                () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: color,
        ),
      ),
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
              // Three dot menu button
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 32,
                onPressed: _showSettingsMenu,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    CupertinoIcons.ellipsis,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalCategories() {
    // Base categories + dynamically detected states
    final baseCategories = [
      'All',
      'Sports', 'Top', 'Trending', 'Science', 'World', 'Health', 'Business', 
      'Tech', 'Entertainment', 'Travel', 'Startups', 'Politics', 'National', 
      'India', 'Education', 'Celebrity', 'Scandal', 'Viral'
    ];
    
    // Add detected states from current articles
    final detectedStates = _getDetectedStatesFromArticles();
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
                  _scrollToSelectedCategoryAccurate(index);
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


  void _showSettingsMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: const Text(
            'Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          message: const Text('App preferences and settings'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                print('Show feed preferences');
              },
              child: const Text('Feed Preferences'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                print('Show language settings');
              },
              child: const Text('Language'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                print('Show notification settings');
              },
              child: const Text('Notifications'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                print('Show reading history');
              },
              child: const Text('Reading History'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }

  void _selectCategory(String category) {
    final categories = [
      'All',
      'Tech',
      'Science',
      'Environment',
      'Energy',
      'Lifestyle',
      'Business',
      'Entertainment',
      'Health',
      'Sports',
      'World',
      'Trending'
    ];
    
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

  void _preloadAllCategories() {
    final categories = [
      'All',
      'Tech',
      'Science',
      'Environment',
      'Energy',
      'Lifestyle',
      'Business',
      'Entertainment',
      'Health',
      'Sports',
      'World',
      'Trending'
    ];
    
    // First, let's see what categories exist in the database
    _debugDatabaseCategories();
    
    // Pre-load all categories in background
    for (String category in categories) {
      _preloadCategoryIfNeeded(category);
    }
  }

  Future<void> _debugDatabaseCategories() async {
    try {
      final allArticles = await SupabaseService.getNews(limit: 200);
      final uniqueCategories = allArticles.map((article) => article.category).toSet().toList();
      print('=== DATABASE CATEGORIES FOUND ===');
      for (String cat in uniqueCategories) {
        final count = allArticles.where((a) => a.category == cat).length;
        print('Category: "$cat" - $count articles');
      }
      print('=== END DATABASE CATEGORIES ===');
    } catch (e) {
      print('Error debugging categories: $e');
    }
  }

  Future<void> _loadNewsArticlesForCategory(String category) async {
    try {
      final allArticles = await SupabaseService.getNews(limit: 100);
      if (allArticles.isNotEmpty) {
        final readIds = await ReadArticlesService.getReadArticleIds();
        final unreadArticles = allArticles.where((article) => 
          !readIds.contains(article.id)
        ).toList();
        
        _categoryArticles[category] = unreadArticles;
        _categoryLoading[category] = false;
        
        // Always update the main articles if this is for the current category
        if (category == _selectedCategory) {
          setState(() {
            _articles = unreadArticles;
            _isLoading = false;
          });
        }
        
        print('Pre-loaded $category: ${unreadArticles.length} articles');
      }
    } catch (e) {
      _categoryLoading[category] = false;
      print('Error pre-loading $category: $e');
    }
  }

  Future<void> _loadArticlesByCategoryForCache(String category) async {
    try {
      final readIds = await ReadArticlesService.getReadArticleIds();
      
      // Map UI category names to database category names
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
      } else if (category == 'Top') {
        dbCategory = 'top'; // Note: lowercase 'top' in database
      } else {
        // For detected state names, use them as-is
        dbCategory = category;
      }
      
      print('=== LOADING CATEGORY: $category ===');
      print('UI Category: "$category" -> DB Category: "$dbCategory"');
      print('Read articles count: ${readIds.length}');
      
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

  void _selectCategoryWithSwipeContext(String category, bool isRightSwipe) {
    setState(() {
      _selectedCategory = category;
      _currentIndex = 0;
    });
    
    if (category == 'All') {
      _loadNewsArticles();
    } else {
      _loadArticlesByCategoryWithSwipeContext(category, isRightSwipe);
    }
    
  }




  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  Future<void> _preloadColors() async {
    // Only preload if we have articles and haven't preloaded recently
    if (_articles.isEmpty) return;
    
    final startIndex = _currentIndex;
    final endIndex = (_currentIndex + 5).clamp(0, _articles.length); // Reduced from 10 to 5
    
    print('Preloading colors for articles $startIndex to $endIndex');
    
    for (int i = startIndex; i < endIndex; i++) {
      if (i < _articles.length && !_colorCache.containsKey(_articles[i].imageUrl)) {
        try {
          final palette = await ColorExtractionService.extractColorsFromImage(_articles[i].imageUrl);
          _colorCache[_articles[i].imageUrl] = palette;
        } catch (e) {
          _colorCache[_articles[i].imageUrl] = ColorPalette.defaultPalette();
        }
      }
    }
  }

  Future<void> _tryLoadMoreArticles() async {
    // Only try to load more if we're actually at the end
    if (_currentIndex >= _articles.length - 2) {
      print('INFO: Near end of articles, trying to load more...');
      
      if (_selectedCategory == 'All') {
        await _loadNewsArticles();
      } else {
        await _loadArticlesByCategory(_selectedCategory);
      }
    }
  }


  Future<void> _loadAllOtherUnreadArticles() async {
    print('INFO: Loading all other unread articles...');
    
    try {
      // Reset to "All" category and load all unread articles
      setState(() {
        _selectedCategory = 'All';
      });
      
      await _loadNewsArticles();
    } catch (e) {
      print('ERROR: Failed to load other unread articles: $e');
      setState(() {
        _error = 'Failed to load other articles: $e';
        _isLoading = false;
      });
    }
  }

  void _showToast(String message) {
    print('TOAST: $message');
    
    // Show a Cupertino-style alert dialog for better visibility
    if (mounted) {
      showCupertinoDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text('Info'),
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  // If we're showing a "no articles" message and not on "All" category,
                  // automatically switch back to "All"
                  if (_selectedCategory != 'All' && _articles.isEmpty) {
                    _selectCategory('All');
                  }
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      
      // Auto-dismiss after 3 seconds and handle category switch
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
          // If we're showing a "no articles" message and not on "All" category,
          // automatically switch back to "All"
          if (_selectedCategory != 'All' && _articles.isEmpty) {
            _selectCategory('All');
          }
        }
      });
    }
  }

  Widget _buildNoArticlesPage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF1a1a1a),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 70),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.news,
                    size: 80,
                    color: CupertinoColors.systemGrey,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No Articles Available',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error.isNotEmpty ? _error : 'All articles have been read!\nCheck back later for new content.',
                    style: const TextStyle(
                      fontSize: 16,
                      color: CupertinoColors.systemGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndOfArticlesPage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF2a2a2a),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 70),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    size: 80,
                    color: CupertinoColors.systemGreen,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'You\'re All Caught Up!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You\'ve read all available articles.\nCheck back later for fresh content!',
                    style: TextStyle(
                      fontSize: 16,
                      color: CupertinoColors.systemGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoButton(
                        onPressed: () {
                          setState(() {
                            _currentIndex = 0;
                          });
                        },
                        child: const Text(
                          'Back to Top',
                          style: TextStyle(color: Colors.white),
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

  Future<List<NewsArticle>> _filterValidArticles(List<NewsArticle> articles) async {
    final validArticles = <NewsArticle>[];
    final invalidArticles = <NewsArticle>[];
    
    for (final article in articles) {
      if (_hasValidContent(article)) {
        validArticles.add(article);
      } else {
        invalidArticles.add(article);
        // Mark invalid articles as read automatically
        await ReadArticlesService.markAsRead(article.id);
        
        // Smart read tracking: Remove from all category caches
        _removeReadArticleFromCaches(article.id);
        
        print('Auto-marked as read (no content): "${article.title}"');
      }
    }
    
    if (invalidArticles.isNotEmpty) {
      print('Filtered out ${invalidArticles.length} articles with no content');
    }
    
    return validArticles;
  }

  bool _hasValidContent(NewsArticle article) {
    // Check if article has valid image URL
    if (!_hasValidImage(article.imageUrl)) {
      print('Invalid image for article: "${article.title}" - URL: "${article.imageUrl}"');
      return false;
    }
    
    // Check if article has keypoints
    if (article.keypoints != null && article.keypoints!.trim().isNotEmpty) {
      return true;
    }
    
    // Check if article has description/summary
    if (article.description.trim().isNotEmpty) {
      return true;
    }
    
    // No valid content found
    return false;
  }

  bool _hasValidImage(String imageUrl) {
    // Check if image URL is not empty
    if (imageUrl.trim().isEmpty) {
      return false;
    }
    
    // Check if it's a valid URL format
    try {
      final uri = Uri.parse(imageUrl);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        return false;
      }
    } catch (e) {
      return false;
    }
    
    // Check if URL ends with common image extensions
    final lowercaseUrl = imageUrl.toLowerCase();
    final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
    
    // If URL has query parameters, check before the '?'
    final urlWithoutQuery = lowercaseUrl.split('?')[0];
    
    // Allow URLs without extensions (many news sites use dynamic image URLs)
    // But reject obviously invalid ones
    if (lowercaseUrl.contains('placeholder') || 
        lowercaseUrl.contains('default') ||
        lowercaseUrl.contains('no-image') ||
        lowercaseUrl.contains('missing')) {
      return false;
    }
    
    return true;
  }

  Future<void> _showAllSupabaseArticles() async {
    try {
      print('=== FETCHING ALL ARTICLES FROM SUPABASE ===');
      
      // Get all articles (increase limit to see more)
      final allArticles = await SupabaseService.getNews(limit: 200);
      
      print('TOTAL ARTICLES FOUND: ${allArticles.length}');
      print('');
      
      for (int i = 0; i < allArticles.length; i++) {
        final article = allArticles[i];
        
        print('--- ARTICLE ${i + 1} ---');
        print('ID: ${article.id}');
        print('Title: ${article.title}');
        print('Category: ${article.category}');
        print('Published: ${article.timestamp}');
        
        // Check keypoints
        if (article.keypoints != null && article.keypoints!.isNotEmpty) {
          print('Keypoints: ${article.keypoints!.substring(0, article.keypoints!.length > 100 ? 100 : article.keypoints!.length)}...');
        } else {
          print('Keypoints: [NONE]');
        }
        
        // Check description
        if (article.description.isNotEmpty) {
          print('Description: ${article.description.substring(0, article.description.length > 100 ? 100 : article.description.length)}...');
        } else {
          print('Description: [EMPTY]');
        }
        
        // Content validation
        final hasKeypoints = article.keypoints != null && article.keypoints!.trim().isNotEmpty;
        final hasDescription = article.description.trim().isNotEmpty;
        final isValid = hasKeypoints || hasDescription;
        
        print('Content Status: ${isValid ? "VALID" : "INVALID (would be auto-marked as read)"}');
        print('Image URL: ${article.imageUrl}');
        print('');
      }
      
      // Summary
      final validCount = allArticles.where((a) => 
        (a.keypoints != null && a.keypoints!.trim().isNotEmpty) || 
        a.description.trim().isNotEmpty
      ).length;
      
      print('=== SUMMARY ===');
      print('Total Articles: ${allArticles.length}');
      print('Valid Articles: $validCount');
      print('Invalid Articles: ${allArticles.length - validCount}');
      print('=== END ===');
      
    } catch (e) {
      print('ERROR fetching articles: $e');
    }
  }

  Future<void> _showSupabaseCategories() async {
    try {
      print('=== CATEGORIES IN SUPABASE DATABASE ===');
      
      final allArticles = await SupabaseService.getNews(limit: 500);
      final categoryMap = <String, int>{};
      
      // Count articles per category
      for (var article in allArticles) {
        categoryMap[article.category] = (categoryMap[article.category] ?? 0) + 1;
      }
      
      // Sort by count (most articles first)
      final sortedCategories = categoryMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      print('AVAILABLE CATEGORIES (sorted by article count):');
      for (var entry in sortedCategories) {
        print('  "${entry.key}" -> ${entry.value} articles');
      }
      
      print('');
      print('CATEGORY LIST: ${sortedCategories.map((e) => e.key).join(", ")}');
      print('TOTAL CATEGORIES: ${sortedCategories.length}');
      print('=== END CATEGORIES ===');
      
    } catch (e) {
      print('ERROR fetching categories: $e');
    }
  }

  List<String> _getDetectedStatesFromArticles() {
    final states = <String>{};
    
    // Check current articles for state mentions
    for (final article in _articles) {
      final detectedState = _detectStateInContent(article);
      if (detectedState != null) {
        states.add(detectedState);
      }
    }
    
    return states.toList()..sort();
  }

  String? _detectStateInContent(NewsArticle article) {
    final content = '${article.title} ${article.description} ${article.keypoints ?? ''}'.toLowerCase();
    
    // US States (major ones)
    final usStates = {
      'california': 'California',
      'texas': 'Texas', 
      'florida': 'Florida',
      'new york': 'New York',
      'illinois': 'Illinois',
    };
    
    // Indian States (major ones)
    final indianStates = {
      'maharashtra': 'Maharashtra',
      'uttar pradesh': 'Uttar Pradesh',
      'tamil nadu': 'Tamil Nadu',
      'karnataka': 'Karnataka',
      'delhi': 'Delhi'
    };
    
    final allStates = {...usStates, ...indianStates};
    
    // Check for state mentions in content
    for (final entry in allStates.entries) {
      if (content.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return null;
  }

  void _scrollToSelectedCategoryAccurate(int categoryIndex) {
    // Use a more aggressive approach - scroll to ensure visibility
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_categoryScrollController.hasClients) return;
      
      try {
        // Get actual category widths dynamically
        final categories = [
          'All', 'Sports', 'Top', 'Trending', 'Science', 'World', 'Health', 'Business', 
          'Tech', 'Entertainment', 'Travel', 'Startups', 'Politics', 'National', 
          'India', 'Education', 'Celebrity', 'Scandal', 'Viral'
        ];
        
        final double screenWidth = MediaQuery.of(context).size.width;
        final double spacing = 8.0; // Space between items
        final double padding = 20.0; // Left padding
        
        // Calculate cumulative position by measuring each category
        double itemPosition = padding;
        for (int i = 0; i < categoryIndex; i++) {
          final double itemWidth = _estimateCategoryWidth(categories[i]);
          itemPosition += itemWidth + spacing;
        }
        
        // Get current category width
        final double currentItemWidth = _estimateCategoryWidth(categories[categoryIndex]);
        
        final double currentScroll = _categoryScrollController.position.pixels;
        final double maxScroll = _categoryScrollController.position.maxScrollExtent;
        
        // Calculate visible area
        final double visibleStart = currentScroll;
        final double visibleEnd = currentScroll + screenWidth - 40;
        
        double targetScroll = currentScroll;
        
        // If category is going off-screen to the RIGHT, scroll right
        if (itemPosition + currentItemWidth > visibleEnd) {
          targetScroll = itemPosition + currentItemWidth - screenWidth + 60;
        }
        // If category is off-screen to the LEFT, scroll left
        else if (itemPosition < visibleStart + 40) {
          targetScroll = itemPosition - 60;
        }
        
        // Ensure we stay within bounds
        targetScroll = targetScroll.clamp(0.0, maxScroll);
        
        print('Category "$categories[categoryIndex]" ($categoryIndex): pos=$itemPosition, width=$currentItemWidth, visible=$visibleStart-$visibleEnd, scroll=$currentScroll->$targetScroll');
        
        // Only animate if we need to scroll significantly
        if ((targetScroll - currentScroll).abs() > 10) {
          _categoryScrollController.animateTo(
            targetScroll,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      } catch (e) {
        print('Scroll error: $e');
      }
    });
  }

  double _estimateCategoryWidth(String categoryName) {
    // Estimate width based on text length and padding
    const double charWidth = 8.0; // Average character width
    const double horizontalPadding = 24.0; // 12px on each side
    
    // Calculate based on actual text length
    final double textWidth = categoryName.length * charWidth;
    return textWidth + horizontalPadding;
  }

  void _scrollToSelectedCategory(int categoryIndex) {
    // Add delay to ensure the scroll controller is ready
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!_categoryScrollController.hasClients) {
        print('ScrollController not ready yet');
        return;
      }
      
      try {
        // Get current scroll position and viewport info
        final double currentPosition = _categoryScrollController.position.pixels;
        final double viewportWidth = _categoryScrollController.position.viewportDimension;
        final double maxScroll = _categoryScrollController.position.maxScrollExtent;
        
        // Calculate item position more accurately
        const double itemWidth = 90.0; // Wider estimate for category pills
        const double itemSpacing = 8.0; // Space between pills
        const double leftPadding = 20.0; // Initial padding
        
        // Calculate where the selected category starts
        final double itemStartPosition = leftPadding + (categoryIndex * (itemWidth + itemSpacing));
        final double itemEndPosition = itemStartPosition + itemWidth;
        
        // Check if item is already visible
        final double visibleStart = currentPosition;
        final double visibleEnd = currentPosition + viewportWidth;
        
        double targetScroll = currentPosition;
        
        // If item is off-screen to the right, scroll to show it
        if (itemEndPosition > visibleEnd) {
          targetScroll = itemEndPosition - viewportWidth + 40; // 40px margin
        }
        // If item is off-screen to the left, scroll to show it  
        else if (itemStartPosition < visibleStart) {
          targetScroll = itemStartPosition - 40; // 40px margin
        }
        
        // Ensure we don't scroll beyond bounds
        targetScroll = targetScroll.clamp(0.0, maxScroll);
        
        print('Category $categoryIndex: start=$itemStartPosition, end=$itemEndPosition, visible=$visibleStart-$visibleEnd, scrollTo=$targetScroll');
        
        // Only scroll if we need to
        if ((targetScroll - currentPosition).abs() > 5) {
          _categoryScrollController.animateTo(
            targetScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      } catch (e) {
        print('Error scrolling to category: $e');
      }
    });
  }


  void _preloadPopularCategories() {
    // Pre-load the most commonly accessed categories
    final popularCategories = ['Sports', 'Top', 'Trending', 'Science', 'Tech'];
    
    Future.delayed(const Duration(milliseconds: 1000), () async {
      for (String category in popularCategories) {
        if (_categoryArticles[category]?.isEmpty != false) {
          print('Pre-loading popular category: $category');
          await _loadArticlesByCategoryForCache(category);
          await Future.delayed(const Duration(milliseconds: 300)); // Small delay between loads
        }
      }
      print('Popular categories pre-loaded successfully');
    });
  }

  void _removeReadArticleFromCaches(String articleId) {
    for (String category in _categoryArticles.keys) {
      final categoryList = _categoryArticles[category];
      if (categoryList != null) {
        categoryList.removeWhere((article) => article.id == articleId);
      }
    }
  }
}
