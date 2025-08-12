import 'package:google_mobile_ads/google_mobile_ads.dart';

class NativeAdModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String advertiser;
  final String callToAction;
  final NativeAd nativeAd;
  final bool isLoaded;

  const NativeAdModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.advertiser,
    required this.callToAction,
    required this.nativeAd,
    this.isLoaded = false,
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
    bool? isLoaded,
  }) {
    return NativeAdModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      advertiser: advertiser ?? this.advertiser,
      callToAction: callToAction ?? this.callToAction,
      nativeAd: nativeAd ?? this.nativeAd,
      isLoaded: isLoaded ?? this.isLoaded,
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