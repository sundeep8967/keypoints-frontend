import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../repositories/news_repository.dart' ;

class MarkArticleAsRead implements UseCase<void, MarkArticleAsReadParams> {
  final NewsRepository repository;

  MarkArticleAsRead(this.repository);

  @override
  Future<Either<Failure, void>> call(MarkArticleAsReadParams params) async {
    return await repository.markArticleAsRead(params.articleId);
  }
}

class MarkArticleAsReadParams {
  final String articleId;

  MarkArticleAsReadParams({required this.articleId});
}