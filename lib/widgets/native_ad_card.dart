import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../models/native_ad_model.dart';
import '../services/hardware_acceleration_service.dart';
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
    // Apply hardware acceleration optimizations for native ads
    return HardwareAccelerationService.createOptimizedAdContainer(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: palette.primary,
        child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 70),
          
          // Image section (same as news articles)
          Container(
            height: MediaQuery.of(context).size.height * 0.3,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.secondary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          // Ad image placeholder or actual ad image
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  palette.secondary,
                                  palette.secondary.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Icon(
                                CupertinoIcons.rectangle_3_offgrid_fill,
                                size: 60,
                                color: palette.onPrimary.withOpacity(0.7),
                              ),
                            ),
                          ),
                          
                          // Native Ad Widget (this will show the actual ad content)
                          // Optimized for hardware acceleration
                          if (adModel.isLoaded)
                            HardwareAccelerationService.optimizeBitmapRendering(
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: AdWidget(ad: adModel.nativeAd),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // "Sponsored" badge (same style as category badge)
                Positioned(
                  top: 15,
                  left: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.9), // Different color for ads
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'SPONSORED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content section (same layout as news articles)
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ad title (same style as news title)
                  Text(
                    adModel.title,
                    style: TextStyle(
                      fontSize: 18, // Same as news articles
                      fontWeight: FontWeight.w700, // Same as news articles
                      color: palette.onPrimary,
                      height: 1.2, // Same as news articles
                      letterSpacing: -0.2, // Same as news articles
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Ad description (same style as news description)
                  Expanded(
                    child: Text(
                      adModel.description,
                      style: TextStyle(
                        fontSize: 16, // Same as news articles
                        color: palette.onPrimary.withOpacity(0.9),
                        height: 1.4, // Same as news articles
                        letterSpacing: 0.1,
                      ),
                      textAlign: TextAlign.justify, // Same justify alignment
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Call-to-action section (same style as news source section)
                  GestureDetector(
                    onTap: () {
                      // Handle ad click
                      print('🔥 NATIVE AD TAPPED!');
                      print('📱 Ad ID: ${adModel.id}');
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            palette.secondary.withOpacity(0.8),
                            palette.secondary.withOpacity(0.6),
                          ],
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  adModel.advertiser,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: palette.onPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  adModel.callToAction.toLowerCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: palette.onPrimary.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                adModel.callToAction,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }
}