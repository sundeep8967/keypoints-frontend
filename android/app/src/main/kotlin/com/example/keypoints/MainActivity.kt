package com.example.keypoints

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import android.os.Bundle
import android.os.Build
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import android.view.Window
import android.graphics.Color

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Modern edge-to-edge implementation for Android 15+ compatibility
        val window: Window = getWindow()
        
        // Enable edge-to-edge display using modern APIs
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        // Use modern WindowInsetsController instead of deprecated window methods
        val windowInsetsController = WindowCompat.getInsetsController(window, window.decorView)
        
        windowInsetsController?.let {
            // Set light status bar (dark icons on light background)
            it.isAppearanceLightStatusBars = true
            // Set light navigation bar (dark icons on light background)
            it.isAppearanceLightNavigationBars = true
        }
        
        // Set transparent system bars using modern approach
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.statusBarColor = Color.TRANSPARENT
            window.navigationBarColor = Color.TRANSPARENT
            
            // Remove navigation bar divider for modern look
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                window.navigationBarDividerColor = Color.TRANSPARENT
            }
        }
    }
    
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