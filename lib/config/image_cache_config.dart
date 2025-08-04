import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ImageCacheConfig {
  static void initialize() {
    // Configure global cache manager for better performance
    DefaultCacheManager().emptyCache(); // Clear any old cache
    
    // Set up optimized cache manager
    final cacheManager = CacheManager(
      Config(
        'optimized_image_cache',
        stalePeriod: const Duration(days: 7), // Keep images for 7 days
        maxNrOfCacheObjects: 200, // Increase cache size
        repo: JsonCacheInfoRepository(databaseName: 'optimized_image_cache'),
        fileService: HttpFileService(),
      ),
    );
    
    // Configure CachedNetworkImage defaults
    CachedNetworkImage.logLevel = CacheManagerLogLevel.none; // Disable logs for performance
  }
  
  static CacheManager getOptimizedCacheManager() {
    return CacheManager(
      Config(
        'news_images',
        stalePeriod: const Duration(days: 7),
        maxNrOfCacheObjects: 200,
        repo: JsonCacheInfoRepository(databaseName: 'news_images'),
        fileService: HttpFileService(),
      ),
    );
  }
}