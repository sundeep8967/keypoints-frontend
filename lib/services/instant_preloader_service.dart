import 'dart:async';
import '../domain/entities/news_article_entity.dart';
import 'optimized_image_service.dart';
import 'parallel_color_service.dart';

import '../utils/app_logger.dart';
/// CRITICAL FIX: Instant preloader that starts immediately when articles load
class InstantPreloaderService {
  static Timer? _preloadTimer;
  static bool _isPreloading = false;
  
  /// Start instant preloading the moment articles are available
  static void startInstantPreloading(List<NewsArticleEntity> articles, {bool highPriority = true}) {
    if (articles.isEmpty || _isPreloading) return;
    
    _isPreloading = true;
    AppLogger.info(' INSTANT PRELOAD: Starting immediate preloading of ${articles.length} articles');
    
    // Cancel any existing timer
    _preloadTimer?.cancel();
    
    // Start preloading immediately - don't wait for user to scroll
    _preloadTimer = Timer(Duration.zero, () async {
      await _preloadAllImagesInstantly(articles);
    });
  }
  
  /// Preload ALL images instantly in batches for zero delay
  static Future<void> _preloadAllImagesInstantly(List<NewsArticleEntity> articles) async {
    try {
      AppLogger.info(' INSTANT PRELOAD: Preloading first 30 images for instant access');
      
      // Preload first 30 images in parallel for instant access
      final imagesToPreload = articles.take(30).toList();
      
      // Preload first 5 images with highest priority (wait for them)
      AppLogger.info(' INSTANT PRELOAD: Priority loading first 5 images');
      for (int i = 0; i < imagesToPreload.length && i < 5; i++) {
        final imageUrl = imagesToPreload[i].imageUrl;
        // 🚀 HIGH PRIORITY: Use priority preloading for instant loading
        await OptimizedImageService.preloadSingleImageWithPriority(imageUrl);
        AppLogger.success(' INSTANT PRELOAD: Priority image $i loaded');
      }
      
      // Preload next 25 images in background (don't wait)
      AppLogger.info(' INSTANT PRELOAD: Background loading next 25 images');
      final backgroundFutures = <Future<void>>[];
      for (int i = 5; i < imagesToPreload.length; i++) {
        final imageUrl = imagesToPreload[i].imageUrl;
        // 🔄 BACKGROUND: Use normal priority for background preloading
        backgroundFutures.add(OptimizedImageService.preloadSingleImageWithPriority(imageUrl));
      }
      
      // Let background preloading continue without blocking
      Future.wait(backgroundFutures).then((_) {
        AppLogger.success(' INSTANT PRELOAD: All 30 images preloaded successfully');
      }).catchError((e) {
        AppLogger.error(' INSTANT PRELOAD: Some images failed to preload: $e');
      });
      
      // Also preload colors for first 15 articles
      ParallelColorService.preloadColorsParallel(articles, 0, colorPreloadCount: 15);
      
    } catch (e) {
      AppLogger.error(' INSTANT PRELOAD ERROR: $e');
    } finally {
      _isPreloading = false;
    }
  }
  
  /// Stop any ongoing preloading
  static void stopPreloading() {
    _preloadTimer?.cancel();
    _preloadTimer = null;
    _isPreloading = false;
  }
  
  /// Check if currently preloading
  static bool get isPreloading => _isPreloading;
}