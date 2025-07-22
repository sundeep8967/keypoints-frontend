import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/news_article_entity.dart';

class NewsArticleCard extends StatelessWidget {
  final NewsArticleEntity article;
  final VoidCallback onRead;

  const NewsArticleCard({
    super.key,
    required this.article,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: CupertinoColors.black,
      ),
      child: Stack(
        children: [
          // Background Image
          _buildBackgroundImage(),
          
          // Gradient Overlay
          _buildGradientOverlay(),
          
          // Content
          _buildContent(context),
          
          // Read Indicator
          if (article.isRead) _buildReadIndicator(),
        ],
      ),
    );
  }

  Widget _buildBackgroundImage() {
    return Positioned.fill(
      child: CachedNetworkImage(
        imageUrl: article.imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: CupertinoColors.systemGrey6,
          child: const Center(
            child: CupertinoActivityIndicator(),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: CupertinoColors.systemGrey6,
          child: const Icon(
            CupertinoIcons.photo,
            size: 50,
            color: CupertinoColors.systemGrey,
          ),
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black54,
              Colors.black87,
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Badge
          _buildCategoryBadge(),
          
          const SizedBox(height: 12),
          
          // Title
          Text(
            article.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 8),
          
          // Description
          Text(
            article.description,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 16),
          
          // Action Buttons
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBlue.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        article.category.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        // Read Button
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: CupertinoColors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(25),
          onPressed: onRead,
          child: const Text(
            'Mark as Read',
            style: TextStyle(
              color: CupertinoColors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Share Button
        CupertinoButton(
          padding: const EdgeInsets.all(12),
          color: CupertinoColors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(25),
          onPressed: () {
            // TODO: Implement share functionality
          },
          child: const Icon(
            CupertinoIcons.share,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildReadIndicator() {
    return Positioned(
      top: 50,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGreen.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.checkmark_circle_fill,
              color: Colors.white,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              'READ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}