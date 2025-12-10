import '../../domain/repositories/i_ad_repository.dart';
import '../../data/models/native_ad_model.dart';
import '../services/admob_service.dart';
import '../services/ad_integration_service.dart';

/// Ad repository implementation
/// Wraps AdMob and ad integration services
class AdRepository implements IAdRepository {
  AdRepository();

  @override
  Future<NativeAdModel?> getNativeAd() async {
    return await AdMobService.createNativeAd();
  }

  @override
  Future<NativeAdModel?> getBannerAd() async {
    return await AdMobService.createBannerFallback();
  }

  @override
  Future<void> preloadAdsForCategory(String category) async {
    await AdIntegrationService.preloadAdsForCategories([category]);
  }

  @override
  Future<void> preloadAdsForCategories(List<String> categories) async {
    await AdIntegrationService.preloadAdsForCategories(categories);
  }

  @override
  void disposeAd(String adId) {
    // Disposal handled by AdMobService internally
  }

  @override
  Future<void> initialize() async {
    await AdIntegrationService.initialize();
  }
}
