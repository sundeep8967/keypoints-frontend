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
  
  // Animation controllers for swipe
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadNewsArticles();
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
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          print('DEBUG: Horizontal swipe detected');
          _handleHorizontalSwipe(details);
        },
        child: Stack(
          children: [
            _buildBody(),
            _buildCleanHeader(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
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

    if (_error.isNotEmpty || _articles.isEmpty) {
      return _buildNoArticlesPage();
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      physics: const PageScrollPhysics(),
      itemCount: _articles.length + 1, // +1 for "end of articles" page
      pageSnapping: true,
      onPageChanged: (index) async {
        print('PAGE CHANGED: Moving to article $index');
        
        // Mark previous article as read when moving to next article
        if (index > 0 && index <= _articles.length && _articles.isNotEmpty) {
          final previousArticle = _articles[index - 1];
          await ReadArticlesService.markAsRead(previousArticle.id);
          print('Marked article "${previousArticle.title}" as read');
        }
        
        setState(() {
          _currentIndex = index;
        });
        
        if (index < _articles.length && index % 3 == 0) {
          _preloadColors();
        }
      },
      itemBuilder: (context, index) {
        // Show "end of articles" page after last article
        if (index >= _articles.length) {
          return _buildEndOfArticlesPage();
        }
        
        final article = _articles[index];
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
                      article.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: palette.onPrimary.withOpacity(0.9),
                        height: 1.5,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 6,
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
    setState(() {
      _selectedCategory = category;
      _currentIndex = 0;
    });
    
    if (category == 'All') {
      _loadNewsArticles();
    } else {
      _loadArticlesByCategory(category);
    }
    
    print('Switched to $category');
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
    
    print('Switched to $category via ${isRightSwipe ? 'right' : 'left'} swipe');
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    
    // Only handle swipes if they're fast enough (minimum velocity)
    if (velocity.abs() < 500) return;
    
    final categories = [
      'All',
      'Technology',
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
    
    final currentIndex = categories.indexOf(_selectedCategory);
    if (currentIndex == -1) return;
    
    int newIndex;
    bool isRightSwipe = velocity > 0;
    
    if (isRightSwipe) {
      // Right swipe - go to next category  
      newIndex = currentIndex < categories.length - 1 ? currentIndex + 1 : 0;
    } else {
      // Left swipe - go to previous category
      newIndex = currentIndex > 0 ? currentIndex - 1 : categories.length - 1;
    }
    
    final newCategory = categories[newIndex];
    _selectCategoryWithSwipeContext(newCategory, isRightSwipe);
    
    // Show a brief toast to indicate category change (only for left swipes)
    if (!isRightSwipe) {
      _showCategoryChangeToast(newCategory);
    }
  }

  void _showCategoryChangeToast(String category) {
    // Create a simple overlay toast
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 80,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.arrow_left_right,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Switched to $category',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    
    // Remove the toast after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      overlayEntry.remove();
    });
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