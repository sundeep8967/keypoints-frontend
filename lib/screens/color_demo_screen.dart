import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/news_article.dart';
import '../widgets/dynamic_color_news_card.dart';
import '../services/firebase_service.dart';

class ColorDemoScreen extends StatefulWidget {
  const ColorDemoScreen({super.key});

  @override
  State<ColorDemoScreen> createState() => _ColorDemoScreenState();
}

class _ColorDemoScreenState extends State<ColorDemoScreen> {
  List<NewsArticle> _articles = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadDemoArticles();
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
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground,
        middle: const Text(
          'KeyPoints',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
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

    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: _loadDemoArticles,
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final article = _articles[index];
              return DynamicColorNewsCard(
                article: article,
                onTap: () {
                  // Navigate to article detail
                },
              );
            },
            childCount: _articles.length,
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 20),
        ),
      ],
    );
  }

}