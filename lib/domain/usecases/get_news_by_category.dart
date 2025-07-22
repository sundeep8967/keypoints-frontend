import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../entities/news_article_entity.dart';
import '../repositories/news_repository.dart';

class GetNewsByCategory implements UseCase<List<NewsArticleEntity>, GetNewsByCategoryParams> {
  final NewsRepository repository;

  GetNewsByCategory(this.repository);

  @override
  Future<Either<Failure, List<NewsArticleEntity>>> call(GetNewsByCategoryParams params) async {
    return await repository.getNewsByCategory(params.category, limit: params.limit);
  }
}

class GetNewsByCategoryParams {
  final String category;
  final int limit;

  GetNewsByCategoryParams({
    required this.category,
    this.limit = 20,
  });
}