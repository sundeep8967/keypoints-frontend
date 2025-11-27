import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/network/network_info.dart';
import '../../domain/entities/news_article_entity.dart';
import '../../domain/repositories/news_repository.dart';
import '../datasources/news_local_datasource.dart';
import '../datasources/news_remote_datasource.dart';
import '../models/news_article_model.dart';

class NewsRepositoryImpl implements NewsRepository {
  final NewsRemoteDataSource remoteDataSource;
  final NewsLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  NewsRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<NewsArticleEntity>>> getNews({int limit = 20}) async {
    try {
      if (await networkInfo.isConnected) {
        // Try to get from remote first
        try {
          final remoteArticles = await remoteDataSource.getNews(limit: limit);
          await localDataSource.cacheNews(remoteArticles);
          
          // Prepare unread-only list
          final unread = await _unreadOnly(remoteArticles);
          return Right(unread);
        } catch (e) {
          // If remote fails, fallback to cache
          return await _getCachedNews();
        }
      } else {
        // No network, get from cache
        return await _getCachedNews();
      }
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<NewsArticleEntity>>> getNewsByCategory(String category, {int limit = 20}) async {
    try {
      if (await networkInfo.isConnected) {
        try {
          final remoteArticles = await remoteDataSource.getNewsByCategory(category, limit: limit);
          
          // Cache these articles (merge with existing cache)
          final existingCache = await localDataSource.getCachedNews();
          final mergedArticles = _mergeArticles(existingCache, remoteArticles);
          await localDataSource.cacheNews(mergedArticles);
          
          final unread = await _unreadOnly(remoteArticles);
          return Right(unread);
        } catch (e) {
          return await _getCachedNewsByCategory(category, limit);
        }
      } else {
        return await _getCachedNewsByCategory(category, limit);
      }
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markArticleAsRead(String articleId) async {
    try {
      await localDataSource.markArticleAsRead(articleId);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isArticleRead(String articleId) async {
    try {
      final isRead = await localDataSource.isArticleRead(articleId);
      return Right(isRead);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<NewsArticleEntity>>> searchNews(String query, {int limit = 20}) async {
    try {
      if (await networkInfo.isConnected) {
        final remoteArticles = await remoteDataSource.searchNews(query, limit: limit);
        final unread = await _unreadOnly(remoteArticles);
        return Right(unread);
      } else {
        // Search in cache
        final cachedArticles = await localDataSource.getCachedNews();
        final filteredArticles = cachedArticles.where((article) =>
          article.title.toLowerCase().contains(query.toLowerCase()) ||
          article.description.toLowerCase().contains(query.toLowerCase())
        ).take(limit).toList();
        
        final unread = await _unreadOnly(filteredArticles);
        return Right(unread);
      }
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> refreshNews() async {
    try {
      if (await networkInfo.isConnected) {
        await localDataSource.clearCache();
        final remoteArticles = await remoteDataSource.getNews(limit: 100);
        await localDataSource.cacheNews(remoteArticles);
        return const Right(null);
      } else {
        return Left(NetworkFailure('No internet connection'));
      }
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<Either<Failure, List<NewsArticleEntity>>> getNewsStream({int limit = 20}) {
    try {
      return remoteDataSource.getNewsStream(limit: limit).asyncMap((articles) async {
        final unread = await _unreadOnly(articles);
        return Right<Failure, List<NewsArticleEntity>>(unread);
      }).handleError((error) {
        return Left<Failure, List<NewsArticleEntity>>(ServerFailure(error.toString()));
      });
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

  // Helper methods
  Future<Either<Failure, List<NewsArticleEntity>>> _getCachedNews() async {
    try {
      final cachedArticles = await localDataSource.getCachedNews();
      final unread = await _unreadOnly(cachedArticles);
      return Right(unread);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<NewsArticleEntity>>> _getCachedNewsByCategory(String category, int limit) async {
    try {
      final cachedArticles = await localDataSource.getCachedNews();
      final filteredArticles = cachedArticles
          .where((article) => category == 'All' || article.category.toLowerCase() == category.toLowerCase())
          .take(limit)
          .toList();
      
      final unread = await _unreadOnly(filteredArticles);
      return Right(unread);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  Future<List<NewsArticleEntity>> _addReadStatusToArticles(List<NewsArticleModel> articles) async {
    final List<NewsArticleEntity> result = [];
    for (final article in articles) {
      final isRead = await localDataSource.isArticleRead(article.id);
      result.add(article.copyWith(isRead: isRead));
    }
    return result;
  }

  Future<List<NewsArticleEntity>> _unreadOnly(List<NewsArticleModel> articles) async {
    final withStatus = await _addReadStatusToArticles(articles);
    return withStatus.where((a) => !a.isRead).toList();
  }

  List<NewsArticleModel> _mergeArticles(List<NewsArticleModel> existing, List<NewsArticleModel> newArticles) {
    final Map<String, NewsArticleModel> articleMap = {};
    
    // Add existing articles
    for (final article in existing) {
      articleMap[article.id] = article;
    }
    
    // Add/update with new articles
    for (final article in newArticles) {
      articleMap[article.id] = article;
    }
    
    return articleMap.values.toList();
  }
}