import Flutter
import UIKit
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register the native ad factory
    let nativeAdFactory = NewsArticleNativeAdFactory()
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      self, 
      factoryId: "newsArticleNativeAd", 
      nativeAdFactory: nativeAdFactory
    )
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
