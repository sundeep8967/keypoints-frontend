import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../domain/entities/news_article_entity.dart';
import 'aggressive_cache_manager.dart';

enum ImagePriority { low, normal, high, critical }

class OptimizedImageService {
  static final Map<String, bool> _preloadedImages = {};
  static final Map<String, bool> _preloadingInProgress = {};
  static final Map<String, ImageProvider> _imageProviderCache = {};
  
  /// Initialize global cache settings for better performance
  static void initializeCache() {
    // Configure CachedNetworkImage global settings
    // CachedNetworkImage.logLevel = CacheManagerLogLevel.none; // This property doesn't exist
  }

  /// Get an optimized image widget with instant loading for preloaded images
  static Widget buildOptimizedImage({
    required String imageUrl,
    required BoxFit fit,
    double? width,
    double? height,
    PlaceholderWidgetBuilder? placeholder,
    LoadingErrorWidgetBuilder? errorWidget,
  }) {
    // Check if image is already preloaded
    final isPreloaded = _preloadedImages[imageUrl] == true;
    
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      // Use memory cache aggressively
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      // Faster loading for preloaded images
      fadeInDuration: isPreloaded ? Duration.zero : const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
      placeholder: placeholder ?? (context, url) => Container(
        color: const Color(0xFF2C2C2E),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
            ),
          ),
        ),
      ),
      errorWidget: errorWidget ?? (context, url, error) => Container(
        color: const Color(0xFF2C2C2E),
        child: const Icon(
          Icons.image_not_supported,
          color: Colors.white54,
          size: 40,
        ),
      ),
      // Use optimized cache manager
      cacheManager: AggressiveCacheManager(),
    );
  }

  /// Preload images aggressively for next articles
  static Future<void> preloadImagesAggressively(
    List<NewsArticleEntity> articles,
    int currentIndex, {
    int preloadCount = 15, // CRITICAL FIX: Increased from 5 to 15
  }) async {
    if (articles.isEmpty || currentIndex >= articles.length) return;

    final startIndex = currentIndex;
    final endIndex = (startIndex + preloadCount).clamp(0, articles.length);

    // Preloading images for better performance

    // Preload current image first (highest priority)
    if (currentIndex < articles.length) {
      final currentImageUrl = articles[currentIndex].imageUrl;
      if (!_isImageCached(currentImageUrl)) {
        await _preloadSingleImageFast(currentImageUrl, priority: true);
      }
    }

    // Preload next images in parallel
    final preloadFutures = <Future<void>>[];
    for (int i = startIndex + 1; i < endIndex; i++) {
      if (i < articles.length) {
        final imageUrl = articles[i].imageUrl;
        if (!_isImageCached(imageUrl)) {
          preloadFutures.add(_preloadSingleImageFast(imageUrl));
        }
      }
    }

    // Don't wait for all to complete - let them load in background
    Future.wait(preloadFutures).catchError((e) {
      // Handle errors silently
      return <void>[];
    });
  }

  /// Fast single image preloading
  static Future<void> _preloadSingleImageFast(String imageUrl, {bool priority = false}) async {
    if (imageUrl.isEmpty || _preloadingInProgress[imageUrl] == true) return;

    try {
      _preloadingInProgress[imageUrl] = true;
      
      // 🚀 HIGH PRIORITY: Use aggressive cache manager for priority images
      final cacheManager = priority 
          ? AggressiveCacheManager() 
          : DefaultCacheManager();
      
      // 🎯 PRIORITY: Use appropriate cache manager based on priority
      final imageProvider = CachedNetworkImageProvider(
        imageUrl,
        cacheManager: cacheManager,
        maxHeight: priority ? null : 400, // Full resolution for priority images
        maxWidth: priority ? null : 400,
      );
      
      // Cache the provider for instant access
      _imageProviderCache[imageUrl] = imageProvider;
      
      // 🚀 PRIORITY: Configure based on priority level
      final imageConfiguration = ImageConfiguration(
        size: priority ? null : const Size(200, 150), // Full size for priority, smaller for background
      );
      
      final completer = Completer<void>();
      final imageStream = imageProvider.resolve(imageConfiguration);
      
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          imageStream.removeListener(listener);
          _preloadedImages[imageUrl] = true;
          if (!completer.isCompleted) {
            completer.complete();
          }
          // Image loaded successfully
        },
        onError: (exception, stackTrace) {
          imageStream.removeListener(listener);
          _preloadedImages[imageUrl] = false;
          if (!completer.isCompleted) {
            completer.completeError(exception);
          }
        },
      );
      
      imageStream.addListener(listener);
      
      // For priority images, wait for completion
      if (priority) {
        await completer.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            // Handle timeout silently
          },
        );
      }
      
    } catch (e) {
      // Handle error silently
      _preloadedImages[imageUrl] = false;
    } finally {
      _preloadingInProgress[imageUrl] = false;
    }
  }

  /// Check if image is cached (preloaded or in memory)
  static bool _isImageCached(String imageUrl) {
    return _preloadedImages[imageUrl] == true || 
           _imageProviderCache.containsKey(imageUrl);
  }

  /// Preload images when user scrolls to an article
  static Future<void> onArticleViewed(
    List<NewsArticleEntity> articles,
    int viewedIndex,
  ) async {
    // Aggressively preload next 15 images (CRITICAL FIX)
    await preloadImagesAggressively(articles, viewedIndex, preloadCount: 15);
    
    // Also preload previous image for smooth back navigation
    if (viewedIndex > 0) {
      final prevImageUrl = articles[viewedIndex - 1].imageUrl;
      if (!_isImageCached(prevImageUrl)) {
        _preloadSingleImageFast(prevImageUrl);
      }
    }
  }

  /// Preload first batch of images for a category
  static Future<void> preloadCategoryImages(
    List<NewsArticleEntity> articles, {
    int maxImages = 8,
  }) async {
    if (articles.isEmpty) return;
    
    final imagesToPreload = articles.take(maxImages).toList();
    final preloadFutures = <Future<void>>[];

    // Preload first image with priority
    if (imagesToPreload.isNotEmpty) {
      await _preloadSingleImageFast(imagesToPreload.first.imageUrl, priority: true);
    }

    // Preload rest in background
    for (int i = 1; i < imagesToPreload.length; i++) {
      final imageUrl = imagesToPreload[i].imageUrl;
      if (!_isImageCached(imageUrl)) {
        preloadFutures.add(_preloadSingleImageFast(imageUrl));
      }
    }

    // Let background preloading continue without blocking
    Future.wait(preloadFutures).catchError((e) {
      // Handle errors silently
      return <void>[];
    });
  }

  /// Clear cache when memory is low
  static void clearCache() {
    _preloadedImages.clear();
    _preloadingInProgress.clear();
    _imageProviderCache.clear();
    // Cache cleared
  }

  /// Preload single image with highest priority (for instant loading)
  static Future<void> preloadSingleImageWithPriority(String imageUrl) async {
    return _preloadSingleImageFast(imageUrl, priority: true);
  }

  /// Get cache statistics
  static Map<String, int> getCacheStats() {
    return {
      'preloaded': _preloadedImages.values.where((v) => v == true).length,
      'failed': _preloadedImages.values.where((v) => v == false).length,
      'inProgress': _preloadingInProgress.values.where((v) => v == true).length,
      'cached_providers': _imageProviderCache.length,
    };
  }
}