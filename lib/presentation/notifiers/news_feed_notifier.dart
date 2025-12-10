import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/news_article_entity.dart';
import '../../domain/repositories/i_article_repository.dart';
import '../../domain/repositories/i_category_repository.dart';
import '../../domain/repositories/i_ad_repository.dart';
import '../states/news_feed_state.dart';
import '../../core/utils/app_logger.dart';
import '../../core/di/providers.dart';
import '../../data/services/ad_integration_service.dart';

part 'news_feed_notifier.g.dart';

/// News feed notifier - manages news feed state and logic
/// Replaces the 1373-line NewsFeedScreen logic
@riverpod
class NewsFeedNotifier extends _$NewsFeedNotifier {
  late IArticleRepository _articleRepository;
  late ICategoryRepository _categoryRepository;
  late IAdRepository _adRepository;

  @override
  NewsFeedState build() {
    // Dependencies will be injected via providers
    _articleRepository = ref.watch(articleRepositoryProvider);
    _categoryRepository = ref.watch(categoryRepositoryProvider);
    _adRepository = ref.watch(adRepositoryProvider);
    
    // Auto-load initial feed when notifier is created
    Future.microtask(() => loadInitialFeed());
    
    return const NewsFeedState();
  }

  /// Load initial feed - tries cache first, then network
  Future<void> loadInitialFeed() async {
    AppLogger.info('📱 LOADING INITIAL FEED');
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // 1. Try cache first for instant display
      final cached = await _articleRepository.loadCachedArticles();
      if (cached.isNotEmpty) {
        // Deduplicate cached articles
        final uniqueCached = _deduplicateArticles(cached);
        final items = uniqueCached.take(20).toList();
        
        // Integrate ads into cached feed
        final feedWithAds = await AdIntegrationService.integrateAdsIntoFeed(
          articles: items.whereType<NewsArticleEntity>().toList(),
          category: 'All',
          maxAds: 999,
        );
        
        final newCache = {...state.categoryCache};
        newCache['All'] = feedWithAds;
        
        state = state.copyWith(
          feedItems: feedWithAds,
          categoryCache: newCache,
          isLoading: false,
          showingCachedContent: true,
        );
        
        AppLogger.success('⚡ INSTANT: Loaded ${items.length} unique cached articles + ${feedWithAds.length - items.length} ads');
        
        // Mark first article as read
        if (feedWithAds.isNotEmpty && feedWithAds.first is NewsArticleEntity) {
          await _articleRepository.markAsRead((feedWithAds.first as NewsArticleEntity).id);
        }
        
        // Load categories in background
        _loadCategories();
        return;
      }

      // 2. No cache - load fresh (first time user)
      AppLogger.info('📱 NO CACHE: Loading fresh content');
      await _loadFreshArticles('All');
      await _loadCategories();
      
    } catch (e) {
      AppLogger.error('❌ INITIAL LOAD ERROR: $e');
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  /// Switch to a different category
  Future<void> switchCategory(String category) async {
    AppLogger.info('📂 SWITCHING TO: $category');
    
    state = state.copyWith(
      selectedCategory: category,
      currentIndex: 0,
    );

    // Check cache first
    if (state.categoryCache[category]?.isNotEmpty == true) {
      state = state.copyWith(
        feedItems: state.categoryCache[category]!,
        isLoading: false,
      );
      AppLogger.success('✅ CACHE HIT: $category');
      return;
    }

    // Load fresh
    await _loadFreshArticles(category);
  }

  /// Load more articles for infinite scroll
  Future<void> loadMoreArticles() async {
    if (state.isLoading) return;
    
    AppLogger.info('🔄 LOADING MORE: ${state.selectedCategory}');
    
    try {
      final currentEntities = state.feedItems
          .whereType<NewsArticleEntity>()
          .toList();
      
      final newArticles = await _articleRepository.loadMoreArticles(
        category: state.selectedCategory,
        currentArticles: currentEntities,
      );
      
      if (newArticles.isNotEmpty) {
        // Integrate ads into new batch (continuous monetization!)
        final feedWithAds = await AdIntegrationService.integrateAdsIntoFeed(
          articles: newArticles,
          category: state.selectedCategory,
          maxAds: 999, // Unlimited
        );
        
        final updatedItems = [...state.feedItems, ...feedWithAds];
        final newCache = {...state.categoryCache};
        newCache[state.selectedCategory] = updatedItems;
        
        state = state.copyWith(
          feedItems: updatedItems,
          categoryCache: newCache,
        );
        
        AppLogger.success('✅ LOADED MORE: ${newArticles.length} articles + ${feedWithAds.length - newArticles.length} ads');
      }
    } catch (e) {
      AppLogger.error('❌ LOAD MORE ERROR: $e');
    }
  }

  /// Mark current article as read
  Future<void> markCurrentAsRead() async {
    if (state.feedItems.isEmpty || state.currentIndex >= state.feedItems.length) {
      return;
    }
    
    final item = state.feedItems[state.currentIndex];
    if (item is NewsArticleEntity) {
      await _articleRepository.markAsRead(item.id);
      AppLogger.info('✓ MARKED READ: ${item.id}');
    }
  }

  /// Update current index (when user swipes)
  void updateCurrentIndex(int index) {
    state = state.copyWith(currentIndex: index);
    
    // Auto-mark as read
    Future.microtask(() => markCurrentAsRead());
    
    // Preload more if near the end
    if (index >= state.feedItems.length - 5) {
      Future.microtask(() => loadMoreArticles());
    }
  }

  /// Refresh current category (pull-to-refresh)
  Future<void> refreshCurrentCategory() async {
    AppLogger.info('🔄 REFRESHING: ${state.selectedCategory}');
    await _loadFreshArticles(state.selectedCategory);
  }

  // ========== Private Methods ==========

  Future<void> _loadFreshArticles(String category) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final articles = await _articleRepository.getUnreadArticles(
        category: category == 'All' ? null : category,
      );
      
      if (articles.isEmpty) {
        state = state.copyWith(
          error: 'No articles available',
          isLoading: false,
        );
        return;
      }
      
      // Integrate ads into the feed (every 5 articles)
      final feedWithAds = await AdIntegrationService.integrateAdsIntoFeed(
        articles: articles,
        category: category,
        maxAds: 999, // Unlimited ads
      );
      
      // Cache the articles (without ads)
      await _articleRepository.cacheArticles(articles);
      
      final newCache = {...state.categoryCache};
      newCache[category] = feedWithAds; // Cache includes ads
      
      state = state.copyWith(
        feedItems: feedWithAds,
        categoryCache: newCache,
        isLoading: false,
        showingCachedContent: false,
      );
      
      AppLogger.success('✅ LOADED FRESH: ${articles.length} articles + ${feedWithAds.length - articles.length} ads for $category');
      
    } catch (e) {
      AppLogger.error('❌ LOAD ERROR: $e');
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryRepository.getAvailableCategories();
      state = state.copyWith(availableCategories: categories);
      AppLogger.success('✅ LOADED CATEGORIES: ${categories.length}');
    } catch (e) {
      AppLogger.error('❌ CATEGORY ERROR: $e');
    }
  }

  /// Deduplicate articles by ID
  List<NewsArticleEntity> _deduplicateArticles(List<NewsArticleEntity> articles) {
    final seenIds = <String>{};
    final unique = <NewsArticleEntity>[];
    
    for (final article in articles) {
      if (!seenIds.contains(article.id)) {
        unique.add(article);
        seenIds.add(article.id);
      }
    }
    
    if (unique.length < articles.length) {
      AppLogger.info('🔍 Deduplicated: ${articles.length} → ${unique.length} articles (removed ${articles.length - unique.length} duplicates)');
    }
    
    return unique;
  }
}
