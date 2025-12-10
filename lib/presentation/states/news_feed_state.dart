import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/news_article_entity.dart';

part 'news_feed_state.freezed.dart';

/// Immutable state for news feed screen
/// Uses freezed for immutability and copyWith
@freezed
class NewsFeedState with _$NewsFeedState {
  const factory NewsFeedState({
    /// List of feed items (articles + ads)
    @Default([]) List<dynamic> feedItems,
    
    /// Currently selected category
    @Default('All') String selectedCategory,
    
    /// Current article index in the feed
    @Default(0) int currentIndex,
    
    /// Cache of articles by category
    @Default({}) Map<String, List<dynamic>> categoryCache,
    
    /// Loading state
    @Default(false) bool isLoading,
    
    /// Error message if any
    String? error,
    
    /// Available categories
    @Default(['All']) List<String> availableCategories,
    
    /// Whether cached content is shown
    @Default(false) bool showingCachedContent,
  }) = _NewsFeedState;
}
