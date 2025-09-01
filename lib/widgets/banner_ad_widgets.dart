import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/color_extraction_service.dart';
import '../utils/app_logger.dart';

/// Standard Banner Ad Widget using your production banner ad unit ID
class StandardBannerAdWidget extends StatefulWidget {
  final ColorPalette? palette;
  final EdgeInsets margin;

  const StandardBannerAdWidget({
    super.key,
    this.palette,
    this.margin = const EdgeInsets.symmetric(vertical: 8.0),
  });

  @override
  State<StandardBannerAdWidget> createState() => _StandardBannerAdWidgetState();
}

class _StandardBannerAdWidgetState extends State<StandardBannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoading = true;
  bool _hasError = false;

  // Your production banner ad unit ID
  static const String _bannerAdUnitId = 'ca-app-pub-1095663786072620/3038197387';
  // Test banner ad unit ID for debug mode
  static const String _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  Future<void> _loadBannerAd() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Use test ads in debug mode, production ads in release mode
      final adUnitId = const bool.fromEnvironment('dart.vm.product') 
          ? _bannerAdUnitId 
          : _testBannerAdUnitId;

      AppLogger.log('🎯 Loading banner ad with unit ID: $adUnitId');

      _bannerAd = BannerAd(
        adUnitId: adUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            AppLogger.success('✅ Banner ad loaded successfully');
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = false;
              });
            }
          },
          onAdFailedToLoad: (ad, error) {
            AppLogger.error('❌ Banner ad failed to load: $error');
            ad.dispose();
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
          onAdOpened: (ad) {
            AppLogger.log('👆 Banner ad opened');
          },
          onAdClosed: (ad) {
            AppLogger.log('🔒 Banner ad closed');
          },
          onAdClicked: (ad) {
            AppLogger.log('🖱️ Banner ad clicked');
          },
          onAdImpression: (ad) {
            AppLogger.log('👁️ Banner ad impression recorded');
          },
        ),
      );

      await _bannerAd!.load();
    } catch (e) {
      AppLogger.error('❌ Error creating banner ad: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette ?? ColorPalette.defaultPalette();
    
    return Container(
      margin: widget.margin,
      child: _buildAdContent(palette),
    );
  }

  Widget _buildAdContent(ColorPalette palette) {
    if (_isLoading) {
      return _buildLoadingIndicator(palette);
    }

    if (_hasError || _bannerAd == null) {
      return _buildErrorPlaceholder(palette);
    }

    return _buildBannerAd();
  }

  Widget _buildLoadingIndicator(ColorPalette palette) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.primary.withOpacity(0.3)),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading ad...',
              style: TextStyle(
                color: palette.onPrimary.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(ColorPalette palette) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.primary.withOpacity(0.2)),
      ),
      child: Center(
        child: Text(
          'Ad space',
          style: TextStyle(
            color: palette.onPrimary.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildBannerAd() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        ),
      ),
    );
  }
}

/// Sticky Bottom Banner Widget
class StickyBottomBannerWidget extends StatefulWidget {
  final ColorPalette? palette;

  const StickyBottomBannerWidget({
    super.key,
    this.palette,
  });

  @override
  State<StickyBottomBannerWidget> createState() => _StickyBottomBannerWidgetState();
}

class _StickyBottomBannerWidgetState extends State<StickyBottomBannerWidget> {
  BannerAd? _bannerAd;
  bool _isVisible = true;
  bool _isLoading = true;

  // Your production banner ad unit ID
  static const String _bannerAdUnitId = 'ca-app-pub-1095663786072620/3038197387';
  // Test banner ad unit ID for debug mode
  static const String _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  @override
  void initState() {
    super.initState();
    _loadStickyBanner();
  }

  Future<void> _loadStickyBanner() async {
    try {
      // Use test ads in debug mode, production ads in release mode
      final adUnitId = const bool.fromEnvironment('dart.vm.product') 
          ? _bannerAdUnitId 
          : _testBannerAdUnitId;

      AppLogger.log('🎯 Loading sticky banner ad with unit ID: $adUnitId');

      _bannerAd = BannerAd(
        adUnitId: adUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            AppLogger.success('✅ Sticky banner ad loaded successfully');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onAdFailedToLoad: (ad, error) {
            AppLogger.error('❌ Sticky banner ad failed to load: $error');
            ad.dispose();
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isVisible = false;
              });
            }
          },
        ),
      );

      await _bannerAd!.load();
    } catch (e) {
      AppLogger.error('❌ Error creating sticky banner ad: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isVisible = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return Container(
        height: 60,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_bannerAd == null) {
      return const SizedBox.shrink();
    }

    final palette = widget.palette ?? ColorPalette.defaultPalette();

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        boxShadow: [
          BoxShadow(
            color: palette.primary.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: palette.onPrimary.withOpacity(0.7),
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isVisible = false;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}