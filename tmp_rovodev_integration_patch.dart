// Integration patch for news_feed_screen.dart
// Replace the existing _loadNewsArticles or _loadDemoArticles method with this:

Future<void> _loadNewsArticles() async {
  try {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    print('Starting news loading with read articles filtering...');

    // Step 1: Load cached UNREAD articles immediately for instant display
    final cachedUnreadArticles = await LocalStorageService.loadUnreadArticles();
    if (cachedUnreadArticles.isNotEmpty) {
      setState(() {
        _articles = cachedUnreadArticles.take(20).toList(); // Show first 20 unread
        _isLoading = false;
      });
      print('Displaying ${_articles.length} cached unread articles');
    }

    // Step 2: Check if we should fetch new articles
    final shouldFetch = await LocalStorageService.shouldFetchNewArticles();
    
    if (shouldFetch) {
      print('Fetching new articles from Supabase...');
      
      try {
        // Fetch 100 new articles from Supabase
        final newArticles = await SupabaseService.getNews(limit: 100);
        print('Fetched ${newArticles.length} new articles from Supabase');
        
        if (newArticles.isNotEmpty) {
          // Add new articles to cache (this will filter duplicates)
          await LocalStorageService.addNewArticles(newArticles);
          
          // Reload UNREAD articles from cache (now includes new unread ones)
          final allUnreadArticles = await LocalStorageService.loadUnreadArticles();
          
          setState(() {
            _articles = allUnreadArticles.take(20).toList();
            _isLoading = false;
          });
          
          print('Updated display with ${_articles.length} unread articles');
          
          // Show cache stats for debugging
          final stats = await LocalStorageService.getCacheStats();
          print('Cache stats: $stats');
          
          // Periodic cleanup (once per week automatically)
          await LocalStorageService.cleanupStorage();
        }
      } catch (e) {
        print('Error fetching from Supabase: $e');
        // If fetch fails but we have cached unread articles, continue
        if (cachedUnreadArticles.isEmpty) {
          setState(() {
            _error = 'Failed to load articles: $e';
            _isLoading = false;
          });
        }
      }
    } else {
      print('Using cached unread articles (last fetch was recent)');
    }

    // If no unread articles available
    if (_articles.isEmpty && !_isLoading) {
      setState(() {
        _error = 'No unread articles available. All articles have been read!';
        _isLoading = false;
      });
    }

  } catch (e) {
    print('Error in _loadNewsArticles: $e');
    setState(() {
      _error = 'Failed to load articles: $e';
      _isLoading = false;
    });
  }
}

// Also add this method to mark articles as read when user views them:
void _markArticleAsRead(NewsArticle article) async {
  await ReadArticlesService.markAsRead(article.id);
  print('Marked article ${article.id} as read');
  
  // Remove from current display
  setState(() {
    _articles.removeWhere((a) => a.id == article.id);
  });
  
  // If we're running low on articles, try to load more
  if (_articles.length < 5) {
    final moreUnreadArticles = await LocalStorageService.loadUnreadArticles();
    setState(() {
      _articles = moreUnreadArticles.take(20).toList();
    });
  }
}