import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/news_article.dart';
import '../widgets/dynamic_color_news_card.dart';
import '../services/firebase_service.dart';
import '../services/color_extraction_service.dart';

class ColorDemoScreen extends StatefulWidget {
  const ColorDemoScreen({super.key});

  @override
  State<ColorDemoScreen> createState() => _ColorDemoScreenState();
}

class _ColorDemoScreenState extends State<ColorDemoScreen> with TickerProviderStateMixin {
  List<NewsArticle> _articles = [];
  bool _isLoading = true;
  String _error = '';
  int _currentIndex = 0;
  
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
    _loadDemoArticles();
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

  Future<void> _loadDemoArticles() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // Try to load from Firebase first
      try {
        final articles = await FirebaseService.getNews();
        if (articles.isNotEmpty) {
          setState(() {
            _articles = articles.take(5).toList(); // Show first 5 for demo
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        print('Firebase not available, using demo data: $e');
      }

      // Fallback to demo data
      _articles = _getDemoArticles();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load articles: $e';
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
        id: 'demo3',
        title: 'Space Exploration Reaches New Milestone',
        description: 'NASA announces successful deployment of next-generation telescope, promising unprecedented views of distant galaxies.',
        imageUrl: 'https://images.unsplash.com/photo-1446776877081-d282a0f896e2?w=800&h=600&fit=crop',
        timestamp: DateTime.now().subtract(const Duration(hours: 8)),
        category: 'Science',
      ),
      NewsArticle(
        id: 'demo4',
        title: 'Sustainable Energy Revolution Continues',
        description: 'New solar panel technology achieves record efficiency, making renewable energy more accessible than ever.',
        imageUrl: 'https://images.unsplash.com/photo-1509391366360-2e959784a276?w=800&h=600&fit=crop',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        category: 'Energy',
      ),
      NewsArticle(
        id: 'demo5',
        title: 'Urban Gardening Movement Grows Worldwide',
        description: 'Cities around the globe embrace vertical farming and rooftop gardens to improve food security and air quality.',
        imageUrl: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800&h=600&fit=crop',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        category: 'Lifestyle',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: _buildBody(),
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
              onPressed: _loadDemoArticles,
            ),
          ],
        ),
      );
    }

    return _buildVerticalSwipeView();
  }

  Widget _buildSwipableStack() {
    if (_articles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.news,
              size: 60,
              color: CupertinoColors.systemGrey,
            ),
            SizedBox(height: 16),
            Text(
              'No more articles',
              style: TextStyle(
                fontSize: 18,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Pull to refresh for more stories',
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.tertiaryLabel,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Show up to 3 cards in stack
        for (int i = _currentIndex; i < _currentIndex + 3 && i < _articles.length; i++)
          _buildStackCard(_articles[i], i - _currentIndex),
      ],
    );
  }

  Widget _buildStackCard(NewsArticle article, int stackIndex) {
    final scale = 1.0 - (stackIndex * 0.05);
    final yOffset = stackIndex * 10.0;
    
    return Positioned.fill(
      child: Transform.scale(
        scale: scale,
        child: Transform.translate(
          offset: Offset(0, yOffset),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: stackIndex == 0 
                ? _buildSwipableCard(article)
                : _buildStaticCard(article),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipableCard(NewsArticle article) {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _isDragging = true;
        });
      },
      onPanUpdate: (details) {
        setState(() {
          _dragOffset += details.delta;
        });
      },
      onPanEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond.dx;
        final threshold = MediaQuery.of(context).size.width * 0.3;
        
        if (_dragOffset.dx.abs() > threshold || velocity.abs() > 500) {
          // Swipe detected
          final isRightSwipe = _dragOffset.dx > 0 || velocity > 0;
          _animateSwipe(isRightSwipe);
        } else {
          // Return to center
          _resetCard();
        }
      },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final offset = _isDragging 
              ? _dragOffset 
              : _slideAnimation.value * MediaQuery.of(context).size.width;
          
          final rotation = _isDragging
              ? _dragOffset.dx * 0.0005
              : _rotationAnimation.value * (_slideAnimation.value.dx > 0 ? 1 : -1);
          
          return Transform.translate(
            offset: offset,
            child: Transform.rotate(
              angle: rotation,
              child: DynamicColorNewsCard(
                article: article,
                onTap: () {
                  // Navigate to article detail
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStaticCard(NewsArticle article) {
    return DynamicColorNewsCard(
      article: article,
      onTap: null, // Disable tap for background cards
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return CupertinoButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: color,
          size: 28,
        ),
      ),
    );
  }

  void _animateSwipe(bool isRightSwipe) {
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(isRightSwipe ? 2.0 : -2.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward().then((_) {
      _nextCard();
      _resetCard();
      final message = isRightSwipe ? 'Liked!' : 'Passed';
      _showFeedback(message, isRightSwipe);
    });
  }
  
  void _resetCard() {
    setState(() {
      _dragOffset = Offset.zero;
      _isDragging = false;
    });
    _animationController.reset();
  }
  
  void _nextCard() {
    setState(() {
      _currentIndex++;
      if (_currentIndex >= _articles.length) {
        _currentIndex = 0; // Loop back to start
      }
    });
  }
  
  void _swipeCard(bool liked) {
    if (_currentIndex < _articles.length && !_isDragging) {
      _animateSwipe(liked);
    }
  }

  void _bookmarkCard() {
    if (_currentIndex < _articles.length) {
      _showFeedback('Bookmarked!', true);
      // Add bookmark logic here
    }
  }

  void _showFeedback(String message, bool positive) {
    final color = positive ? CupertinoColors.systemGreen : CupertinoColors.systemRed;
    
    // You can implement a toast or snackbar here
    print(message); // For now, just print
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

  Widget _buildVerticalSwipeView() {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      physics: const BouncingScrollPhysics(),
      itemCount: _articles.length,
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      itemBuilder: (context, index) {
        final article = _articles[index];
        return _buildFullScreenCard(article, index);
      },
    );
  }

  Widget _buildFullScreenCard(NewsArticle article, int index) {
    return FutureBuilder<ColorPalette>(
      future: ColorExtractionService.extractColorsFromImage(article.imageUrl),
      builder: (context, snapshot) {
        final palette = snapshot.data ?? ColorPalette.defaultPalette();
        
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: palette.primary,
          ),
          child: Stack(
            children: [
              // Background image with overlay
              Positioned.fill(
                child: Stack(
                  children: [
                    // Image
                    Image.network(
                      article.imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: palette.primary,
                          child: Center(
                            child: Icon(
                              CupertinoIcons.photo_fill,
                              size: 80,
                              color: palette.onPrimary.withOpacity(0.3),
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: palette.primary,
                          child: Center(
                            child: CupertinoActivityIndicator(
                              color: palette.onPrimary,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            palette.primary.withOpacity(0.3),
                            palette.primary.withOpacity(0.8),
                            palette.primary,
                          ],
                          stops: const [0.0, 0.3, 0.6, 0.8, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Top UI elements
              Positioned(
                top: MediaQuery.of(context).padding.top + 20,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        article.category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: palette.primary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    
                    // Page indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        '${index + 1} / ${_articles.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bottom content
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 40,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Description
                    Text(
                      article.description,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.5,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Bottom actions
                    Row(
                      children: [
                        // Timestamp
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _formatTimestamp(article.timestamp),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Action buttons
                        _buildVerticalActionButton(
                          CupertinoIcons.heart_fill,
                          Colors.red,
                          () {
                            // Like action
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildVerticalActionButton(
                          CupertinoIcons.bookmark_fill,
                          Colors.blue,
                          () {
                            // Bookmark action
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildVerticalActionButton(
                          CupertinoIcons.share_up,
                          Colors.green,
                          () {
                            // Share action
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Swipe indicator
                    if (index < _articles.length - 1)
                      Center(
                        child: Column(
                          children: [
                            const Icon(
                              CupertinoIcons.chevron_up,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Swipe up for next story',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerticalActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 24,
          color: Colors.white,
        ),
      ),
    );
  }

}