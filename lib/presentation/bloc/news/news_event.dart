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

class LoadAllCategoriesEvent extends NewsEvent {
  final int limit;

  const LoadAllCategoriesEvent({this.limit = 200});

  @override
  List<Object> get props => [limit];
}

class PreloadCategoryEvent extends NewsEvent {
  final String category;
  final int limit;

  const PreloadCategoryEvent({
    required this.category,
    this.limit = 100,
  });

  @override
  List<Object> get props => [category, limit];
}

class UpdateCurrentIndexEvent extends NewsEvent {
  final int index;

  const UpdateCurrentIndexEvent({required this.index});

  @override
  List<Object> get props => [index];
}

class ClearCacheEvent extends NewsEvent {
  const ClearCacheEvent();
}