part of 'news_bloc.dart';

abstract class NewsEvent extends Equatable {
  const NewsEvent();

  @override
  List<Object> get props => [];
}

class LoadNewsEvent extends NewsEvent {
  final int limit;

  const LoadNewsEvent({this.limit = 20});

  @override
  List<Object> get props => [limit];
}

class LoadNewsByCategoryEvent extends NewsEvent {
  final String category;
  final int limit;

  const LoadNewsByCategoryEvent({
    required this.category,
    this.limit = 20,
  });

  @override
  List<Object> get props => [category, limit];
}

class MarkArticleAsReadEvent extends NewsEvent {
  final String articleId;

  const MarkArticleAsReadEvent({required this.articleId});

  @override
  List<Object> get props => [articleId];
}

class RefreshNewsEvent extends NewsEvent {
  final int limit;

  const RefreshNewsEvent({this.limit = 20});

  @override
  List<Object> get props => [limit];
}