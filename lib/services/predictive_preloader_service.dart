import 'dart:async';
import '../models/news_article.dart';
import 'optimized_image_service.dart';
import 'parallel_color_service.dart';

/// CRITICAL FIX: Predictive preloading based on scroll velocity
/// Preloads more content when user scrolls fast
class PredictivePreloaderService {
  static DateTime _lastScrollTime = DateTime.now();
  static double _lastScrollPosition = 0.0;
  static double _scrollVelocity = 0.0;
  static Timer? _velocityTimer;
  
  /// Update scroll metrics and adjust preloading strategy
  static void updateScrollMetrics(double currentPosition) {
    final now = DateTime.now();
    final timeDiff = now.difference(_lastScrollTime).inMilliseconds;
    
    if (timeDiff > 0) {
      final positionDiff = (currentPosition - _lastScrollPosition).abs();
      _scrollVelocity = positionDiff / timeDiff; // pixels per millisecond
      
      _lastScrollTime = now;
      _lastScrollPosition = currentPosition;
      
      // Reset velocity after 500ms of no updates
      _velocityTimer?.cancel();
      _velocityTimer = Timer(const Duration(milliseconds: 500), () {
        _scrollVelocity = 0.0;
      });
    }
  }
  
  /// Get dynamic preload count based on scroll velocity
  static int getDynamicPreloadCount() {
    if (_scrollVelocity > 2.0) {
      return 25; // Very fast scrolling - preload 25 images
    } else if (_scrollVelocity > 1.0) {
      return 20; // Fast scrolling - preload 20 images
    } else if (_scrollVelocity > 0.5) {
      return 15; // Medium scrolling - preload 15 images
    } else {
      return 10; // Slow/no scrolling - preload 10 images
    }
  }
  
  /// Predictive preloading with velocity-based strategy
  static Future<void> predictivePreload(
    List<NewsArticle> articles,
    int currentIndex,
  ) async {
    final preloadCount = getDynamicPreloadCount();
    
    print('🚀 PREDICTIVE PRELOAD: Velocity=${_scrollVelocity.toStringAsFixed(3)}, Count=$preloadCount');
    
    // Preload images aggressively
    await OptimizedImageService.preloadImagesAggressively(
      articles, 
      currentIndex, 
      preloadCount: preloadCount,
    );
    
    // Preload colors in parallel
    ParallelColorService.preloadColorsParallel(
      articles, 
      currentIndex + 1, 
      colorPreloadCount: preloadCount,
    );
  }
  
  /// Instant cache warming for category selection
  static Future<void> warmCategoryCache(List<NewsArticle> articles) async {
    if (articles.isEmpty) return;
    
    print('🔥 CACHE WARMING: Preloading ${articles.length.clamp(0, 20)} articles');
    
    // Preload first 20 images immediately
    final imagesToWarm = articles.take(20).toList();
    
    // Preload first image with highest priority
    if (imagesToWarm.isNotEmpty) {
      await OptimizedImageService.preloadImagesAggressively(
        imagesToWarm, 
        0, 
        preloadCount: 1,
      );
    }
    
    // Preload rest in background
    if (imagesToWarm.length > 1) {
      OptimizedImageService.preloadImagesAggressively(
        imagesToWarm, 
        1, 
        preloadCount: imagesToWarm.length - 1,
      );
    }
    
    // Preload colors for first 15 articles
    ParallelColorService.preloadColorsParallel(
      imagesToWarm, 
      0, 
      colorPreloadCount: 15,
    );
  }
  
  /// Get current scroll velocity for debugging
  static double getCurrentVelocity() => _scrollVelocity;
  
  /// Reset velocity tracking
  static void resetVelocity() {
    _scrollVelocity = 0.0;
    _velocityTimer?.cancel();
  }
}