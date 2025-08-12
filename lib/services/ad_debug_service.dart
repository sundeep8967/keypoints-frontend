import 'admob_service.dart';

/// Debug service for troubleshooting native ad issues
class AdDebugService {
  
  /// Print comprehensive ad debugging information
  static void printDebugInfo() {
    print('\n🔍 ===== AD DEBUG INFORMATION =====');
    
    final info = AdMobService.getTroubleshootingInfo();
    
    print('📱 AdMob Status:');
    print('   - Initialized: ${info['isInitialized']}');
    print('   - Ad Unit ID: ${info['adUnitId']}');
    print('   - Using Test Ads: ${info['isTestAdUnit']}');
    print('   - Loaded Ads Count: ${info['loadedAdsCount']}');
    print('   - Ad Counter: ${info['adCounter']}');
    print('   - Cache Expired: ${info['cacheExpired']}');
    print('   - Last Cache Time: ${info['lastCacheTime'] ?? 'Never'}');
    
    print('\n💡 Troubleshooting Tips:');
    final tips = info['troubleshootingTips'] as List<String>;
    for (int i = 0; i < tips.length; i++) {
      print('   ${i + 1}. ${tips[i]}');
    }
    
    print('\n📊 Performance Stats:');
    final stats = AdMobService.getAdLoadingStats();
    print('   - Total Loaded Ads: ${stats['totalLoadedAds']}');
    print('   - Cache Status: ${stats['cacheExpired'] ? 'EXPIRED' : 'VALID'}');
    
    print('\n🎯 Current Issue Analysis:');
    if (info['isTestAdUnit'] == true) {
      print('   ✅ Using test ad unit (should work in all environments)');
    } else {
      print('   ⚠️  Using production ad unit (may not work in test environments)');
    }
    
    if (info['loadedAdsCount'] == 0) {
      print('   ❌ No ads currently loaded');
      print('   💡 This could be due to:');
      print('      - Network connectivity issues');
      print('      - AdMob server unavailability');
      print('      - Emulator limitations');
      print('      - Ad inventory shortage');
    } else {
      print('   ✅ ${info['loadedAdsCount']} ads successfully loaded');
    }
    
    print('================================\n');
  }
  
  /// Test ad loading with detailed logging
  static Future<void> testAdLoading() async {
    print('🧪 Starting ad loading test...');
    
    printDebugInfo();
    
    print('🔄 Attempting to load a single test ad...');
    final ad = await AdMobService.createNativeAd();
    
    if (ad != null) {
      print('✅ Test ad loaded successfully!');
      print('   - Ad ID: ${ad.id}');
      print('   - Title: ${ad.title}');
      print('   - Advertiser: ${ad.advertiser}');
    } else {
      print('❌ Test ad failed to load');
      print('💡 Recommendations:');
      print('   1. Check internet connection');
      print('   2. Try running on a physical device instead of emulator');
      print('   3. Verify AdMob configuration');
      print('   4. Check if ads are available in your region');
    }
    
    print('🧪 Ad loading test completed.\n');
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