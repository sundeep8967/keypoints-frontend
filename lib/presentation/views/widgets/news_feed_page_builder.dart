import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../domain/entities/news_article_entity.dart';
import '../../../data/services/read_articles_service.dart';
import '../../../data/models/native_ad_model.dart';
import '../widgets/news_feed_widgets.dart';

import '../../../core/utils/app_logger.dart';

class NewsFeedPageBuilder {
  static Widget buildCategoryContent(
    BuildContext context,
    String category,
    List<dynamic> items,
    int currentIndex,
    PageController pageController,
    void Function(String category, int afterIndex) onDemandAdAtIndex,
  ) {
    // Filter for articles to preload images
    final articles = items.whereType<NewsArticleEntity>().toList();
    if (articles.isNotEmpty) {
      _preloadImagesForUpcomingArticles(articles, currentIndex);
    }

    return PageView.builder(
      controller: pageController,
      scrollDirection: Axis.vertical,
      itemCount: items.length,
      onPageChanged: (index) {
        _handlePageChange(context, index, items, category, onDemandAdAtIndex);
      },
      itemBuilder: (context, index) {
        final item = items[index];
        
        if (item is NewsArticleEntity) {
          return _buildNewsCard(context, item, index);
        } else if (item is NativeAdModel) {
          return _buildAdCard(context, item);
        }
        
        return const SizedBox();
      },
    );
  }

  static Widget _buildNewsCard(
    BuildContext context,
    NewsArticleEntity article,
    int index,
  ) {
    try {
      return NewsFeedWidgets.buildTinderStyleCard(context, article, index);
    } catch (e) {
      AppLogger.error('Error building news card for article $index: $e');
      return const SizedBox();
    }
  }

  static Widget _buildAdCard(BuildContext context, NativeAdModel adModel) {
    try {
      return NewsFeedWidgets.buildAdCard(context, adModel);
    } catch (e) {
      AppLogger.error('Error building ad card: $e');
      return const SizedBox();
    }
  }

  static void _handlePageChange(
    BuildContext context,
    int index,
    List<dynamic> items,
    String category,
    void Function(String category, int afterIndex) onDemandAdAtIndex,
  ) {
    final item = items[index];
    
    if (item is NewsArticleEntity) {
      // Mark article as read when user swipes to it
      ReadArticlesService.markAsRead(item.id);
      final t = item.title;
      final preview = t.length > 50 ? t.substring(0, 50) + '…' : t;
      AppLogger.log('📖 Viewing article: $preview');
      
      // Preload upcoming articles
      final articlesOnly = items.whereType<NewsArticleEntity>().toList();
      final articleIndex = articlesOnly.indexOf(item);
      
      if (articleIndex != -1) {
        _preloadImagesForUpcomingArticles(articlesOnly, articleIndex);
        
        // On-demand ad trigger: after every 5 articles
        if (((articleIndex + 1) % 5 == 0)) {
          final nextIndexInItems = index + 1;
          final nextExists = nextIndexInItems < items.length;
          final nextIsAd = nextExists ? items[nextIndexInItems] is NativeAdModel : false;
          if (!nextIsAd) {
            onDemandAdAtIndex(category, index); // request ad after this index
          }
        }
      }
    }
  }

  static void _preloadImagesForUpcomingArticles(
    List<NewsArticleEntity> articles,
    int currentIndex,
  ) {
    // Placeholder for image preloading if needed in future
  }

  static Widget buildFullScreenCard(
    BuildContext context,
    NewsArticleEntity article,
    int index,
  ) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: NewsFeedWidgets.buildSimpleCard(context, article, index),
    );
  }

  static Widget buildCategoryPageView(
    BuildContext context,
    List<String> categories,
    PageController categoryPageController,
    String selectedCategory,
    int currentIndex,
    Map<String, List<dynamic>> categoryItems, // Updated to dynamic
    Map<String, bool> categoryLoading,
    String error,
    Function(String) onCategorySelected,
    Function(int) onIndexChanged,
    Function(String) onLoadMore,
    Function() onLoadAll,
    Map<String, PageController> articlePageControllers,
    void Function(String category, int afterIndex) onDemandAdAtIndex,
  ) {
    return PageView.builder(
      controller: categoryPageController,
      itemCount: categories.length,
      onPageChanged: (index) {
        if (index < categories.length) {
          onCategorySelected(categories[index]);
        }
      },
      itemBuilder: (context, categoryIndex) {
        if (categoryIndex >= categories.length) return const SizedBox();
        
        final category = categories[categoryIndex];
        final items = categoryItems[category] ?? [];
        final isLoading = categoryLoading[category] ?? false;

        if (isLoading && items.isEmpty) {
          return NewsFeedWidgets.buildLoadingPage();
        }

        if (items.isEmpty && error.isNotEmpty) {
          return NewsFeedWidgets.buildNoArticlesPage(context, error);
        }

        if (items.isEmpty) {
          return NewsFeedWidgets.buildNoArticlesPage(context, 'No articles available for $category');
        }

        // Get or create PageController for this category
        if (!articlePageControllers.containsKey(category)) {
          articlePageControllers[category] = PageController();
        }
        
        final pageController = articlePageControllers[category]!;

        return buildCategoryContent(
          context,
          category,
          items,
          currentIndex,
          pageController,
          onDemandAdAtIndex,
        );
      },
    );
  }
}