import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/news_article.dart';
import '../services/color_extraction_service.dart';
import '../services/read_articles_service.dart';
import '../services/category_preference_service.dart';
import '../services/image_preloader_service.dart';
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
        final palette = await ColorExtractionService.extractColorsFromImage(articles[i].imageUrl);
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
  ) {
    final categoryArticlesList = categoryArticles[category] ?? [];
    final isLoading = categoryLoading[category] ?? false;
    
    // Always use category-specific articles, not the main _articles list
    final articlesToShow = categoryArticlesList;
    
    if (isLoading && articlesToShow.isEmpty) {
      return NewsFeedWidgets.buildLoadingPage();
    }

    if (articlesToShow.isEmpty) {
      return NewsFeedWidgets.buildNoArticlesPage(context, error);
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
          
          // Smart read tracking: Remove this article from all category caches
          CategoryPreferenceService.removeReadArticleFromCaches(previousArticle.id, categoryArticles);
          
          // Track article read for preference learning
          CategoryPreferenceService.trackArticleRead(previousArticle, selectedCategory);
          
          print('Marked article "${previousArticle.title}" as read and removed from all categories');
        }
        
        if (category == selectedCategory) {
          onCurrentIndexChanged(index);
        }
        
        // Preload images and colors for next articles when user views current article
        if (index < articlesToShow.length) {
          ImagePreloaderService.onArticleViewed(articlesToShow, index);
          // Also preload colors for upcoming articles
          _preloadColorsForUpcomingArticles(articlesToShow, index, colorCache);
        }
      },
      itemBuilder: (context, index) {
        // Show "end of articles" page after last article
        if (index >= articlesToShow.length) {
          return NewsFeedWidgets.buildEndOfArticlesPage(context, () {
            onCurrentIndexChanged(0);
          });
        }
        
        final article = articlesToShow[index];
        return Container(
          width: double.infinity,
          height: double.infinity,
          child: buildFullScreenCard(context, article, index, colorCache),
        );
      },
    );
  }

  static Widget buildFullScreenCard(
    BuildContext context,
    NewsArticle article, 
    int index, 
    Map<String, ColorPalette> colorCache
  ) {
    final cachedPalette = colorCache[article.imageUrl];
    
    if (cachedPalette != null) {
      final titlePreview = article.title.length > 50 ? article.title.substring(0, 50) : article.title;
      print('🎯 USING CACHED COLOR: Article $index - $titlePreview...');
      return NewsFeedWidgets.buildCardWithPalette(context, article, index, cachedPalette);
    }
    
    final titlePreview = article.title.length > 50 ? article.title.substring(0, 50) : article.title;
    print('⏳ LOADING COLOR: Article $index - $titlePreview...');
    return FutureBuilder<ColorPalette>(
      future: ColorExtractionService.extractColorsFromImage(article.imageUrl),
      builder: (context, snapshot) {
        final palette = snapshot.data ?? ColorPalette.defaultPalette();
        
        if (snapshot.data != null) {
          colorCache[article.imageUrl] = snapshot.data!;
          print('✅ CACHED NEW COLOR: Article $index');
        }
        
        return NewsFeedWidgets.buildCardWithPalette(context, article, index, palette);
      },
    );
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
        );
      },
    );
  }
}