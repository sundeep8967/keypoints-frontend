import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/repositories/i_article_repository.dart';
import '../../domain/repositories/i_category_repository.dart';
import '../../domain/repositories/i_ad_repository.dart';
import '../../data/repositories/article_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/ad_repository.dart';
import '../../data/services/supabase_service.dart';
import '../../data/services/read_articles_service.dart';
import '../../data/services/admob_service.dart';
import '../../data/services/ad_integration_service.dart';

part 'providers.g.dart';

// ========== Repository Providers ==========

/// Article repository provider - singleton
@riverpod
IArticleRepository articleRepository(ArticleRepositoryRef ref) {
  return ArticleRepository(
    supabaseService: SupabaseService(),
    readArticlesService: ReadArticlesService(),
  );
}

/// Category repository provider - singleton
@riverpod
ICategoryRepository categoryRepository(CategoryRepositoryRef ref) {
  return CategoryRepository();
}

/// Ad repository provider - singleton
@riverpod
IAdRepository adRepository(AdRepositoryRef ref) {
  return AdRepository();
}

// ========== Service Providers ==========

/// Ad integration service provider - singleton
@riverpod
AdIntegrationService adIntegrationService(AdIntegrationServiceRef ref) {
  return AdIntegrationService();
}
