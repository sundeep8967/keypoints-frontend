package com.sundeep.keypoints;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin;
import android.os.Bundle;
import android.os.Build;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import android.view.Window;
import android.graphics.Color;

public class MainActivity extends FlutterActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Modern edge-to-edge implementation for Android 15+ compatibility
        Window window = getWindow();
        
        // Enable edge-to-edge display using modern APIs
        WindowCompat.setDecorFitsSystemWindows(window, false);
        
        // Use modern WindowInsetsController instead of deprecated window methods
        WindowInsetsControllerCompat windowInsetsController = 
            WindowCompat.getInsetsController(window, window.getDecorView());
        
        if (windowInsetsController != null) {
            // Set light status bar (dark icons on light background)
            windowInsetsController.setAppearanceLightStatusBars(true);
            // Set light navigation bar (dark icons on light background)
            windowInsetsController.setAppearanceLightNavigationBars(true);
        }
        
        // Set transparent system bars using modern approach
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.setStatusBarColor(Color.TRANSPARENT);
            window.setNavigationBarColor(Color.TRANSPARENT);
            
            // Remove navigation bar divider for modern look
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                window.setNavigationBarDividerColor(Color.TRANSPARENT);
            }
        }
    }

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        // Register the native ad factory for Google Mobile Ads
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine, 
            "newsArticleNativeAd", 
            new NewsArticleNativeAdFactory(getLayoutInflater())
        );
    }
    
    @Override
    public void cleanUpFlutterEngine(FlutterEngine flutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine);
        
        // Unregister the native ad factory
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "newsArticleNativeAd");
    }
}