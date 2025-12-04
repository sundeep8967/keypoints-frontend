import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/entities/news_article_entity.dart';
import '../services/url_launcher_service.dart';
import '../utils/app_logger.dart';

class TinderStyleNewsCard extends StatelessWidget {
  final NewsArticleEntity article;
  final int index;

  const TinderStyleNewsCard({
    super.key,
    required this.article,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: CupertinoColors.black, // Match loading page background
      child: Column(
        children: [
          // Top spacing for header (match loading page)
          const SizedBox(height: 120),
          
          // Main card content (match loading page layout)
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24), // Match loading page
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image section (60% of the card) - matches loading page ratio
                    Expanded(
                      flex: 3,
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: article.imageUrl,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 300),
                            fadeOutDuration: const Duration(milliseconds: 200),
                            memCacheWidth: (MediaQuery.of(context).size.width * 
                                MediaQuery.of(context).devicePixelRatio).round(),
                            placeholder: (context, url) => Container(
                              color: Colors.white.withValues(alpha: 0.2),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.photo,
                                      size: 48,
                                      color: CupertinoColors.systemGrey,
                                    ),
                                    SizedBox(height: 12),
                                    CupertinoActivityIndicator(
                                      radius: 16,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.white.withValues(alpha: 0.2),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.photo,
                                      size: 48,
                                      color: CupertinoColors.systemGrey,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Image unavailable',
                                      style: TextStyle(
                                        color: CupertinoColors.systemGrey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Content section (40% of the card) - matches loading page ratio  
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12, 
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                article.category.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Title
                            Expanded(
                              flex: 2,
                              child: Text(
                                article.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Description
                            Expanded(
                              flex: 2,
                              child: Text(
                                article.description,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: CupertinoColors.systemGrey,
                                  height: 1.4,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Action buttons
                            Row(
                              children: [
                                // Read more button
                                Expanded(
                                  child: CupertinoButton(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    color: CupertinoColors.systemBlue,
                                    borderRadius: BorderRadius.circular(12),
                                    onPressed: () {
                                      if (article.sourceUrl != null && 
                                          article.sourceUrl!.isNotEmpty) {
                                        UrlLauncherService.launchInternalBrowser(
                                          article.sourceUrl!
                                        );
                                      }
                                    },
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Read More',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          CupertinoIcons.arrow_up_right,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(width: 12),
                                
                                // Share button
                                CupertinoButton(
                                  padding: const EdgeInsets.all(12),
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  onPressed: () => _shareArticle(article),
                                  child: const Icon(
                                    CupertinoIcons.share,
                                    size: 20,
                                    color: CupertinoColors.systemBlue,
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
              ),
            ),
          ),
          
          // Bottom spacing (match loading page)
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _shareArticle(NewsArticleEntity article) async {
    try {
      final shareText = '''
📰 ${article.title}

${article.description}

📱 Read more on Key Points News App
${article.sourceUrl != null && article.sourceUrl!.isNotEmpty ? '\n🔗 Source: ${article.sourceUrl}' : ''}
''';
      
      await Share.share(
        shareText,
        subject: '📰 ${article.title} - Key Points News',
      );
    } catch (e) {
      AppLogger.error('Share failed: $e');
    }
  }
}