import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/news_article.dart';
import '../widgets/dynamic_color_news_card.dart';
import '../services/firebase_service.dart';
import '../services/supabase_service.dart';
import '../services/news_integration_service.dart';
import '../services/color_extraction_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadNewsArticles();
  }

  Future<void> _loadNewsArticles() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      print('Loading unread articles from Supabase...');
      
      // Load unread articles using integration service
      final unreadArticles = await NewsIntegrationService.loadUnreadNews(displayLimit: 20);
      
      if (unreadArticles.isNotEmpty) {
        setState(() {
          _articles = unreadArticles;
          _isLoading = false;
        });
        
        print('Loaded ${unreadArticles.length} unread articles');
        return;
      } else {
        setState(() {
          _error = 'No unread articles available. All articles have been read!';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading articles: $e');
      setState(() {
        _error = 'Failed to load articles: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'KeyPoints',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CupertinoActivityIndicator(
                        color: CupertinoColors.white,
                      ),
                    )
                  : _error.isNotEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  CupertinoIcons.exclamationmark_triangle,
                                  color: CupertinoColors.systemRed,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _error,
                                  style: const TextStyle(
                                    color: CupertinoColors.white,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        )
                      : _articles.isEmpty
                          ? const Center(
                              child: Text(
                                'No articles available',
                                style: TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : PageView.builder(
                              scrollDirection: Axis.vertical,
                              itemCount: _articles.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentIndex = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                final article = _articles[index];
                                return Container(
                                  margin: const EdgeInsets.all(16),
                                  child: DynamicColorNewsCard(
                                    article: article,
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}