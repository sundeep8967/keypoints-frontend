import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';
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

/// Smart Sticky Banner Widget with intelligent loading and user behavior tracking
class SmartStickyBannerWidget extends StatefulWidget {
  final bool showAtBottom;
  final int articlesRead;
  final bool isScrolling;
  final VoidCallback? onAdLoaded;
  final VoidCallback? onAdFailed;

  const SmartStickyBannerWidget({
    Key? key,
    this.showAtBottom = true,
    this.articlesRead = 0,
    this.isScrolling = false,
    this.onAdLoaded,
    this.onAdFailed,
  }) : super(key: key);

  @override
  State<SmartStickyBannerWidget> createState() => _SmartStickyBannerWidgetState();
}

class _SmartStickyBannerWidgetState extends State<SmartStickyBannerWidget> {
  BannerAd? _stickyBannerAd;
  bool _isBannerLoaded = false;
  Timer? _refreshTimer;
  int _impressionCount = 0;
  DateTime? _lastLoadTime;
  
  // Smart banner configuration
  static const Duration _refreshInterval = Duration(minutes: 3);
  static const int _maxImpressionsBeforeRefresh = 8;

  @override
  void initState() {
    super.initState();
    // Only load banner if user has read at least 2 articles
    if (widget.articlesRead >= 2) {
      _loadStickyBanner();
      _startSmartRefresh();
    }
  }

  @override
  void didUpdateWidget(SmartStickyBannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Start loading banner when user reaches 2 articles
    if (oldWidget.articlesRead < 2 && widget.articlesRead >= 2 && !_isBannerLoaded) {
      AppLogger.info('🧠 SMART STICKY: User reached 2 articles, loading banner...');
      _loadStickyBanner();
      _startSmartRefresh();
    }
  }

  void _loadStickyBanner() {
    _stickyBannerAd?.dispose();
    _stickyBannerAd = null;
    _isBannerLoaded = false;

    AppLogger.info('🎯 SMART STICKY: Loading banner...');

    _stickyBannerAd = BannerAd(
      adUnitId: _getStickyBannerAdUnitId(),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isBannerLoaded = true;
              _lastLoadTime = DateTime.now();
              _impressionCount = 0;
            });
            AppLogger.success('✅ SMART STICKY: Banner loaded successfully');
            widget.onAdLoaded?.call();
          }
        },
        onAdFailedToLoad: (ad, error) {
          AppLogger.error('❌ SMART STICKY: Failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _stickyBannerAd = null;
              _isBannerLoaded = false;
            });
            widget.onAdFailed?.call();
          }
        },
        onAdClicked: (ad) {
          AppLogger.log('👆 SMART STICKY: Banner clicked');
          _trackImpression();
        },
        onAdImpression: (ad) {
          AppLogger.log('👁️ SMART STICKY: Banner impression');
          _trackImpression();
        },
      ),
    );

    _stickyBannerAd!.load();
  }

  String _getStickyBannerAdUnitId() {
    const bool isDebug = bool.fromEnvironment('dart.vm.product') == false;
    if (isDebug) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Test banner
    }
    return 'ca-app-pub-1095663786072620/3038197387'; // Production banner
  }

  void _trackImpression() {
    _impressionCount++;
    AppLogger.log('📊 SMART STICKY: Impression count: $_impressionCount');
    
    if (_impressionCount >= _maxImpressionsBeforeRefresh) {
      AppLogger.info('🔄 SMART STICKY: Max impressions reached, refreshing...');
      _loadStickyBanner();
    }
  }

  void _startSmartRefresh() {
    _refreshTimer?.cancel();
    
    _refreshTimer = Timer.periodic(_refreshInterval, (timer) {
      if (mounted && _isBannerLoaded) {
        final timeSinceLoad = DateTime.now().difference(_lastLoadTime ?? DateTime.now());
        
        if (timeSinceLoad >= _refreshInterval) {
          AppLogger.info('🔄 SMART STICKY: Auto-refresh triggered');
          _loadStickyBanner();
        }
      } else if (mounted && !_isBannerLoaded && widget.articlesRead >= 2) {
        AppLogger.info('🔄 SMART STICKY: Banner not loaded, attempting reload...');
        _loadStickyBanner();
      }
    });
  }

  bool _shouldShowBanner() {
    if (!_isBannerLoaded || _stickyBannerAd == null) return false;
    if (widget.articlesRead < 2) return false;
    if (widget.isScrolling) return false; // Hide while scrolling for better UX
    return true;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _stickyBannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowBanner()) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: widget.showAtBottom ? 0 : null,
      top: !widget.showAtBottom ? MediaQuery.of(context).padding.top : null,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, widget.showAtBottom ? -2 : 2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 50,
            alignment: Alignment.center,
            child: AdWidget(ad: _stickyBannerAd!),
          ),
        ),
      ),
    );
  }
}