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

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeCategories();
    _loadNewsArticles();
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
          
          setState(() {
            _articles = unreadArticles;
            _isLoading = false;
          });
          
          print('SUCCESS: Loaded ${allArticles.length} total articles, ${unreadArticles.length} unread from Supabase');
          print('INFO: ${readIds.length} articles already read');
          
          if (unreadArticles.isEmpty) {
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
          
          // Pre-load this category if not already loaded
          _preloadCategoryIfNeeded(newCategory);
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
    
    // If this is the current category, use the main articles list
    final articlesToShow = category == _selectedCategory ? _articles : categoryArticles;
    
    if (isLoading && articlesToShow.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(radius: 20),
            SizedBox(height: 16),
            Text(
              'Loading articles...',
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel,
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
          print('Marked article "${previousArticle.title}" as read');
        }
        
        if (category == _selectedCategory) {
          setState(() {
            _currentIndex = index;
          });
        }
        
        if (index < articlesToShow.length && index % 3 == 0) {
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
                    child: SingleChildScrollView(
                      child: Text(
                        article.description,
                        style: TextStyle(
                          fontSize: 16,
                          color: palette.onPrimary.withOpacity(0.9),
                          height: 1.5,
                          letterSpacing: 0.1,
                        ),
                      ),
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
                              const SizedBox(width: 8),
                              // Category swipe indicator
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: palette.onPrimary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: palette.onPrimary.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.arrow_left,
                                      size: 12,
                                      color: palette.onPrimary.withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Categories',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: palette.onPrimary.withOpacity(0.7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(
                                      CupertinoIcons.arrow_right,
                                      size: 12,
                                      color: palette.onPrimary.withOpacity(0.7),
                                    ),
                                  ],
                                ),
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

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == _selectedCategory;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: () => _selectCategory(category),
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
      
      final allCategoryArticles = await SupabaseService.getNewsByCategory(category, limit: 100);
      if (allCategoryArticles.isNotEmpty) {
        final unreadCategoryArticles = allCategoryArticles.where((article) => 
          !readIds.contains(article.id)
        ).toList();
        
        _categoryArticles[category] = unreadCategoryArticles;
        _categoryLoading[category] = false;
        
        if (category == _selectedCategory) {
          setState(() {
            _articles = unreadCategoryArticles;
            _isLoading = false;
          });
        }
        
        print('Pre-loaded $category: ${unreadCategoryArticles.length} articles');
      } else {
        _categoryArticles[category] = [];
        _categoryLoading[category] = false;
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
    final startIndex = _currentIndex;
    final endIndex = (_currentIndex + 10).clamp(0, _articles.length);
    
    for (int i = startIndex; i < endIndex; i++) {
      if (!_colorCache.containsKey(_articles[i].imageUrl)) {
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
    print('INFO: Running low on articles, trying to load more...');
    
    if (_selectedCategory == 'All') {
      await _loadNewsArticles();
    } else {
      await _loadArticlesByCategory(_selectedCategory);
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
}