import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/news_article_entity.dart';
import '../../../domain/usecases/get_news.dart';
import '../../../domain/usecases/get_news_by_category.dart';
import '../../../domain/usecases/mark_article_as_read.dart';

part 'news_event.dart';
part 'news_state.dart';

class NewsBloc extends Bloc<NewsEvent, NewsState> {
  final GetNews getNews;
  final GetNewsByCategory getNewsByCategory;
  final MarkArticleAsRead markArticleAsRead;

  NewsBloc({
    required this.getNews,
    required this.getNewsByCategory,
    required this.markArticleAsRead,
  }) : super(NewsInitial()) {
    on<LoadNewsEvent>(_onLoadNews);
    on<LoadNewsByCategoryEvent>(_onLoadNewsByCategory);
    on<MarkArticleAsReadEvent>(_onMarkArticleAsRead);
    on<RefreshNewsEvent>(_onRefreshNews);
  }

  Future<void> _onLoadNews(LoadNewsEvent event, Emitter<NewsState> emit) async {
    emit(NewsLoading());
    
    final result = await getNews(GetNewsParams(limit: event.limit));
    
    result.fold(
      (failure) => emit(NewsError(failure.message)),
      (articles) => emit(NewsLoaded(articles)),
    );
  }

  Future<void> _onLoadNewsByCategory(LoadNewsByCategoryEvent event, Emitter<NewsState> emit) async {
    emit(NewsLoading());
    
    final result = await getNewsByCategory(
      GetNewsByCategoryParams(category: event.category, limit: event.limit),
    );
    
    result.fold(
      (failure) => emit(NewsError(failure.message)),
      (articles) => emit(NewsByCategoryLoaded(articles, event.category)),
    );
  }

  Future<void> _onMarkArticleAsRead(MarkArticleAsReadEvent event, Emitter<NewsState> emit) async {
    final currentState = state;
    if (currentState is NewsLoaded) {
      // Optimistically update UI
      final updatedArticles = currentState.articles
          .map((article) => article.id == event.articleId 
              ? article.copyWith(isRead: true) 
              : article)
          .toList();
      
      emit(NewsLoaded(updatedArticles));
      
      // Then update backend
      final result = await markArticleAsRead(MarkArticleAsReadParams(articleId: event.articleId));
      
      result.fold(
        (failure) {
          // Revert on failure
          emit(NewsLoaded(currentState.articles));
          emit(NewsError(failure.message));
        },
        (_) {
          // Success - keep the updated state
        },
      );
    }
  }

  Future<void> _onRefreshNews(RefreshNewsEvent event, Emitter<NewsState> emit) async {
    // Don't show loading for refresh
    final result = await getNews(GetNewsParams(limit: event.limit));
    
    result.fold(
      (failure) => emit(NewsError(failure.message)),
      (articles) => emit(NewsLoaded(articles)),
    );
  }
}