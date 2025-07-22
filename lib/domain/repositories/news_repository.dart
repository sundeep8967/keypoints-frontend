import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/news_article_entity.dart';

abstract class NewsRepository {
  Future<Either<Failure, List<NewsArticleEntity>>> getNews({int limit = 20});
  Future<Either<Failure, List<NewsArticleEntity>>> getNewsByCategory(String category, {int limit = 20});
  Future<Either<Failure, List<NewsArticleEntity>>> getUnreadNews({int limit = 20});
  Future<Either<Failure, void>> markArticleAsRead(String articleId);
  Future<Either<Failure, bool>> isArticleRead(String articleId);
  Future<Either<Failure, List<NewsArticleEntity>>> searchNews(String query, {int limit = 20});
  Future<Either<Failure, void>> refreshNews();
  Stream<Either<Failure, List<NewsArticleEntity>>> getNewsStream({int limit = 20});
}