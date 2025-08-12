import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../models/news_article.dart';
import '../services/color_extraction_service.dart';
import '../services/parallel_color_service.dart';
import '../services/predictive_preloader_service.dart';
import '../services/read_articles_service.dart';
import '../services/category_preference_service.dart';
import '../services/image_preloader_service.dart';
import '../services/optimized_image_service.dart';
import '../services/scroll_state_service.dart';
import '../services/ad_integration_service.dart';
import '../models/native_ad_model.dart';
import '../widgets/news_feed_widgets.dart';

// Helper function to preload colors for upcoming articles
Future<void> _preloadColorsForUpcomingArticles(
  List<NewsArticle> articles, 
  int currentIndex, 
  Map<String, ColorPalette> colorCache
) async {
  final startIndex = currentIndex + 1;
  final endIndex = (currentIndex + 4).clamp(0, articles.length);
  
  print('🎨 PRELOADING COLORS: Articles $startIndex to $endIndex');
  
  for (int i = startIndex; i < endIndex; i++) {
    if (i < articles.length && !colorCache.containsKey(articles[i].imageUrl)) {
      try {
        final palette = await ParallelColorService.extractColorsParallel(articles[i].imageUrl);
        colorCache[articles[i].imageUrl] = palette;
        final titlePreview = articles[i].title.length > 50 ? articles[i].title.substring(0, 50) : articles[i].title;
        print('✅ PRELOADED COLOR: Article $i - $titlePreview...');
      } catch (e) {
        colorCache[articles[i].imageUrl] = ColorPalette.defaultPalette();
        print('❌ COLOR FAILED: Article $i - Using default palette');
      }
    }
  }
}

class NewsFeedPageBuilder {
  static Widget buildCategoryContent(
    BuildContext context,
    String category,
    Map<String, List<NewsArticle>> categoryArticles,
    Map<String, bool> categoryLoading,
    String selectedCategory,
    int currentIndex,
    String error,
    Function(int) onCurrentIndexChanged,
    Map<String, ColorPalette> colorCache,
    Function(String)? loadMoreArticles, // Add callback for loading more articles
    PageController? pageController, // Add PageController parameter for bidirectional scrolling
    Map<String, PageController> articlePageControllers, // Add PageControllers map for direction checking
  ) {
    final categoryArticlesList = categoryArticles[category] ?? [];
    final isLoading = categoryLoading[category] ?? false;
    
    // Create mixed feed with ads integrated
    return FutureBuilder<List<dynamic>>(
      future: _createMixedFeedWithAds(categoryArticlesList, category),
      builder: (context, snapshot) {
        final mixedFeed = snapshot.data ?? categoryArticlesList;
        return _buildPageViewForMixedFeed(
          context,
          category,
          mixedFeed,
          isLoading,
          selectedCategory,
          currentIndex,
          error,
          onCurrentIndexChanged,
          colorCache,
          loadMoreArticles,
          pageController,
          articlePageControllers,
        );
      },
    );
  }

  // Helper method to create mixed feed with ads
  static Future<List<dynamic>> _createMixedFeedWithAds(
    List<NewsArticle> articles, 
    String category
  ) async {
    if (articles.isEmpty) return articles;
    
    try {
      return await AdIntegrationService.integrateAdsIntoFeed(
        articles: articles,
        category: category,
        maxAds: 3, // Maximum 3 ads per category
      );
    } catch (e) {
      print('❌ Error integrating ads: $e');
      return articles; // Fallback to articles only
    }
  }

  // Helper method to build PageView for mixed feed
  static Widget _buildPageViewForMixedFeed(
    BuildContext context,
    String category,
    List<dynamic> mixedFeed,
    bool isLoading,
    String selectedCategory,
    int currentIndex,
    String error,
    Function(int) onCurrentIndexChanged,
    Map<String, ColorPalette> colorCache,
    Function(String)? loadMoreArticles,
    PageController? pageController,
    Map<String, PageController> articlePageControllers,
  ) {
    
    if (isLoading && mixedFeed.isEmpty) {
      return NewsFeedWidgets.buildLoadingPage();
    }

    if (mixedFeed.isEmpty) {
      return NewsFeedWidgets.buildNoArticlesPage(context, error);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollStartNotification) {
          ScrollStateService.startScrolling();
        } else if (notification is ScrollEndNotification) {
          ScrollStateService.stopScrolling();
        }
        return false;
      },
      child: PageView.builder(
        controller: pageController, // CRITICAL FIX: Use PageController for bidirectional scrolling
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(), // CRITICAL FIX: Allow smooth rapid scrolling
        itemCount: mixedFeed.length + 1, // CRITICAL FIX: Proper item count for mixed feed
        pageSnapping: true,
        onPageChanged: (index) async {
          final itemType = index < mixedFeed.length ? AdIntegrationService.getItemType(mixedFeed[index]) : 'END';
          print('PAGE CHANGED: Moving to $itemType $index in $category (scrolling: ${ScrollStateService.isActivelyScrolling})');
          
          // Load more articles when approaching the end (3 items before the end)
          // Only if not actively scrolling to prevent list modifications
          if (index >= mixedFeed.length - 3 && loadMoreArticles != null && index < mixedFeed.length && !ScrollStateService.isActivelyScrolling) {
            print('🔄 LOADING MORE: Approaching end at index $index, loading more articles for $category');
            loadMoreArticles(category);
          }
          
          // CRITICAL FIX: Only mark articles as read (not ads) when moving forward and user stops scrolling
          // This prevents article list changes during active scrolling and allows backward navigation
          Future.delayed(const Duration(milliseconds: 1500), () async {
            // Only mark as read if:
            // 1. User has stopped scrolling
            // 2. Moving forward (index > previous index)
            // 3. Valid item range
            // 4. Previous item was an article (not an ad)
            if (!ScrollStateService.isActivelyScrolling && index > 0 && index < mixedFeed.length && mixedFeed.isNotEmpty) {
              // Get the PageController to check scroll direction
              final pageController = articlePageControllers[category];
              if (pageController != null && pageController.hasClients) {
                // Only mark as read if we're moving forward, not backward
                final currentPage = pageController.page ?? 0;
                if (currentPage >= index) { // Moving forward or staying
                  final previousItem = mixedFeed[index - 1];
                  
                  // Only mark as read if previous item was an article (not an ad)
                  if (AdIntegrationService.isNewsArticle(previousItem)) {
                    final previousArticle = previousItem as NewsArticle;
                    await ReadArticlesService.markAsRead(previousArticle.id);
                    
                    // CRITICAL FIX: Never remove from cache during scrolling session
                    // This prevents the "next article changes" issue completely
                    
                    // Track article read for preference learning (only when scrolling stops)
                    CategoryPreferenceService.trackArticleRead(previousArticle, selectedCategory);
                    
                    // 🚀 NEW: Track user reading behavior for ad preloading optimization
                    AdIntegrationService.trackUserReading(
                      articlesRead: index,
                      averageTimePerArticle: 45.0, // TODO: Calculate actual reading time
                      currentCategory: category,
                    );
                    
                    print('✅ SAFE MARK AS READ (FORWARD): "${previousArticle.title}" (ID: ${previousArticle.id}) - user stopped scrolling forward');
                  } else if (AdIntegrationService.isAd(previousItem)) {
                    print('📱 PREVIOUS ITEM WAS AD: Not marking as read');
                  }
                } else {
                  print('⬆️ BACKWARD SCROLL: Not marking item as read - user scrolled back to see previous item');
                }
              }
            } else if (ScrollStateService.isActivelyScrolling) {
              print('⏸️ SKIP MARK AS READ: User still scrolling, preventing cache modifications');
            }
          });
          
          if (category == selectedCategory) {
            onCurrentIndexChanged(index);
          }
          
          // CRITICAL FIX: AGGRESSIVE preloading - preload way ahead (only for articles, not ads)
          if (index < mixedFeed.length) {
            // Update scroll metrics for velocity tracking
            PredictivePreloaderService.updateScrollMetrics(index.toDouble());
            
            // Only preload if current item is an article (not an ad)
            final currentItem = mixedFeed[index];
            if (AdIntegrationService.isNewsArticle(currentItem)) {
              // INSTANT PRELOAD: Preload next article images immediately when user scrolls
              print('🚀 SCROLL PRELOAD: User at article index $index, preloading next images');
              
              // Extract only articles from mixed feed for preloading
              final articlesOnly = mixedFeed.whereType<NewsArticle>().toList();
              final articleIndex = articlesOnly.indexOf(currentItem as NewsArticle);
              
              if (articleIndex >= 0) {
                OptimizedImageService.preloadImagesAggressively(articlesOnly, articleIndex, preloadCount: 25);
                PredictivePreloaderService.predictivePreload(articlesOnly, articleIndex);
                _preloadColorsForUpcomingArticles(articlesOnly, articleIndex, colorCache);
              }
            } else {
              print('📱 SCROLL PRELOAD: Current item is ad, skipping image preloading');
            }
          }
        },
        itemBuilder: (context, index) {
        // If we've scrolled beyond available items, show loading or end message
        if (index >= mixedFeed.length) {
          // If we're loading more articles, show loading indicator
          if (isLoading) {
            return NewsFeedWidgets.buildLoadingPage();
          }
          // Otherwise show end of articles page
          return NewsFeedWidgets.buildEndOfArticlesPage(context, () {
            onCurrentIndexChanged(0);
          });
        }
        
        final item = mixedFeed[index];
        
        // Handle different item types
        if (AdIntegrationService.isAd(item)) {
          // Render native ad card with dynamic colors like articles
          final adModel = item as NativeAdModel;
          final adPalette = _generateAdColorPalette(); // Generate colors for ad
          
          if (adModel.isLoaded && adModel.nativeAd != null) {
            // Real native ad - use AdWidget
            return Container(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                children: [
                  // Top spacing to avoid header overlap
                  SizedBox(height: MediaQuery.of(context).padding.top + 70),
                  
                  // Pure ad content - no container styling
                  Expanded(
                    child: AdWidget(ad: adModel.nativeAd!), // Safe to use ! here since we checked above
                  ),
                  
                  // Bottom spacing
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            );
          } else {
            // Mock ad or loading state - show custom UI that looks like news article
            return Container(
              width: double.infinity,
              height: double.infinity,
              color: CupertinoColors.black,
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top + 70),
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ad image placeholder
                          Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [adPalette.primary, adPalette.secondary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.star_fill,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Sponsored',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          SizedBox(height: 20),
                          
                          // Ad title
                          Text(
                            adModel.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Ad description
                          Text(
                            adModel.description,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                          
                          Spacer(),
                          
                          // Call to action button
                          Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [adPalette.primary, adPalette.accent],
                              ),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Center(
                              child: Text(
                                adModel.callToAction,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            );
          }
        } else if (AdIntegrationService.isNewsArticle(item)) {
          // Render news article card
          final article = item as NewsArticle;
          return Container(
            width: double.infinity,
            height: double.infinity,
            child: buildFullScreenCard(context, article, index, colorCache),
          );
        } else {
          // Fallback for unknown item types
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.red,
            child: Center(
              child: Text(
                'Unknown item type',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          );
        }
        },
      ),
    );
  }

  // Helper method to generate color palette for ads
  static ColorPalette _generateAdColorPalette() {
    // Generate a consistent color palette for ads
    final adColors = [
      const Color(0xFF1E3A8A), // Blue
      const Color(0xFF7C3AED), // Purple
      const Color(0xFF059669), // Green
      const Color(0xFFDC2626), // Red
      const Color(0xFFEA580C), // Orange
    ];
    
    final selectedColor = adColors[DateTime.now().millisecondsSinceEpoch % adColors.length];
    
    return ColorPalette(
      primary: selectedColor,
      secondary: selectedColor.withValues(alpha: 0.8),
      accent: selectedColor.withValues(alpha: 0.6),
      background: selectedColor.withValues(alpha: 0.1),
      surface: selectedColor.withValues(alpha: 0.05),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onAccent: Colors.white,
    );
  }

  static Widget buildFullScreenCard(
    BuildContext context,
    NewsArticle article, 
    int index, 
    Map<String, ColorPalette> colorCache
  ) {
    final cachedPalette = colorCache[article.imageUrl];
    
    final titlePreview = article.title.length > 50 ? article.title.substring(0, 50) : article.title;
    
    if (cachedPalette != null) {
      print('🎯 USING CACHED COLOR: Article $index (ID: ${article.id}) - $titlePreview...');
      return NewsFeedWidgets.buildCardWithPalette(context, article, index, cachedPalette);
    }
    
    print('⏳ LOADING COLOR: Article $index (ID: ${article.id}) - $titlePreview...');
    // CRITICAL FIX: Use non-blocking color extraction
    final palette = ParallelColorService.getCachedColorOrDefault(article.imageUrl);
    
    // Start background extraction if not cached
    if (!ParallelColorService.isColorCached(article.imageUrl)) {
      ParallelColorService.extractColorsParallel(article.imageUrl).then((extractedPalette) {
        colorCache[article.imageUrl] = extractedPalette;
        // Note: UI will update automatically when setState is called elsewhere
      });
    }
    
    return NewsFeedWidgets.buildCardWithPalette(context, article, index, palette);
  }

  static Widget buildCategoryPageView(
    BuildContext context,
    List<String> categories,
    PageController categoryPageController,
    String selectedCategory,
    int currentIndex,
    Map<String, List<NewsArticle>> categoryArticles,
    Map<String, bool> categoryLoading,
    String error,
    Function(String) onCategoryChanged,
    Function(int) onCurrentIndexChanged,
    Function(String) loadArticlesByCategoryForCache,
    Function() loadNewsArticles,
    Map<String, ColorPalette> colorCache,
    Map<String, PageController> articlePageControllers, // Add PageControllers for each category
  ) {
    return PageView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemCount: categories.length,
      controller: categoryPageController,
      onPageChanged: (categoryIndex) {
        final newCategory = categories[categoryIndex];
        if (newCategory != selectedCategory) {
          print('RIGHT SWIPE DETECTED: Switching from $selectedCategory to $newCategory');
          
          // Track category switch for preference learning
          CategoryPreferenceService.trackCategorySwitch(selectedCategory, newCategory);
          onCategoryChanged(newCategory);
          onCurrentIndexChanged(0);
          
          // Force load the specific category
          if (newCategory == 'All') {
            loadNewsArticles();
          } else {
            print('Loading specific category: $newCategory');
            loadArticlesByCategoryForCache(newCategory);
          }
          
          // Check if category is already pre-loaded
          if (categoryArticles[newCategory]?.isNotEmpty == true) {
            // Category is ready - switch immediately
            print('Instant switch to $newCategory: ${categoryArticles[newCategory]!.length} articles ready');
          } else {
            // Category not ready - show loading state
            print('Loading $newCategory on-demand...');
          }
        }
      },
      itemBuilder: (context, categoryIndex) {
        final category = categories[categoryIndex];
        
        // Get or create PageController for this category
        if (!articlePageControllers.containsKey(category)) {
          articlePageControllers[category] = PageController(initialPage: 0);
        }
        
        return buildCategoryContent(
          context,
          category,
          categoryArticles,
          categoryLoading,
          selectedCategory,
          currentIndex,
          error,
          onCurrentIndexChanged,
          colorCache,
          loadArticlesByCategoryForCache, // Pass the load more articles callback
          articlePageControllers[category], // Pass the PageController for bidirectional scrolling
          articlePageControllers, // Pass the PageControllers map for direction checking
        );
      },
    );
  }
}