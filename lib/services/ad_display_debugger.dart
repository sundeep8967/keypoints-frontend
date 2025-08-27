import '../models/news_article.dart';
import '../models/native_ad_model.dart';
import 'ad_integration_service.dart';
import 'admob_service.dart';
import '../utils/app_logger.dart';

/// Comprehensive ad display debugging service
class AdDisplayDebugger {
  static bool _debugMode = true;
  
  /// Enable/disable debug mode
  static void setDebugMode(bool enabled) {
    _debugMode = enabled;
    AppLogger.log('🐛 AD DEBUG MODE: ${enabled ? "ENABLED" : "DISABLED"}');
  }
  
  /// Debug the entire ad integration process
  static Future<void> debugAdIntegration(List<NewsArticle> articles, String category) async {
    if (!_debugMode) return;
    
    AppLogger.log('');
    AppLogger.log('🔍 ===== AD INTEGRATION DEBUG REPORT =====');
    AppLogger.log('📊 Category: $category');
    AppLogger.log('📰 Articles count: ${articles.length}');
    AppLogger.log('');
    
    // Step 1: Check AdMob service status
    await _debugAdMobService();
    
    // Step 2: Check ad positioning logic
    _debugAdPositioning(articles.length);
    
    // Step 3: Test ad creation
    await _debugAdCreation();
    
    // Step 4: Test full integration
    await _debugFullIntegration(articles, category);
    
    AppLogger.log('🔍 ===== END AD DEBUG REPORT =====');
    AppLogger.log('');
  }
  
  /// Debug AdMob service initialization and status
  static Future<void> _debugAdMobService() async {
    AppLogger.log('🔧 STEP 1: AdMob Service Status');
    
    final stats = AdMobService.getAdLoadingStats();
    AppLogger.log('  📊 Initialization: ${stats['isInitialized']}');
    AppLogger.log('  📊 Loaded ads: ${stats['totalLoadedAds']}');
    AppLogger.log('  📊 Ad counter: ${stats['adCounter']}');
    AppLogger.log('  📊 Cache expired: ${stats['cacheExpired']}');
    AppLogger.log('  📊 Last cache: ${stats['lastCacheTime'] ?? "Never"}');
    
    final troubleshooting = AdMobService.getTroubleshootingInfo();
    AppLogger.log('  🔧 Ad Unit ID: ${troubleshooting['adUnitId']}');
    AppLogger.log('  🔧 Is test unit: ${troubleshooting['isTestAdUnit']}');
    AppLogger.log('');
  }
  
  /// Debug ad positioning calculations
  static void _debugAdPositioning(int articleCount) {
    AppLogger.log('📍 STEP 2: Ad Positioning Logic');
    
    // Test old positioning
    final oldPositions = AdMobService.getAdPositions(articleCount);
    AppLogger.log('  📊 Old positions (every 5th): $oldPositions');
    
    // Test new positioning
    final newPositions = _calculateOptimalAdPositions(articleCount);
    AppLogger.log('  📊 New positions (optimal): $newPositions');
    
    // Calculate dynamic max ads
    final dynamicMaxAds = (articleCount / 5).ceil().clamp(3, 15);
    AppLogger.log('  📊 Dynamic max ads: $dynamicMaxAds');
    AppLogger.log('  📊 Actual ads needed: ${newPositions.length.clamp(0, dynamicMaxAds)}');
    AppLogger.log('');
  }
  
  /// Test ad creation process
  static Future<void> _debugAdCreation() async {
    AppLogger.log('🏭 STEP 3: Ad Creation Test');
    
    try {
      AppLogger.log('  🔄 Attempting to create single test ad...');
      final testAd = await AdMobService.createNativeAd();
      
      if (testAd != null) {
        AppLogger.success('  ✅ Test ad created successfully!');
        AppLogger.log('    📊 ID: ${testAd.id}');
        AppLogger.log('    📊 Title: ${testAd.title}');
        AppLogger.log('    📊 Loaded: ${testAd.isLoaded}');
        AppLogger.log('    📊 Has native ad: ${testAd.nativeAd != null}');
      } else {
        AppLogger.error('  ❌ Test ad creation failed!');
        AppLogger.log('  💡 This could be due to:');
        AppLogger.log('    - Network connectivity issues');
        AppLogger.log('    - AdMob configuration problems');
        AppLogger.log('    - Running in emulator (ads may not load)');
        AppLogger.log('    - Ad inventory temporarily unavailable');
      }
    } catch (e) {
      AppLogger.error('  ❌ Exception during ad creation: $e');
    }
    AppLogger.log('');
  }
  
  /// Test full ad integration process
  static Future<void> _debugFullIntegration(List<NewsArticle> articles, String category) async {
    AppLogger.log('🔗 STEP 4: Full Integration Test');
    
    try {
      AppLogger.log('  🔄 Testing full ad integration...');
      
      final dynamicMaxAds = (articles.length / 5).ceil().clamp(3, 15);
      AppLogger.log('  📊 Requesting $dynamicMaxAds ads for ${articles.length} articles');
      
      final mixedFeed = await AdIntegrationService.integrateAdsIntoFeed(
        articles: articles,
        category: category,
        maxAds: dynamicMaxAds,
      );
      
      AppLogger.log('  📊 Mixed feed created: ${mixedFeed.length} items');
      
      // Analyze the mixed feed
      int articleCount = 0;
      int adCount = 0;
      final adPositions = <int>[];
      
      for (int i = 0; i < mixedFeed.length; i++) {
        if (AdIntegrationService.isAd(mixedFeed[i])) {
          adCount++;
          adPositions.add(i);
        } else if (AdIntegrationService.isNewsArticle(mixedFeed[i])) {
          articleCount++;
        }
      }
      
      AppLogger.log('  📊 Final breakdown:');
      AppLogger.log('    📰 Articles: $articleCount');
      AppLogger.log('    📺 Ads: $adCount');
      AppLogger.log('    📍 Ad positions: $adPositions');
      
      if (adCount == 0) {
        AppLogger.error('  ❌ NO ADS IN MIXED FEED!');
        AppLogger.log('  🔍 Possible causes:');
        AppLogger.log('    - Ad creation is failing');
        AppLogger.log('    - Ad positioning logic is broken');
        AppLogger.log('    - Integration service has bugs');
      } else {
        AppLogger.success('  ✅ Ads successfully integrated into feed!');
        
        // Check ad spacing
        if (adPositions.length > 1) {
          final spacings = <int>[];
          for (int i = 1; i < adPositions.length; i++) {
            spacings.add(adPositions[i] - adPositions[i-1]);
          }
          AppLogger.log('    📊 Ad spacing: $spacings');
        }
      }
      
    } catch (e) {
      AppLogger.error('  ❌ Integration test failed: $e');
    }
    AppLogger.log('');
  }
  
  /// Debug individual ad display
  static void debugAdDisplay(dynamic item, int index) {
    if (!_debugMode) return;
    
    if (AdIntegrationService.isAd(item)) {
      final adModel = item as NativeAdModel;
      AppLogger.log('📺 AD DISPLAY DEBUG at index $index:');
      AppLogger.log('  📊 ID: ${adModel.id}');
      AppLogger.log('  📊 Title: ${adModel.title}');
      AppLogger.log('  📊 Loaded: ${adModel.isLoaded}');
      AppLogger.log('  📊 Has native ad: ${adModel.nativeAd != null}');
      AppLogger.log('  📊 Will show: ${adModel.isLoaded && adModel.nativeAd != null ? "Real AdWidget" : "Custom UI"}');
    }
  }
  
  /// Copy of the optimal positioning logic for debugging
  static List<int> _calculateOptimalAdPositions(int articleCount) {
    if (articleCount <= 3) return [];
    
    final positions = <int>[];
    int nextAdPosition = 3;
    
    while (nextAdPosition < articleCount - 1) {
      positions.add(nextAdPosition);
      final spacing = 4 + (positions.length % 3);
      nextAdPosition += spacing;
    }
    
    return positions;
  }
  
  /// Get comprehensive debug summary
  static Future<Map<String, dynamic>> getDebugSummary() async {
    final adMobStats = AdMobService.getAdLoadingStats();
    final adIntegrationStats = AdIntegrationService.getAdStats();
    
    return {
      'debugMode': _debugMode,
      'adMobService': adMobStats,
      'adIntegration': adIntegrationStats,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  /// Quick ad test - creates and displays a single ad
  static Future<bool> quickAdTest() async {
    AppLogger.log('🚀 QUICK AD TEST');
    
    try {
      final testAd = await AdMobService.createNativeAd();
      if (testAd != null) {
        AppLogger.success('✅ Quick test PASSED - Ad created successfully');
        return true;
      } else {
        AppLogger.error('❌ Quick test FAILED - No ad created');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ Quick test ERROR: $e');
      return false;
    }
  }
}