import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import '../models/news_article.dart';
import '../services/color_extraction_service.dart';

/// OPTIMIZATION 3: Parallel color extraction without blocking images
class ParallelColorService {
  static final Map<String, ColorPalette> _colorCache = {};
  static final Map<String, bool> _colorExtractionInProgress = {};
  static final Map<String, Completer<ColorPalette>> _colorCompleters = {};
  
  // Background isolate for color extraction
  static Isolate? _colorExtractionIsolate;
  static SendPort? _colorExtractionSendPort;
  
  /// Initialize parallel color extraction
  static Future<void> initializeParallelColorExtraction() async {
    try {
      final receivePort = ReceivePort();
      _colorExtractionIsolate = await Isolate.spawn(
        _colorExtractionIsolateEntry,
        receivePort.sendPort,
      );
      
      final completer = Completer<SendPort>();
      receivePort.listen((data) {
        if (data is SendPort) {
          _colorExtractionSendPort = data;
          completer.complete(data);
        } else if (data is Map<String, dynamic>) {
          _handleColorExtractionResult(data);
        }
      });
      
      await completer.future;
    } catch (e) {
      // Fallback to main thread if isolate fails
      _colorExtractionSendPort = null;
    }
  }
  
  /// Background isolate entry point for color extraction
  static void _colorExtractionIsolateEntry(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    
    receivePort.listen((data) async {
      if (data is Map<String, dynamic>) {
        final imageUrl = data['imageUrl'] as String;
        try {
          // Extract colors in background thread
          final palette = await ColorExtractionService.extractColorsFromImage(imageUrl);
          sendPort.send({
            'imageUrl': imageUrl,
            'success': true,
            'palette': {
              'primary': palette.primary.value,
              'secondary': palette.secondary.value,
              'accent': palette.accent.value,
              'background': palette.background.value,
              'surface': palette.surface.value,
              'onPrimary': palette.onPrimary.value,
              'onSecondary': palette.onSecondary.value,
              'onAccent': palette.onAccent.value,
            },
          });
        } catch (e) {
          sendPort.send({
            'imageUrl': imageUrl,
            'success': false,
            'error': e.toString(),
          });
        }
      }
    });
  }
  
  /// Handle color extraction results from background isolate
  static void _handleColorExtractionResult(Map<String, dynamic> data) {
    final imageUrl = data['imageUrl'] as String;
    final success = data['success'] as bool;
    
    if (success) {
      final paletteData = data['palette'] as Map<String, dynamic>;
      final palette = ColorPalette(
        primary: Color(paletteData['primary'] as int),
        secondary: Color(paletteData['secondary'] as int),
        accent: Color(paletteData['accent'] as int),
        background: Color(paletteData['background'] as int),
        surface: Color(paletteData['surface'] as int),
        onPrimary: Color(paletteData['onPrimary'] as int),
        onSecondary: Color(paletteData['onSecondary'] as int),
        onAccent: Color(paletteData['onAccent'] as int),
      );
      
      _colorCache[imageUrl] = palette;
      
      // Complete any waiting futures
      if (_colorCompleters.containsKey(imageUrl)) {
        _colorCompleters[imageUrl]!.complete(palette);
        _colorCompleters.remove(imageUrl);
      }
    } else {
      final defaultPalette = ColorPalette.defaultPalette();
      _colorCache[imageUrl] = defaultPalette;
      
      if (_colorCompleters.containsKey(imageUrl)) {
        _colorCompleters[imageUrl]!.complete(defaultPalette);
        _colorCompleters.remove(imageUrl);
      }
    }
    
    _colorExtractionInProgress[imageUrl] = false;
  }
  
  /// Extract colors in parallel without blocking image loading
  static Future<ColorPalette> extractColorsParallel(String imageUrl) async {
    // Return cached color immediately if available
    if (_colorCache.containsKey(imageUrl)) {
      return _colorCache[imageUrl]!;
    }
    
    // Return existing completer if extraction is in progress
    if (_colorCompleters.containsKey(imageUrl)) {
      return _colorCompleters[imageUrl]!.future;
    }
    
    // Start new color extraction
    if (!_colorExtractionInProgress.containsKey(imageUrl)) {
      _colorExtractionInProgress[imageUrl] = true;
      final completer = Completer<ColorPalette>();
      _colorCompleters[imageUrl] = completer;
      
      if (_colorExtractionSendPort != null) {
        // Extract in background isolate
        _colorExtractionSendPort!.send({
          'imageUrl': imageUrl,
        });
      } else {
        // Fallback to main thread
        _extractColorMainThread(imageUrl);
      }
      
      return completer.future;
    }
    
    // Return default palette if something goes wrong
    return ColorPalette.defaultPalette();
  }
  
  /// Fallback color extraction on main thread
  static Future<void> _extractColorMainThread(String imageUrl) async {
    try {
      final palette = await ColorExtractionService.extractColorsFromImage(imageUrl);
      _colorCache[imageUrl] = palette;
      
      if (_colorCompleters.containsKey(imageUrl)) {
        _colorCompleters[imageUrl]!.complete(palette);
        _colorCompleters.remove(imageUrl);
      }
    } catch (e) {
      final defaultPalette = ColorPalette.defaultPalette();
      _colorCache[imageUrl] = defaultPalette;
      
      if (_colorCompleters.containsKey(imageUrl)) {
        _colorCompleters[imageUrl]!.complete(defaultPalette);
        _colorCompleters.remove(imageUrl);
      }
    } finally {
      _colorExtractionInProgress[imageUrl] = false;
    }
  }
  
  /// Preload colors for multiple articles in parallel
  static Future<void> preloadColorsParallel(
    List<NewsArticle> articles,
    int startIndex, {
    int colorPreloadCount = 10,
  }) async {
    final endIndex = (startIndex + colorPreloadCount).clamp(0, articles.length);
    final colorFutures = <Future<ColorPalette>>[];
    
    for (int i = startIndex; i < endIndex; i++) {
      if (i < articles.length) {
        final imageUrl = articles[i].imageUrl;
        if (!_colorCache.containsKey(imageUrl)) {
          colorFutures.add(extractColorsParallel(imageUrl));
        }
      }
    }
    
    // Execute all color extractions in parallel
    Future.wait(colorFutures).catchError((e) {
      // Handle errors silently
      return <ColorPalette>[];
    });
  }
  
  /// Get cached color or default immediately
  static ColorPalette getCachedColorOrDefault(String imageUrl) {
    return _colorCache[imageUrl] ?? ColorPalette.defaultPalette();
  }
  
  /// Check if color is cached
  static bool isColorCached(String imageUrl) {
    return _colorCache.containsKey(imageUrl);
  }
  
  /// Clear color cache
  static void clearColorCache() {
    _colorCache.clear();
    _colorExtractionInProgress.clear();
    _colorCompleters.clear();
  }
  
  /// Get color cache statistics
  static Map<String, int> getColorCacheStats() {
    return {
      'cached_colors': _colorCache.length,
      'in_progress': _colorExtractionInProgress.values.where((v) => v == true).length,
      'pending_completers': _colorCompleters.length,
    };
  }
  
  /// Dispose resources
  static void dispose() {
    _colorExtractionIsolate?.kill();
    _colorExtractionIsolate = null;
    _colorExtractionSendPort = null;
    clearColorCache();
  }
}