import '../entities/news_article_entity.dart';
import '../repositories/news_repository.dart';
import '../../core/usecases/usecase.dart';
import '../../core/error/failures.dart';
import 'package:dartz/dartz.dart';

class LoadMainNewsFeed implements UseCase<List<NewsArticleEntity>, NoParams> {
  final NewsRepository repository;

  LoadMainNewsFeed(this.repository);

  @override
  Future<Either<Failure, List<NewsArticleEntity>>> call(NoParams params) async {
    try {
      return await repository.getNews();
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}