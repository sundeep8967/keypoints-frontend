import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../domain/entities/news_article_entity.dart';
import '../services/color_extraction_service.dart';

class NewsCardStack extends StatelessWidget {
  final List<NewsArticleEntity> articles;
  final int currentIndex;
  final Map<String, ColorPalette> colorCache;
  final Function(int) onIndexChanged;
  final Function(NewsArticleEntity) onArticleRead;
  final Function(NewsArticleEntity) onArticleShare;

  const NewsCardStack({
    super.key,
    required this.articles,
    required this.currentIndex,
    required this.colorCache,
    required this.onIndexChanged,
    required this.onArticleRead,
    required this.onArticleShare,
  });

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      color: CupertinoColors.black,
      child: PageView.builder(
        itemCount: articles.length,
        onPageChanged: onIndexChanged,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.all(16),
            child: Text(
              articles[index].title,
              style: const TextStyle(color: CupertinoColors.white),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF1a1a1a),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.news,
              size: 80,
              color: CupertinoColors.systemGrey,
            ),
            SizedBox(height: 24),
            Text(
              'No Articles Available',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'All articles have been read!\nCheck back later for new content.',
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.systemGrey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}