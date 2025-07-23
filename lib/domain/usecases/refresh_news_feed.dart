import '../repositories/news_repository.dart';
import '../../core/usecases/usecase.dart';
import '../../core/error/failures.dart';
import 'package:dartz/dartz.dart';

class RefreshNewsFeed implements UseCase<void, NoParams> {
  final NewsRepository repository;

  RefreshNewsFeed(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    try {
      final result = await repository.refreshNews();
      return result;
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}