package com.example.keypoints

import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

class NewsArticleNativeAdFactory(private val layoutInflater: LayoutInflater) : NativeAdFactory {
    
    override fun createNativeAd(nativeAd: NativeAd, customOptions: MutableMap<String, Any>?): NativeAdView {
        // Create a simple native ad view that matches your news article layout
        val context = layoutInflater.context
        val packageName = context.packageName
        val layoutId = context.resources.getIdentifier("native_ad_news_article", "layout", packageName)
        val adView = layoutInflater.inflate(layoutId, null) as NativeAdView
        
        // Get references to the views
        val headlineView = adView.findViewById<TextView>(context.resources.getIdentifier("ad_headline", "id", packageName))
        val bodyView = adView.findViewById<TextView>(context.resources.getIdentifier("ad_body", "id", packageName))
        val iconView = adView.findViewById<ImageView>(context.resources.getIdentifier("ad_icon", "id", packageName))
        val mediaView = adView.findViewById<com.google.android.gms.ads.nativead.MediaView>(context.resources.getIdentifier("ad_media", "id", packageName))
        val callToActionView = adView.findViewById<Button>(context.resources.getIdentifier("ad_call_to_action", "id", packageName))
        val advertiserView = adView.findViewById<TextView>(context.resources.getIdentifier("ad_advertiser", "id", packageName))
        
        // Populate the views with ad content
        headlineView?.text = nativeAd.headline
        bodyView?.text = nativeAd.body
        callToActionView?.text = nativeAd.callToAction
        advertiserView?.text = nativeAd.advertiser
        
        // Set the icon
        if (nativeAd.icon != null) {
            iconView?.setImageDrawable(nativeAd.icon?.drawable)
            iconView?.visibility = View.VISIBLE
        } else {
            iconView?.visibility = View.GONE
        }
        
        // Set the media content
        mediaView?.setMediaContent(nativeAd.mediaContent)
        
        // Register the views with the native ad
        adView.headlineView = headlineView
        adView.bodyView = bodyView
        adView.iconView = iconView
        adView.mediaView = mediaView
        adView.callToActionView = callToActionView
        adView.advertiserView = advertiserView
        
        // Set the native ad
        adView.setNativeAd(nativeAd)
        
        return adView
    }
}