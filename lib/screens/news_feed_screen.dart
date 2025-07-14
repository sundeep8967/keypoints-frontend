import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/news_article.dart';
import '../widgets/dynamic_color_news_card.dart';
import '../services/firebase_service.dart';
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
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotationAnimation;
  
  // Drag state
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

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
    
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(2.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
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

      // PRIORITY 2: Fallback to demo data only if Supabase fails
      final demoArticles = _getDemoArticles();
      final readIds = await ReadArticlesService.getReadArticleIds();
      final unreadDemoArticles = demoArticles.where((article) => 
        !readIds.contains(article.id)
      ).toList();
      
      setState(() {
        _articles = unreadDemoArticles;
        _isLoading = false;
      });
      
      if (unreadDemoArticles.isEmpty) {
        setState(() {
          _error = 'All demo articles have been read! Please check your internet connection to load new articles.';
        });
      }
      
      print('FALLBACK: Using ${unreadDemoArticles.length} unread demo articles out of ${demoArticles.length} total');
    } catch (e) {
      setState(() {
        _error = 'Failed to load articles: $e';
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
            // Show toast and load all other unread articles instead of showing error
            _showToast('No $category articles found. Showing other news instead.');
            await _loadAllOtherUnreadArticles();
            return;
          }
        }
      } catch (e) {
        print('ERROR: Failed to filter Supabase articles: $e');
      }

      // PRIORITY 3: If Supabase completely fails, show toast and try to load other articles
      _showToast('Unable to load $category articles. Showing other available news.');
      await _loadAllOtherUnreadArticles();
      if (_articles.isEmpty) {
        setState(() {
          _articles = [];
          _error = 'Unable to load any articles. Please check your internet connection and try again.';
          _isLoading = false;
        });
        print('ERROR: Supabase completely unavailable for $category');
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load articles for $category: $e';
        _isLoading = false;
      });
    }
  }

  List<NewsArticle> _getDemoArticles() {
    return [
      NewsArticle(
        id: 'demo1',
        title: 'Breaking: Revolutionary AI Technology Unveiled',
        description: 'Scientists have developed a groundbreaking AI system that can extract colors from images in real-time, revolutionizing mobile app design.',
        imageUrl: 'https://images.unsplash.com/photo-1677442136019-21780ecad995?w=800&h=600&fit=crop',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        category: 'Technology',
      ),
      NewsArticle(
        id: 'demo2',
        title: 'Ocean Conservation Efforts Show Promising Results',
        description: 'Marine biologists report significant improvements in coral reef health following new conservation initiatives.',
        imageUrl: 'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=800&h=600&fit=crop',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        category: 'Environment',
      ),
      NewsArticle(
        id: 'demo6',
        title: 'Hollywood Blockbuster Breaks Box Office Records',
        description: 'The latest superhero movie has shattered opening weekend records, earning over \$200 million globally in its first three days.',
        imageUrl: 'https://images.unsplash.com/photo-1489599735734-79b4169c2a78?w=800&h=600&fit=crop',
        timestamp: DateTime.now().subtract(const Duration(hours: 12)),
        category: 'Entertainment',
      ),
      NewsArticle(
        id: 'demo8',
        title: 'Tech Giant Reports Record Quarterly Earnings',
        description: 'Major technology company exceeds analyst expectations with strong performance across all business segments.',
        imageUrl: 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=800&h=600&fit=crop',
        timestamp: DateTime.now().subtract(const Duration(hours: 6)),
        category: 'Business',
      ),
      NewsArticle(
        id: 'demo10',
        title: 'Breakthrough in Cancer Treatment Research',
        description: 'Scientists develop new immunotherapy approach showing promising results in clinical trials for multiple cancer types.',
        imageUrl: 'https://images.unsplash.com/photo-1559757148-5c350d0d3c56?w=800&h=600&fit=crop',
        timestamp: DateTime.now().subtract(const Duration(hours: 10)),
        category: 'Health',
      ),
      NewsArticle(
        id: 'demo12',
        title: 'Championship Final Set for This Weekend',
        description: 'Two powerhouse teams prepare for the ultimate showdown in what promises to be the game of the century.',
        imageUrl: 'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=800&h=600&fit=crop',
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        category: 'Sports',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Stack(
        children: [
          _buildBody(),
          _buildCleanHeader(),
        ],
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

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 60,
              color: CupertinoColors.systemRed,
            ),
            const SizedBox(height: 16),
            Text(
              _error,
              style: const TextStyle(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CupertinoButton.filled(
              child: const Text('Retry'),
              onPressed: _loadNewsArticles,
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      physics: const ClampingScrollPhysics(),
      itemCount: _articles.length,
      controller: PageController(
        viewportFraction: 1.0,
        keepPage: true,
      ),
      pageSnapping: true,
      onPageChanged: (index) async {
        // Mark previous article as read when moving to next article
        if (index > 0 && _articles.isNotEmpty) {
          final previousArticle = _articles[index - 1];
          await ReadArticlesService.markAsRead(previousArticle.id);
          print('Marked article "${previousArticle.title}" as read');
        }
        
        setState(() {
          _currentIndex = index;
        });
        
        if (index % 3 == 0) {
          _preloadColors();
        }
        
        // If we're near the end and running out of articles, try to load more
        if (index >= _articles.length - 2) {
          _tryLoadMoreArticles();
        }
      },
      itemBuilder: (context, index) {
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
          SizedBox(height: MediaQuery.of(context).padding.top + 50),
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
                  Text(
                    article.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: palette.onPrimary.withOpacity(0.9),
                      height: 1.5,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
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
                                CupertinoIcons.heart_fill,
                                palette.onPrimary,
                                () {},
                              ),
                              const SizedBox(width: 12),
                              _buildActionButton(
                                CupertinoIcons.bookmark_fill,
                                palette.onPrimary,
                                () {},
                              ),
                              const SizedBox(width: 12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Text(
                  'KeyPoints',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // My Feed button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 0,
                      onPressed: _showMyFeed,
                      child: const Text(
                        'My Feed',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Refresh button
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _refreshArticles,
                      child: const Icon(
                        CupertinoIcons.refresh,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Category menu button
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _showCategoryMenu,
                      child: const Icon(
                        CupertinoIcons.ellipsis,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMyFeed() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: const Text(
            'My Feed',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          message: const Text('Manage your personalized news feed'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                print('Show bookmarked articles');
              },
              child: const Text('Bookmarked Articles'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                print('Show liked articles');
              },
              child: const Text('Liked Articles'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                print('Show reading history');
              },
              child: const Text('Reading History'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                print('Show feed preferences');
              },
              child: const Text('Feed Preferences'),
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

  void _showCategoryMenu() {
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

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: const Text(
            'Select News Category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          message: Text('Currently showing: $_selectedCategory'),
          actions: categories.map((category) {
            final isSelected = category == _selectedCategory;
            return CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _selectCategory(category);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSelected)
                    const Icon(
                      CupertinoIcons.checkmark,
                      size: 18,
                      color: CupertinoColors.systemBlue,
                    ),
                  if (isSelected) const SizedBox(width: 8),
                  Text(
                    category,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? CupertinoColors.systemBlue : null,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
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

  Future<void> _refreshArticles() async {
    print('INFO: Refreshing articles...');
    
    // Clean up old read IDs periodically
    await ReadArticlesService.cleanupOldReadIds();
    
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
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      
      // Auto-dismiss after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      });
    }
  }
}