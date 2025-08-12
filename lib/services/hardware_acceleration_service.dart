import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service to optimize hardware acceleration for native ads and news feed
class HardwareAccelerationService {
  
  /// Enable hardware layer for smooth animations (following Android best practices)
  static void enableHardwareLayerForAnimation(Widget widget) {
    // This is handled automatically by Flutter, but we can optimize specific cases
    // Flutter automatically uses hardware acceleration when available
  }
  
  /// Optimize view layers for native ad animations
  static Widget optimizeForNativeAds(Widget child) {
    return RepaintBoundary(
      // RepaintBoundary creates a separate layer, similar to LAYER_TYPE_HARDWARE
      // This prevents unnecessary repaints of the entire widget tree
      child: child,
    );
  }
  
  /// Optimize alpha animations (following Android documentation)
  static Widget optimizeAlphaAnimation(Widget child) {
    return RepaintBoundary(
      // When applying alpha animations, use RepaintBoundary to create
      // a separate layer that can be efficiently composited
      child: child,
    );
  }
  
  /// Check if hardware acceleration is available
  static bool isHardwareAccelerated() {
    // In Flutter, this is handled automatically
    // Hardware acceleration is used when available
    return true; // Flutter handles this internally
  }
  
  /// Optimize for overdraw reduction (Android best practice)
  static Widget reduceOverdraw(Widget child) {
    return ClipRect(
      // ClipRect helps reduce overdraw by clipping content that's outside bounds
      child: child,
    );
  }
  
  /// Optimize bitmap handling for native ads
  static Widget optimizeBitmapRendering(Widget child) {
    return RepaintBoundary(
      // Separate layer for bitmap-heavy content like ad images
      child: child,
    );
  }
  
  /// Create optimized container for native ads
  static Widget createOptimizedAdContainer({
    required Widget child,
    bool enableRepaintBoundary = true,
    bool clipContent = true,
  }) {
    Widget optimizedChild = child;
    
    // Apply clipping to reduce overdraw
    if (clipContent) {
      optimizedChild = ClipRect(child: optimizedChild);
    }
    
    // Apply repaint boundary for better performance
    if (enableRepaintBoundary) {
      optimizedChild = RepaintBoundary(child: optimizedChild);
    }
    
    return optimizedChild;
  }
  
  /// Optimize animation performance for native ad cards
  static Widget optimizeAdCardAnimation(Widget child) {
    return RepaintBoundary(
      // Create separate layer for ad card animations
      // This prevents the entire news feed from repainting during animations
      child: ClipRect(
        // Clip to reduce overdraw
        child: child,
      ),
    );
  }
  
  /// Performance tips for native ads (based on Android documentation)
  static Map<String, String> getPerformanceTips() {
    return {
      'reduceViews': 'Minimize widget tree depth in ad layouts',
      'avoidOverdraw': 'Use ClipRect and proper opacity handling',
      'cacheImages': 'Use RepaintBoundary for image-heavy ad content',
      'optimizeAlpha': 'Use RepaintBoundary when applying alpha animations',
      'layerManagement': 'Enable hardware layers only during animations',
    };
  }
}