import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../domain/entities/news_article_entity.dart';
import '../services/consolidated/article_service.dart';
import '../utils/app_logger.dart';

class NewsDetailScreen extends StatelessWidget {
  final NewsArticleEntity article;

  const NewsDetailScreen({
    super.key,
    required this.article,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.9),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(
            CupertinoIcons.back,
            color: CupertinoColors.systemBlue,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            try {
              await ArticleService.shareArticle(article);
            } catch (e) {
              AppLogger.error('Share failed: $e');
            }
          },
          child: const Icon(
            CupertinoIcons.share,
            color: CupertinoColors.systemBlue,
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Image
              CachedNetworkImage(
                imageUrl: article.imageUrl,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 250,
                  color: CupertinoColors.systemGrey5,
                  child: const Center(
                    child: CupertinoActivityIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 250,
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
              
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timestamp
                    Text(
                      _formatTimestamp(article.timestamp),
                      style: const TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Title
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: CupertinoColors.label,
                        height: 1.2,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Description
                    Text(
                      article.description,
                      style: const TextStyle(
                        fontSize: 17,
                        color: CupertinoColors.label,
                        height: 1.5,
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton.filled(
                            child: const Text('Share'),
                            onPressed: () async {
                              try {
                                await ArticleService.shareArticle(article);
                              } catch (e) {
                                AppLogger.error('Share failed: $e');
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('MMMM dd, yyyy • h:mm a').format(timestamp);
  }
}