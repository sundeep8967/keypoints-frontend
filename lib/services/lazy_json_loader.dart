import 'dart:convert';
import 'package:flutter/services.dart';
import '../utils/app_logger.dart';

/// Lazy JSON data loader service
/// Loads JSON files only when needed to improve startup performance
class LazyJsonLoader {
  static final Map<String, dynamic> _cache = {};
  
  /// Load JSON data lazily with caching
  static Future<List<dynamic>> loadJsonData(String fileName) async {
    try {
      // Check cache first
      if (_cache.containsKey(fileName)) {
        AppLogger.info('Loading $fileName from cache');
        return _cache[fileName];
      }
      
      // Load from assets
      AppLogger.info('Loading $fileName from assets');
      final String jsonString = await rootBundle.loadString('assets/data/$fileName');
      final List<dynamic> data = json.decode(jsonString);
      
      // Cache for future use
      _cache[fileName] = data;
      
      AppLogger.success('Loaded $fileName: ${data.length} items');
      return data;
      
    } catch (e) {
      AppLogger.error('Failed to load $fileName: $e');
      return [];
    }
  }
  
  /// Preload critical JSON files in background
  static Future<void> preloadCriticalData() async {
    final criticalFiles = [
      'news_top.json',
      'news_trending.json',
    ];
    
    for (final file in criticalFiles) {
      try {
        await loadJsonData(file);
      } catch (e) {
        AppLogger.error('Failed to preload $file: $e');
      }
    }
  }
  
  /// Clear cache to free memory
  static void clearCache() {
    _cache.clear();
    AppLogger.info('JSON cache cleared');
  }
  
  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'cached_files': _cache.keys.length,
      'memory_usage': _cache.toString().length,
    };
  }
}