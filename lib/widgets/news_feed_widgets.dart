import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/news_article.dart';
import '../screens/news_detail_screen.dart';
import '../services/color_extraction_service.dart';
import '../services/news_feed_helper.dart';
import '../services/text_formatting_service.dart';
import '../services/dynamic_text_service.dart';
import '../services/url_launcher_service.dart';

class NewsFeedWidgets {
  static Widget buildNoArticlesPage(BuildContext context, String error) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF1a1a1a),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 70),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.news,
                    size: 80,
                    color: CupertinoColors.systemGrey,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No Articles Available',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    error.isNotEmpty ? error : 'All articles have been read!\nCheck back later for new content.',
                    style: const TextStyle(
                      fontSize: 16,
                      color: CupertinoColors.systemGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildEndOfArticlesPage(BuildContext context, VoidCallback onBackToTop) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF2a2a2a),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 70),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    size: 80,
                    color: CupertinoColors.systemGreen,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'You\'re All Caught Up!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You\'ve read all available articles.\nCheck back later for fresh content!',
                    style: TextStyle(
                      fontSize: 16,
                      color: CupertinoColors.systemGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoButton(
                        onPressed: onBackToTop,
                        child: const Text(
                          'Back to Top',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildLoadingPage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(
            radius: 20,
            color: Colors.white,
          ),
          SizedBox(height: 16),
          Text(
            'Loading articles...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildCardWithPalette(
    BuildContext context,
    NewsArticle article, 
    int index, 
    ColorPalette palette
  ) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: palette.primary,
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 70),
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
                  // Intelligently fill available space with content
                  DynamicTextService.buildAdaptiveContent(
                    keypoints: article.keypoints,
                    description: article.description,
                    baseStyle: TextStyle(
                      fontSize: 16,
                      color: palette.onPrimary.withOpacity(0.9),
                      height: 1.4, // Compact line spacing for more content
                      letterSpacing: 0.1,
                    ),
                    minLines: 4,
                    maxLines: 20, // Allow more lines to fill space
                  ),
                  
                  // Small gap before bottom content
                  const SizedBox(height: 16),
                  // Blurred background with article image for bottom section
                  GestureDetector(
                    onTap: () {
                      print('🔥 BLURRED BOX TAPPED!');
                      print('🔗 Article sourceUrl: "${article.sourceUrl}"');
                      print('📰 Article title: "${article.title}"');
                      
                      // Open article URL directly in internal browser
                      if (article.sourceUrl != null && article.sourceUrl!.isNotEmpty) {
                        print('✅ URL is available, opening directly in internal browser');
                        UrlLauncherService.launchInternalBrowser(article.sourceUrl!);
                      } else {
                        print('❌ No URL available for this article');
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(article.imageUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Source display on the left (moved from center)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                article.source ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: palette.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'tap to read more!!',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: palette.onPrimary.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              buildActionButton(
                                CupertinoIcons.square_arrow_up,
                                palette.onPrimary,
                                () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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

  static Widget buildActionButton(IconData icon, Color color, VoidCallback onTap) {
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

  static Widget buildHorizontalCategories(
    BuildContext context,
    List<String> categories,
    String selectedCategory,
    ScrollController categoryScrollController,
    Function(String) onCategorySelected,
    Function(int) onScrollToCategory,
  ) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        controller: categoryScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: () {
                onCategorySelected(category);
                // Also scroll to tapped category
                onScrollToCategory(index);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected 
                    ? Colors.white 
                    : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}