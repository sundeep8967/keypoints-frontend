import '../../domain/entities/news_article_entity.dart';
import '../../domain/repositories/i_category_repository.dart';
import '../services/dynamic_category_discovery_service.dart';
import '../services/supabase_service.dart';

/// Category repository implementation
/// Wraps existing category services
class CategoryRepository implements ICategoryRepository {
  CategoryRepository();

  @override
  Future<List<String>> getAvailableCategories() async {
    // Use dynamic category discovery
    return await DynamicCategoryDiscoveryService.discoverCategories();
  }

  @override
  Future<List<String>> getUserPreferredCategories() async {
    // Returns default categories for now
    return ['All', 'Technology', 'Business', 'Sports', 'Entertainment'];
  }

  @override
  Future<void> savePreferredCategories(List<String> categories) async {
    // Category preferences storage not yet implemented
  }

  @override
  Future<List<NewsArticleEntity>> getArticlesByCategory(String category) async {
    return await SupabaseService.getUnreadNewsByCategory(category, [], limit: 100);
  }

  @override
  Future<void> preloadPopularCategories() async {
    // Preloading optimization not yet implemented
  }
}
