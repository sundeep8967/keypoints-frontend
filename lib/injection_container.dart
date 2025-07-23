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

// Presentation
import 'presentation/bloc/news/news_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
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
}