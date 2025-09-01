import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Core
import 'core/network/network_info.dart';

// Data
import 'data/datasources/news_local_datasource.dart';
import 'data/datasources/news_remote_datasource.dart';
import 'data/repositories/news_repository_impl.dart';

// Domain
import 'domain/repositories/news_repository.dart';
import 'domain/usecases/get_news.dart';
import 'domain/usecases/get_news_by_category.dart';
import 'domain/usecases/mark_article_as_read.dart';
import 'domain/usecases/load_main_news_feed.dart';
import 'domain/usecases/refresh_news_feed.dart';

// Services - Core Services
import 'services/supabase_service.dart';
import 'services/local_storage_service.dart';
import 'services/read_articles_service.dart';
import 'services/admob_service.dart';
import 'services/fcm_service.dart';

// Services - Image & Color Services
import 'services/color_extraction_service.dart';
import 'services/optimized_image_service.dart';
import 'services/image_preloader_service.dart';
import 'services/parallel_color_service.dart';
import 'services/instant_preloader_service.dart';

// Services - News & Content Services
import 'services/news_feed_helper.dart';
import 'services/news_loading_service.dart';
import 'services/article_management_service.dart';
import 'services/news_integration_service.dart';
import 'services/news_ui_service.dart';

// Services - Category Services
import 'services/category_loading_service.dart';
import 'services/category_management_service.dart';
import 'services/category_preference_service.dart';
import 'services/category_scroll_service.dart';
import 'services/dynamic_category_discovery_service.dart';

// Services - UI & UX Services
import 'services/text_formatting_service.dart';
import 'services/dynamic_text_service.dart';
import 'services/error_message_service.dart';
import 'services/url_launcher_service.dart';
import 'services/scroll_state_service.dart';

// Services - Advanced Features
import 'services/infinite_scroll_service.dart';
import 'services/predictive_preloader_service.dart';
import 'services/ad_integration_service.dart';
import 'services/reward_points_service.dart';
import 'services/reward_claims_service.dart';

// Services - Consolidated Services
import 'services/consolidated/news_service.dart';
import 'services/consolidated/article_service.dart';
import 'services/consolidated/category_service.dart';
import 'services/consolidated/news_facade.dart';

// Interfaces
import 'core/interfaces/article_interface.dart';
import 'core/interfaces/news_interface.dart';
import 'core/interfaces/category_interface.dart';

// Refactored Services
import 'services/refactored/article_validator_service.dart';
import 'services/refactored/article_state_manager.dart';
import 'services/refactored/news_loader_service.dart';
import 'services/refactored/news_processor_service.dart';
import 'services/refactored/category_manager_service.dart';
import 'services/refactored/service_coordinator.dart';

// Presentation
import 'presentation/bloc/news/news_bloc.dart';

final sl = GetIt.instance;

Future<void> initLegacy() async {
  //! Features - News
  // Bloc
  sl.registerFactory(
    () => NewsBloc(
      getNews: sl(),
      getNewsByCategory: sl(),
      markArticleAsRead: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetNews(sl()));
  sl.registerLazySingleton(() => GetNewsByCategory(sl()));
  sl.registerLazySingleton(() => MarkArticleAsRead(sl()));
  
  // New consolidated use cases
  sl.registerLazySingleton(() => LoadMainNewsFeed(sl()));
  sl.registerLazySingleton(() => RefreshNewsFeed(sl()));

  // Repository
  sl.registerLazySingleton<NewsRepository>(
    () => NewsRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data sources
  sl.registerLazySingleton<NewsRemoteDataSource>(
    () => NewsRemoteDataSourceImpl(supabaseClient: sl()),
  );

  sl.registerLazySingleton<NewsLocalDataSource>(
    () => NewsLocalDataSourceImpl(),
  );

  //! Core
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());

  //! External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  
  // Supabase client will be registered after initialization
  sl.registerLazySingleton(() => Supabase.instance.client);

  //! Service Layer - All Services Registration
  // Note: Most services in this app use static methods and don't need dependency injection
  // They are utility services that can be called directly without instantiation
  
  // The following services use static methods and are already available:
  // - SupabaseService (static methods)
  // - LocalStorageService (static methods)
  // - ReadArticlesService (static methods)
  // - AdMobService (static methods)
  // - FCMService (static methods)
  // - ColorExtractionService (static methods)
  // - OptimizedImageService (static methods)
  // - ImagePreloaderService (static methods)
  // - ParallelColorService (static methods)
  // - InstantPreloaderService (static methods)
  // - NewsFeedHelper (static methods)
  // - NewsLoadingService (static methods)
  // - ArticleManagementService (static methods)
  // - NewsIntegrationService (static methods)
  // - NewsUIService (static methods)
  // - CategoryLoadingService (static methods)
  // - CategoryManagementService (static methods)
  // - CategoryPreferenceService (static methods)
  // - CategoryScrollService (static methods)
  // - DynamicCategoryDiscoveryService (static methods)
  // - TextFormattingService (static methods)
  // - DynamicTextService (static methods)
  // - ErrorMessageService (static methods)
  // - URLLauncherService (static methods)
  // - ScrollStateService (static methods)
  // - InfiniteScrollService (static methods)
  // - PredictivePreloaderService (static methods)
  // - AdIntegrationService (static methods)
  // - RewardPointsService (static methods)
  // - RewardClaimsService (static methods)
  // - Consolidated Services: NewsService, ArticleService, CategoryService, NewsFacade (static methods)
  
  // All services are now accessible throughout the app via their static methods
  // No additional registration needed as they don't require dependency injection
}

/// NEW REFACTORED ARCHITECTURE - Use this for new code
Future<void> init() async {
  //! Service Coordinator - Central service management
  sl.registerLazySingleton<ServiceCoordinator>(() => ServiceCoordinator());
  
  //! Refactored Services - Interface-based registration
  // Article services
  sl.registerLazySingleton<IArticleValidator>(() => ArticleValidatorService());
  sl.registerLazySingleton<IArticleStateManager>(() => ArticleStateManager());
  
  // News services
  sl.registerLazySingleton<INewsLoader>(() => NewsLoaderService());
  sl.registerLazySingleton<INewsProcessor>(() => NewsProcessorService());
  
  // Category services
  sl.registerLazySingleton<ICategoryManager>(() => CategoryManagerService());
  sl.registerLazySingleton<ICategoryLoader>(() => CategoryManagerService());
  sl.registerLazySingleton<ICategoryPreferences>(() => CategoryManagerService());

  //! Features - News
  // Bloc with refactored dependencies
  sl.registerFactory(
    () => NewsBloc(
      getNews: sl(),
      getNewsByCategory: sl(),
      markArticleAsRead: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetNews(sl()));
  sl.registerLazySingleton(() => GetNewsByCategory(sl()));
  sl.registerLazySingleton(() => MarkArticleAsRead(sl()));
  
  // New consolidated use cases
  sl.registerLazySingleton(() => LoadMainNewsFeed(sl()));
  sl.registerLazySingleton(() => RefreshNewsFeed(sl()));

  // Repository
  sl.registerLazySingleton<NewsRepository>(
    () => NewsRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data sources
  sl.registerLazySingleton<NewsRemoteDataSource>(
    () => NewsRemoteDataSourceImpl(supabaseClient: sl()),
  );

  sl.registerLazySingleton<NewsLocalDataSource>(
    () => NewsLocalDataSourceImpl(),
  );

  //! Core
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());

  //! External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  
  // Supabase client will be registered after initialization
  sl.registerLazySingleton(() => Supabase.instance.client);

  //! Initialize the service coordinator
  await sl<ServiceCoordinator>().initialize();
}