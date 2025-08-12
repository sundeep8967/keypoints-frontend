package com.sundeep.keypoints;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import com.chaquo.python.Python;
import com.chaquo.python.android.AndroidPlatform;
import com.chaquo.python.PyObject;
import java.util.List;
import java.util.ArrayList;
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "color_extraction";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        // Register the native ad factory for Google Mobile Ads
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine, 
            "newsArticleNativeAd", 
            new NewsArticleNativeAdFactory(getLayoutInflater())
        );
        
        // Initialize Python
        if (!Python.isStarted()) {
            Python.start(new AndroidPlatform(this));
        }

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    try {
                        Python py = Python.getInstance();
                        PyObject module = py.getModule("color_extraction");

                        switch (call.method) {
                            case "extractDominantColor":
                                String imagePath = call.argument("imagePath");
                                PyObject dominantColor = module.callAttr("extract_dominant_color", imagePath);
                                result.success(dominantColor.toString());
                                break;

                            case "extractColorPalette":
                                String paletteImagePath = call.argument("imagePath");
                                Integer colorCount = call.argument("colorCount");
                                if (colorCount == null) colorCount = 5;
                                
                                PyObject palette = module.callAttr("extract_color_palette", paletteImagePath, colorCount);
                                List<String> colorList = new ArrayList<>();
                                for (PyObject color : palette.asList()) {
                                    colorList.add(color.toString());
                                }
                                result.success(colorList);
                                break;

                            default:
                                result.notImplemented();
                                break;
                        }
                    } catch (Exception e) {
                        result.error("PYTHON_ERROR", "Error executing Python code: " + e.getMessage(), null);
                    }
                });
    }
    
    @Override
    public void cleanUpFlutterEngine(FlutterEngine flutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine);
        
        // Unregister the native ad factory
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "newsArticleNativeAd");
    }
}
