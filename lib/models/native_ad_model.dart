import 'package:google_mobile_ads/google_mobile_ads.dart';

class NativeAdModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String advertiser;
  final String callToAction;
  final NativeAd? nativeAd; // Make nullable for fallback ads
  final BannerAd? bannerAd; // Add banner ad for fallback
  final bool isLoaded;
  final bool isBannerFallback; // Flag to indicate if this is a banner fallback

  const NativeAdModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.advertiser,
    required this.callToAction,
    this.nativeAd, // Make optional for fallback ads
    this.bannerAd, // Banner ad for fallback
    this.isLoaded = false,
    this.isBannerFallback = false,
  });

  // Create a copy with updated loading state
  NativeAdModel copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? advertiser,
    String? callToAction,
    NativeAd? nativeAd,
    BannerAd? bannerAd,
    bool? isLoaded,
    bool? isBannerFallback,
  }) {
    return NativeAdModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      advertiser: advertiser ?? this.advertiser,
      callToAction: callToAction ?? this.callToAction,
      nativeAd: nativeAd ?? this.nativeAd,
      bannerAd: bannerAd ?? this.bannerAd,
      isLoaded: isLoaded ?? this.isLoaded,
      isBannerFallback: isBannerFallback ?? this.isBannerFallback,
    );
  }

  // Convert to a format similar to NewsArticle for easy integration
  Map<String, dynamic> toNewsArticleFormat() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'source': advertiser,
      'category': 'Sponsored',
      'isAd': true,
      'callToAction': callToAction,
    };
  }
}