import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/news_article.dart';
import '../services/color_extraction_service.dart';
import '../services/dynamic_text_service.dart';
import '../services/url_launcher_service.dart';

class OptimizedNewsCard extends StatelessWidget {
  final NewsArticle article;
  final ColorPalette palette;
  final VoidCallback? onTap;

  const OptimizedNewsCard({
    super.key,
    required this.article,
    required this.palette,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: palette.primary,
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 70),
          // Optimized image section
          Container(
            height: MediaQuery.of(context).size.height * 0.3,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: article.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      fadeInDuration: const Duration(milliseconds: 150),
                      fadeOutDuration: const Duration(milliseconds: 100),
                      memCacheWidth: 400,
                      memCacheHeight: 300,
                      placeholder: (context, url) => Container(
                        decoration: BoxDecoration(
                          color: palette.secondary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: CupertinoActivityIndicator(
                            color: palette.onPrimary,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
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
                      ),
                    ),
                  ),
                ),
                // Category badge
                Positioned(
                  top: 15,
                  left: 15,
                  child: Container(
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
                ),
              ],
            ),
          ),
          // Content section
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
                  
                  // Dynamic content
                  DynamicTextService.buildAdaptiveContent(
                    keypoints: article.keypoints,
                    description: article.description,
                    baseStyle: TextStyle(
                      fontSize: 16,
                      color: palette.onPrimary.withValues(alpha: 0.9),
                      height: 1.4,
                      letterSpacing: 0.1,
                    ),
                    minLines: 4,
                    maxLines: 20,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Action section with optimized background
                  GestureDetector(
                    onTap: () {
                      if (article.sourceUrl != null && article.sourceUrl!.isNotEmpty) {
                        UrlLauncherService.launchInternalBrowser(article.sourceUrl!);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        // Use a simple gradient instead of blurred image for better performance
                        gradient: LinearGradient(
                          colors: [
                            palette.secondary.withValues(alpha: 0.8),
                            palette.secondary.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
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
                                    color: palette.onPrimary.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              CupertinoIcons.square_arrow_up,
                              size: 20,
                              color: palette.onPrimary,
                            ),
                          ],
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
}