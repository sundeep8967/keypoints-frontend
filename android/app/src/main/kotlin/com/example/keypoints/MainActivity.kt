package com.example.keypoints

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register the native ad factory
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine, 
            "newsArticleNativeAd", 
            NewsArticleNativeAdFactory(layoutInflater)
        )
    }
    
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        
        // Unregister the native ad factory
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "newsArticleNativeAd")
    }
}