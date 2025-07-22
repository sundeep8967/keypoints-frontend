import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../entities/news_article_entity.dart';
import '../repositories/news_repository.dart';

class GetNews implements UseCase<List<NewsArticleEntity>, GetNewsParams> {
  final NewsRepository repository;

  GetNews(this.repository);

  @override
  Future<Either<Failure, List<NewsArticleEntity>>> call(GetNewsParams params) async {
    return await repository.getNews(limit: params.limit);
  }
}

class GetNewsParams {
  final int limit;

  GetNewsParams({this.limit = 20});
}