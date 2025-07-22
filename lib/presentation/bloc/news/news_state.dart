part of 'news_bloc.dart';

abstract class NewsState extends Equatable {
  const NewsState();

  @override
  List<Object> get props => [];
}

class NewsInitial extends NewsState {}

class NewsLoading extends NewsState {}

class NewsLoaded extends NewsState {
  final List<NewsArticleEntity> articles;

  const NewsLoaded(this.articles);

  @override
  List<Object> get props => [articles];
}

class NewsByCategoryLoaded extends NewsState {
  final List<NewsArticleEntity> articles;
  final String category;

  const NewsByCategoryLoaded(this.articles, this.category);

  @override
  List<Object> get props => [articles, category];
}

class NewsError extends NewsState {
  final String message;

  const NewsError(this.message);

  @override
  List<Object> get props => [message];
}