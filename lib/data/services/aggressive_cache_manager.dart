import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// CRITICAL FIX: Aggressive cache manager for instant image loading
/// 30-day cache with 1GB limit to minimize network requests
class AggressiveCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'aggressive_image_cache';
  
  static AggressiveCacheManager? _instance;
  
  factory AggressiveCacheManager() {
    return _instance ??= AggressiveCacheManager._();
  }
  
  AggressiveCacheManager._() : super(
    Config(
      key,
      stalePeriod: const Duration(days: 30), // CRITICAL: 30-day cache
      maxNrOfCacheObjects: 10000, // CRITICAL: Store up to 10,000 images
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}

