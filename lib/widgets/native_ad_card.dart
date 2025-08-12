import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../models/native_ad_model.dart';
import '../services/color_extraction_service.dart';

class NativeAdCard extends StatelessWidget {
  final NativeAdModel adModel;
  final ColorPalette palette;

  const NativeAdCard({
    super.key,
    required this.adModel,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    // Absolute minimal implementation - pure AdWidget only
    if (adModel.isLoaded && adModel.nativeAd != null) {
      return AdWidget(ad: adModel.nativeAd!);
    } else {
      // Minimal loading state
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Container(
          color: palette.primary,
          child: Center(
            child: CupertinoActivityIndicator(
              color: palette.onPrimary,
            ),
          ),
        ),
      );
    }
  }
}