import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/news_article.dart';
import '../services/firebase_service.dart';
import '../widgets/news_card.dart';
import 'news_detail_screen.dart';
import 'admin_screen.dart';
import 'color_demo_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<NewsArticle> _articles = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final articles = await FirebaseService.getNews();
      
      if (mounted) {
        setState(() {
          _articles = articles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load news. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshNews() async {
    await _loadNews();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.transparent,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.transparent,
        border: null,
        middle: const Text(
          'KeyPoints',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => const ColorDemoScreen(),
                  ),
                );
              },
              child: const Icon(
                CupertinoIcons.color_filter,
                color: CupertinoColors.systemPurple,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => const AdminScreen(),
                  ),
                );
              },
              child: const Icon(
                CupertinoIcons.settings,
                color: CupertinoColors.systemBlue,
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 20),
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
              onPressed: _refreshNews,
            ),
          ],
        ),
      );
    }

    if (_articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.news,
              size: 60,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No news available',
              style: TextStyle(
                fontSize: 18,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pull down to refresh',
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.tertiaryLabel,
              ),
            ),
            const SizedBox(height: 20),
            CupertinoButton.filled(
              child: const Text('Refresh'),
              onPressed: _refreshNews,
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: _articles.length,
      itemBuilder: (context, index) {
        final article = _articles[index];
        return _buildFullPageArticle(article, index);
      },
    );
  }

  void _navigateToDetail(NewsArticle article) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => NewsDetailScreen(article: article),
      ),
    );
  }

  Widget _buildFullPageArticle(NewsArticle article, int index) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: article.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: CupertinoColors.systemGrey5,
                child: const Center(
                  child: CupertinoActivityIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: CupertinoColors.systemGrey5,
                child: const Center(
                  child: Icon(
                    CupertinoIcons.photo,
                    size: 60,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ),
            ),
          ),
          
          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    CupertinoColors.black.withOpacity(0.3),
                    CupertinoColors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),
          
          // Content
          Positioned(
            left: 20,
            right: 20,
            bottom: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  article.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.white,
                    height: 1.2,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Description
                Text(
                  article.description,
                  style: const TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.white,
                    height: 1.4,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 20),
                
                // Timestamp and Actions
                Row(
                  children: [
                    Text(
                      _formatTimestamp(article.timestamp),
                      style: const TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      onPressed: () => _navigateToDetail(article),
                      child: const Icon(
                        CupertinoIcons.arrow_right_circle,
                        color: CupertinoColors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Page Indicator
          Positioned(
            right: 20,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_articles.length, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    width: 4,
                    height: i == index ? 20 : 8,
                    decoration: BoxDecoration(
                      color: i == index 
                          ? CupertinoColors.white 
                          : CupertinoColors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }).take(10).toList(), // Show max 10 indicators
              ),
            ),
          ),
          
          // Swipe Hint (only on first article)
          if (index == 0)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  const Icon(
                    CupertinoIcons.chevron_up,
                    color: CupertinoColors.white,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Swipe up for next story',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(timestamp);
    }
  }
}