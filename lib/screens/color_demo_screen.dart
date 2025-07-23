import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/news_article.dart';
import '../widgets/dynamic_color_news_card.dart';
import '../services/news_loading_service.dart';
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

      // Load real articles from news service
      final articles = await NewsLoadingService.loadNewsArticles();
      
      if (articles.isNotEmpty) {
        setState(() {
          _articles = articles.take(5).toList(); // Show first 5 for color demo
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'No articles available. Please check your internet connection.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load articles. Please check your internet connection and try again.';
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
          _buildBody(),
          // Simple clean header - positioned last to be on top
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
              onPressed: _loadDemoArticles,
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
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
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
  

  void _showFeedback(String message, bool positive) {
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

  Widget _buildFullScreenCard(NewsArticle article, int index) {
    return FutureBuilder<ColorPalette>(
      future: ColorExtractionService.extractColorsFromImage(article.imageUrl),
      builder: (context, snapshot) {
        final palette = snapshot.data ?? ColorPalette.defaultPalette();
        
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: palette.primary,
          child: Column(
            children: [
              // Space for the floating header
              SizedBox(height: MediaQuery.of(context).padding.top + 50),
              // Top image section (like Inshorts) - starts right after header
              Container(
                height: MediaQuery.of(context).size.height * 0.3,
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Stack(
                  children: [
                    // Image with rounded corners
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          article.imageUrl,
                          fit: BoxFit.cover,
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
                                  color: palette.onPrimary.withValues(alpha: 0.5),
                                ),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              decoration: BoxDecoration(
                                color: palette.secondary,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: CupertinoActivityIndicator(
                                  color: palette.onPrimary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    
                    // Category badge and page indicator on image
                    Positioned(
                      top: 15,
                      left: 15,
                      right: 15,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Category badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
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
                          
                          // Page indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${index + 1} / ${_articles.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bottom content section (like Inshorts)
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
                      // Title
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
                      
                      // Description - fills ALL available space
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            article.description,
                            style: TextStyle(
                              fontSize: 16,
                              color: palette.onPrimary.withValues(alpha: 0.9),
                              height: 1.5,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Add spacer to push bottom content down
                      const Spacer(),
                      
                      // Bottom section with all elements in same area
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Timestamp and action buttons in same row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Timestamp on left
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: palette.onPrimary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: palette.onPrimary.withValues(alpha: 0.2),
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
                              
                              // Action buttons on right
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildInshortsActionButton(
                                    CupertinoIcons.share_up,
                                    palette.onPrimary,
                                    () {
                                      // Share action
                                    },
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
      },
    );
  }


  Widget _buildInshortsActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
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
      top: MediaQuery.of(context).padding.top, // Start below notification bar
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
              // KeyPoints text - smaller size
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
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
              
              // Smaller menu button
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    // Menu action
                  },
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

}