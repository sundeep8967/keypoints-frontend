import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/news_article.dart';

import '../utils/app_logger.dart';
class ImagePreloaderService {
  static final Map<String, bool> _preloadedImages = {};
  static final Map<String, bool> _preloadingInProgress = {};

  /// Preload images for the next few articles to improve user experience
  static Future<void> preloadNextArticleImages(
    List<NewsArticle> articles,
    int currentIndex, {
    int preloadCount = 15, // CRITICAL FIX: Increased from 3 to 15
  }) async {
    if (articles.isEmpty || currentIndex >= articles.length) return;

    // Calculate the range of articles to preload
    final startIndex = currentIndex + 1;
    final endIndex = (startIndex + preloadCount).clamp(0, articles.length);

    AppLogger.info(' PRELOADING: Current article index: $currentIndex');
    if (currentIndex < articles.length) {
      AppLogger.log('📖 CURRENT ARTICLE: "${articles[currentIndex].title}"');
      AppLogger.log('🖼️ CURRENT IMAGE: ${articles[currentIndex].imageUrl.substring(0, 50)}...');
    }
    
    AppLogger.info(' PRELOADING NEXT $preloadCount ARTICLES (indices $startIndex to ${endIndex - 1}):');
    for (int i = startIndex; i < endIndex; i++) {
      if (i < articles.length) {
        AppLogger.log('  📄 Article $i: "${articles[i].title}"');
        AppLogger.log('  🖼️ Image $i: ${articles[i].imageUrl.substring(0, 50)}...');
      }
    }

    // Preload images in parallel for better performance
    final preloadFutures = <Future<void>>[];

    for (int i = startIndex; i < endIndex; i++) {
      if (i < articles.length) {
        final imageUrl = articles[i].imageUrl;
        
        // Skip if already preloaded or currently preloading
        if (_preloadedImages[imageUrl] == true || _preloadingInProgress[imageUrl] == true) {
          continue;
        }

        preloadFutures.add(_preloadSingleImage(imageUrl));
      }
    }

    // Wait for all preloading to complete
    await Future.wait(preloadFutures);
  }

  /// Preload a single image
  static Future<void> _preloadSingleImage(String imageUrl) async {
    if (imageUrl.isEmpty) return;

    try {
      _preloadingInProgress[imageUrl] = true;
      
      // Use CachedNetworkImage to preload and cache the image
      final imageProvider = CachedNetworkImageProvider(imageUrl);
      
      // Create a completer to wait for image loading
      final completer = Completer<void>();
      
      final imageStream = imageProvider.resolve(const ImageConfiguration());
      late ImageStreamListener listener;
      
      listener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          imageStream.removeListener(listener);
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (exception, stackTrace) {
          imageStream.removeListener(listener);
          if (!completer.isCompleted) {
            completer.completeError(exception);
          }
        },
      );
      
      imageStream.addListener(listener);
      await completer.future;
      
      _preloadedImages[imageUrl] = true;
      AppLogger.success(' Successfully preloaded image: ${imageUrl.substring(0, 50)}...');
    } catch (e) {
      AppLogger.log('Failed to preload image $imageUrl: $e');
      _preloadedImages[imageUrl] = false;
    } finally {
      _preloadingInProgress[imageUrl] = false;
    }
  }

  /// Preload images when user is reading an article (triggered by page change)
  static Future<void> onArticleViewed(
    List<NewsArticle> articles,
    int viewedIndex,
  ) async {
    AppLogger.log('\n🎯 USER VIEWED ARTICLE AT INDEX: $viewedIndex');
    if (viewedIndex < articles.length) {
      AppLogger.log('👀 VIEWING: "${articles[viewedIndex].title}"');
      AppLogger.log('🖼️ VIEWING IMAGE: ${articles[viewedIndex].imageUrl.substring(0, 50)}...');
    }
    
    // Preload next 15 images when user views an article (CRITICAL FIX)
    await preloadNextArticleImages(articles, viewedIndex, preloadCount: 15);
    
    // Also preload previous image if user might swipe back
    if (viewedIndex > 0) {
      final prevImageUrl = articles[viewedIndex - 1].imageUrl;
      if (_preloadedImages[prevImageUrl] != true && _preloadingInProgress[prevImageUrl] != true) {
        AppLogger.log('⬅️ Also preloading previous image for article ${viewedIndex - 1}');
        _preloadSingleImage(prevImageUrl);
      }
    }
    AppLogger.log('─────────────────────────────────────────────────────\n');
  }

  /// Check if an image is already preloaded
  static bool isImagePreloaded(String imageUrl) {
    return _preloadedImages[imageUrl] == true;
  }

  /// Clear preloaded image cache (call when memory is low)
  static void clearPreloadCache() {
    _preloadedImages.clear();
    _preloadingInProgress.clear();
    AppLogger.log('Cleared image preload cache');
  }

  /// Get preload statistics for debugging
  static Map<String, int> getPreloadStats() {
    final preloaded = _preloadedImages.values.where((v) => v == true).length;
    final failed = _preloadedImages.values.where((v) => v == false).length;
    final inProgress = _preloadingInProgress.values.where((v) => v == true).length;
    
    return {
      'preloaded': preloaded,
      'failed': failed,
      'inProgress': inProgress,
      'total': _preloadedImages.length,
    };
  }

  /// Preload images for an entire category when it's selected
  static Future<void> preloadCategoryImages(
    List<NewsArticle> categoryArticles, {
    int maxImages = 10,
  }) async {
    if (categoryArticles.isEmpty) return;

    AppLogger.log('Preloading first $maxImages images for category');

    final preloadFutures = <Future<void>>[];
    final imagesToPreload = categoryArticles.take(maxImages);

    for (final article in imagesToPreload) {
      final imageUrl = article.imageUrl;
      
      if (_preloadedImages[imageUrl] != true && _preloadingInProgress[imageUrl] != true) {
        preloadFutures.add(_preloadSingleImage(imageUrl));
      }
    }

    await Future.wait(preloadFutures);
    AppLogger.log('Completed category image preloading');
  }
}

// Simple image preloading without navigation service dependency