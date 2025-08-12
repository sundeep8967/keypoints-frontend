import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/news_article_entity.dart';
import '../../../domain/usecases/get_news.dart';
import '../../../domain/usecases/get_news_by_category.dart';
import '../../../domain/usecases/mark_article_as_read.dart';
import '../../../services/ad_integration_service.dart';
import '../../../models/news_article.dart';

part 'news_event.dart';
part 'news_state.dart';

class NewsBloc extends Bloc<NewsEvent, NewsState> {
  final GetNews getNews;
  final GetNewsByCategory getNewsByCategory;
  final MarkArticleAsRead markArticleAsRead;
  
  // Internal caches to maintain state
  final Map<String, List<NewsArticleEntity>> _categoryCache = {};
  final Map<String, bool> _categoryLoading = {};
  int _currentIndex = 0;

  NewsBloc({
    required this.getNews,
    required this.getNewsByCategory,
    required this.markArticleAsRead,
  }) : super(NewsInitial()) {
    on<LoadNewsEvent>(_onLoadNews);
    on<LoadNewsByCategoryEvent>(_onLoadNewsByCategory);
    on<MarkArticleAsReadEvent>(_onMarkArticleAsRead);
    on<RefreshNewsEvent>(_onRefreshNews);
    on<LoadAllCategoriesEvent>(_onLoadAllCategories);
    on<PreloadCategoryEvent>(_onPreloadCategory);
    on<UpdateCurrentIndexEvent>(_onUpdateCurrentIndex);
    on<ClearCacheEvent>(_onClearCache);
  }

  /// Gets cached articles for a category
  List<NewsArticleEntity> getCachedArticles(String category) {
    return _categoryCache[category] ?? [];
  }

  /// Gets current index
  int get currentIndex => _currentIndex;

  /// Convert NewsArticleEntity to NewsArticle for ad integration
  List<NewsArticle> _convertEntitiesToModels(List<NewsArticleEntity> entities) {
    return entities.map((entity) => NewsArticle(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      imageUrl: entity.imageUrl,
      timestamp: entity.timestamp,
      category: entity.category,
      keypoints: entity.keypoints,
      sourceUrl: entity.sourceUrl,
    )).toList();
  }

  Future<void> _onLoadNews(LoadNewsEvent event, Emitter<NewsState> emit) async {
    emit(NewsLoading());
    
    final result = await getNews(GetNewsParams(limit: event.limit));
    
    await result.fold(
      (failure) async => emit(NewsError(failure.message)),
      (articles) async {
        // Convert entities to models for ad integration
        final articleModels = _convertEntitiesToModels(articles);
        // Integrate ads into the news feed
        final mixedFeed = await AdIntegrationService.integrateAdsIntoFeed(
          articles: articleModels,
          category: 'All',
          maxAds: 3,
        );
        emit(NewsLoaded(articles, mixedFeed: mixedFeed));
      },
    );
  }

  Future<void> _onLoadNewsByCategory(LoadNewsByCategoryEvent event, Emitter<NewsState> emit) async {
    emit(NewsLoading());
    
    final result = await getNewsByCategory(
      GetNewsByCategoryParams(category: event.category, limit: event.limit),
    );
    
    await result.fold(
      (failure) async => emit(NewsError(failure.message)),
      (articles) async {
        // Convert entities to models for ad integration
        final articleModels = _convertEntitiesToModels(articles);
        // Integrate ads into the category feed
        final mixedFeed = await AdIntegrationService.integrateAdsIntoFeed(
          articles: articleModels,
          category: event.category,
          maxAds: 3,
        );
        emit(NewsByCategoryLoaded(articles, event.category, mixedFeed: mixedFeed));
      },
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
    
    await result.fold(
      (failure) async => emit(NewsError(failure.message)),
      (articles) async {
        // Clear ads cache and integrate fresh ads
        AdIntegrationService.clearAllAds();
        // Convert entities to models for ad integration
        final articleModels = _convertEntitiesToModels(articles);
        final mixedFeed = await AdIntegrationService.integrateAdsIntoFeed(
          articles: articleModels,
          category: 'All',
          maxAds: 3,
        );
        emit(NewsLoaded(articles, mixedFeed: mixedFeed));
      },
    );
  }

  Future<void> _onLoadAllCategories(LoadAllCategoriesEvent event, Emitter<NewsState> emit) async {
    emit(NewsLoading());
    
    final result = await getNews(GetNewsParams(limit: event.limit));
    
    result.fold(
      (failure) => emit(NewsError(failure.message)),
      (articles) {
        // Cache articles for "All" category
        _categoryCache['All'] = articles;
        _categoryLoading['All'] = false;
        emit(NewsAllCategoriesLoaded(articles, Map.from(_categoryCache)));
      },
    );
  }

  Future<void> _onPreloadCategory(PreloadCategoryEvent event, Emitter<NewsState> emit) async {
    // Check if already cached
    if (_categoryCache.containsKey(event.category)) {
      emit(NewsCategoryPreloaded(event.category, _categoryCache[event.category]!));
      return;
    }

    _categoryLoading[event.category] = true;
    
    final result = await getNewsByCategory(
      GetNewsByCategoryParams(category: event.category, limit: event.limit),
    );
    
    result.fold(
      (failure) {
        _categoryLoading[event.category] = false;
        emit(NewsError(failure.message));
      },
      (articles) {
        _categoryCache[event.category] = articles;
        _categoryLoading[event.category] = false;
        emit(NewsCategoryPreloaded(event.category, articles));
      },
    );
  }

  Future<void> _onUpdateCurrentIndex(UpdateCurrentIndexEvent event, Emitter<NewsState> emit) async {
    _currentIndex = event.index;
    
    // Get current articles from state
    final currentState = state;
    if (currentState is NewsLoaded) {
      emit(NewsIndexUpdated(_currentIndex, currentState.articles));
    } else if (currentState is NewsByCategoryLoaded) {
      emit(NewsIndexUpdated(_currentIndex, currentState.articles));
    }
  }

  Future<void> _onClearCache(ClearCacheEvent event, Emitter<NewsState> emit) async {
    _categoryCache.clear();
    _categoryLoading.clear();
    _currentIndex = 0;
    emit(const NewsCacheCleared());
  }
}