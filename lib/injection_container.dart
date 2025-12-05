import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

final sl = GetIt.instance;

/// SIMPLIFIED ARCHITECTURE - Only active services
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

  //! External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  
  // Supabase client will be registered after initialization
  sl.registerLazySingleton(() => Supabase.instance.client);

  //! Initialize the service coordinator (now instant - heavy work runs in background)
  await sl<ServiceCoordinator>().initialize();
}