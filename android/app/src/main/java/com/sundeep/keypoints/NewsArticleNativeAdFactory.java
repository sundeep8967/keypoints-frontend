package com.sundeep.keypoints;

import android.view.LayoutInflater;
import android.view.View;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.TextView;
import com.google.android.gms.ads.nativead.NativeAd;
import com.google.android.gms.ads.nativead.NativeAdView;
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory;
import java.util.Map;

public class NewsArticleNativeAdFactory implements NativeAdFactory {
    private final LayoutInflater layoutInflater;

    public NewsArticleNativeAdFactory(LayoutInflater layoutInflater) {
        this.layoutInflater = layoutInflater;
    }

    @Override
    public NativeAdView createNativeAd(NativeAd nativeAd, Map<String, Object> customOptions) {
        // Inflate the native ad layout
        NativeAdView adView = (NativeAdView) layoutInflater.inflate(R.layout.native_ad_news_article, null);

        // Set up the ad view components
        TextView headlineView = adView.findViewById(R.id.ad_headline);
        TextView bodyView = adView.findViewById(R.id.ad_body);
        TextView advertiserView = adView.findViewById(R.id.ad_advertiser);
        Button callToActionView = adView.findViewById(R.id.ad_call_to_action);
        ImageView iconView = adView.findViewById(R.id.ad_icon);
        com.google.android.gms.ads.nativead.MediaView mediaView = adView.findViewById(R.id.ad_media);

        // Populate the ad view with native ad content
        if (nativeAd.getHeadline() != null) {
            headlineView.setText(nativeAd.getHeadline());
        }
        
        if (nativeAd.getBody() != null) {
            bodyView.setText(nativeAd.getBody());
        }
        
        if (nativeAd.getAdvertiser() != null) {
            advertiserView.setText(nativeAd.getAdvertiser());
        }
        
        if (nativeAd.getCallToAction() != null) {
            callToActionView.setText(nativeAd.getCallToAction());
        }
        
        if (nativeAd.getIcon() != null) {
            iconView.setImageDrawable(nativeAd.getIcon().getDrawable());
        }

        // Register the view components with the native ad view
        adView.setHeadlineView(headlineView);
        adView.setBodyView(bodyView);
        adView.setAdvertiserView(advertiserView);
        adView.setCallToActionView(callToActionView);
        adView.setIconView(iconView);
        adView.setMediaView(mediaView);

        // Set the native ad
        adView.setNativeAd(nativeAd);

        return adView;
    }
}