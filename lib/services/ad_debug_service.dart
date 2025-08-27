import 'admob_service.dart';

import '../utils/app_logger.dart';
/// Debug service for troubleshooting native ad issues
class AdDebugService {
  
  /// Print comprehensive ad debugging information
  static void printDebugInfo() {
    AppLogger.debug(' INFORMATION =====');
    
    final info = AdMobService.getTroubleshootingInfo();
    
    AppLogger.info(' AdMob Status:');
    AppLogger.log('   - Initialized: ${info['isInitialized']}');
    AppLogger.log('   - Ad Unit ID: ${info['adUnitId']}');
    AppLogger.log('   - Using Test Ads: ${info['isTestAdUnit']}');
    AppLogger.log('   - Loaded Ads Count: ${info['loadedAdsCount']}');
    AppLogger.log('   - Ad Counter: ${info['adCounter']}');
    AppLogger.log('   - Cache Expired: ${info['cacheExpired']}');
    AppLogger.log('   - Last Cache Time: ${info['lastCacheTime'] ?? 'Never'}');
    
    AppLogger.log('\n💡 Troubleshooting Tips:');
    final tips = info['troubleshootingTips'] as List<String>;
    for (int i = 0; i < tips.length; i++) {
      AppLogger.log('   ${i + 1}. ${tips[i]}');
    }
    
    AppLogger.log('\n📊 Performance Stats:');
    final stats = AdMobService.getAdLoadingStats();
    AppLogger.log('   - Total Loaded Ads: ${stats['totalLoadedAds']}');
    AppLogger.log('   - Cache Status: ${stats['cacheExpired'] ? 'EXPIRED' : 'VALID'}');
    
    AppLogger.log('\n🎯 Current Issue Analysis:');
    if (info['isTestAdUnit'] == true) {
      AppLogger.log('   ✅ Using test ad unit (should work in all environments)');
    } else {
      AppLogger.log('   ⚠️  Using production ad unit (may not work in test environments)');
    }
    
    if (info['loadedAdsCount'] == 0) {
      AppLogger.log('   ❌ No ads currently loaded');
      AppLogger.log('   💡 This could be due to:');
      AppLogger.log('      - Network connectivity issues');
      AppLogger.log('      - AdMob server unavailability');
      AppLogger.log('      - Emulator limitations');
      AppLogger.log('      - Ad inventory shortage');
    } else {
      AppLogger.log('   ✅ ${info['loadedAdsCount']} ads successfully loaded');
    }
    
    AppLogger.log('================================\n');
  }
  
  /// Test ad loading with detailed logging
  static Future<void> testAdLoading() async {
    AppLogger.log('🧪 Starting ad loading test...');
    
    printDebugInfo();
    
    AppLogger.info(' Attempting to load a single test ad...');
    final ad = await AdMobService.createNativeAd();
    
    if (ad != null) {
      AppLogger.success(' Test ad loaded successfully!');
      AppLogger.log('   - Ad ID: ${ad.id}');
      AppLogger.log('   - Title: ${ad.title}');
      AppLogger.log('   - Advertiser: ${ad.advertiser}');
    } else {
      AppLogger.error(' Test ad failed to load');
      AppLogger.log('💡 Recommendations:');
      AppLogger.log('   1. Check internet connection');
      AppLogger.log('   2. Try running on a physical device instead of emulator');
      AppLogger.log('   3. Verify AdMob configuration');
      AppLogger.log('   4. Check if ads are available in your region');
    }
    
    AppLogger.log('🧪 Ad loading test completed.\n');
  }
  
  /// Check if the current environment supports ads
  static Map<String, dynamic> checkEnvironment() {
    return {
      'isEmulator': _isEmulator(),
      'hasInternet': true, // Would need connectivity check
      'adMobConfigured': _checkAdMobConfig(),
      'recommendations': _getEnvironmentRecommendations(),
    };
  }
  
  static bool _isEmulator() {
    // Simple check - in a real app you'd use a more robust method
    return true; // Assume emulator for now
  }
  
  static bool _checkAdMobConfig() {
    final info = AdMobService.getTroubleshootingInfo();
    return info['isInitialized'] == true && info['adUnitId'] != null;
  }
  
  static List<String> _getEnvironmentRecommendations() {
    final recommendations = <String>[];
    
    if (_isEmulator()) {
      recommendations.add('Test on a physical device for better ad loading');
      recommendations.add('Emulators may have limited ad inventory');
    }
    
    if (!_checkAdMobConfig()) {
      recommendations.add('Verify AdMob initialization and configuration');
    }
    
    recommendations.add('Ensure stable internet connection');
    recommendations.add('Check AdMob dashboard for any account issues');
    
    return recommendations;
  }
}