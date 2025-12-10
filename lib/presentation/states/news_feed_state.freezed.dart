// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'news_feed_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$NewsFeedState {
  /// List of feed items (articles + ads)
  List<dynamic> get feedItems => throw _privateConstructorUsedError;

  /// Currently selected category
  String get selectedCategory => throw _privateConstructorUsedError;

  /// Current article index in the feed
  int get currentIndex => throw _privateConstructorUsedError;

  /// Cache of articles by category
  Map<String, List<dynamic>> get categoryCache =>
      throw _privateConstructorUsedError;

  /// Loading state
  bool get isLoading => throw _privateConstructorUsedError;

  /// Error message if any
  String? get error => throw _privateConstructorUsedError;

  /// Available categories
  List<String> get availableCategories => throw _privateConstructorUsedError;

  /// Whether cached content is shown
  bool get showingCachedContent => throw _privateConstructorUsedError;

  /// Create a copy of NewsFeedState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NewsFeedStateCopyWith<NewsFeedState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NewsFeedStateCopyWith<$Res> {
  factory $NewsFeedStateCopyWith(
          NewsFeedState value, $Res Function(NewsFeedState) then) =
      _$NewsFeedStateCopyWithImpl<$Res, NewsFeedState>;
  @useResult
  $Res call(
      {List<dynamic> feedItems,
      String selectedCategory,
      int currentIndex,
      Map<String, List<dynamic>> categoryCache,
      bool isLoading,
      String? error,
      List<String> availableCategories,
      bool showingCachedContent});
}

/// @nodoc
class _$NewsFeedStateCopyWithImpl<$Res, $Val extends NewsFeedState>
    implements $NewsFeedStateCopyWith<$Res> {
  _$NewsFeedStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NewsFeedState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? feedItems = null,
    Object? selectedCategory = null,
    Object? currentIndex = null,
    Object? categoryCache = null,
    Object? isLoading = null,
    Object? error = freezed,
    Object? availableCategories = null,
    Object? showingCachedContent = null,
  }) {
    return _then(_value.copyWith(
      feedItems: null == feedItems
          ? _value.feedItems
          : feedItems // ignore: cast_nullable_to_non_nullable
              as List<dynamic>,
      selectedCategory: null == selectedCategory
          ? _value.selectedCategory
          : selectedCategory // ignore: cast_nullable_to_non_nullable
              as String,
      currentIndex: null == currentIndex
          ? _value.currentIndex
          : currentIndex // ignore: cast_nullable_to_non_nullable
              as int,
      categoryCache: null == categoryCache
          ? _value.categoryCache
          : categoryCache // ignore: cast_nullable_to_non_nullable
              as Map<String, List<dynamic>>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      availableCategories: null == availableCategories
          ? _value.availableCategories
          : availableCategories // ignore: cast_nullable_to_non_nullable
              as List<String>,
      showingCachedContent: null == showingCachedContent
          ? _value.showingCachedContent
          : showingCachedContent // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NewsFeedStateImplCopyWith<$Res>
    implements $NewsFeedStateCopyWith<$Res> {
  factory _$$NewsFeedStateImplCopyWith(
          _$NewsFeedStateImpl value, $Res Function(_$NewsFeedStateImpl) then) =
      __$$NewsFeedStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<dynamic> feedItems,
      String selectedCategory,
      int currentIndex,
      Map<String, List<dynamic>> categoryCache,
      bool isLoading,
      String? error,
      List<String> availableCategories,
      bool showingCachedContent});
}

/// @nodoc
class __$$NewsFeedStateImplCopyWithImpl<$Res>
    extends _$NewsFeedStateCopyWithImpl<$Res, _$NewsFeedStateImpl>
    implements _$$NewsFeedStateImplCopyWith<$Res> {
  __$$NewsFeedStateImplCopyWithImpl(
      _$NewsFeedStateImpl _value, $Res Function(_$NewsFeedStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of NewsFeedState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? feedItems = null,
    Object? selectedCategory = null,
    Object? currentIndex = null,
    Object? categoryCache = null,
    Object? isLoading = null,
    Object? error = freezed,
    Object? availableCategories = null,
    Object? showingCachedContent = null,
  }) {
    return _then(_$NewsFeedStateImpl(
      feedItems: null == feedItems
          ? _value._feedItems
          : feedItems // ignore: cast_nullable_to_non_nullable
              as List<dynamic>,
      selectedCategory: null == selectedCategory
          ? _value.selectedCategory
          : selectedCategory // ignore: cast_nullable_to_non_nullable
              as String,
      currentIndex: null == currentIndex
          ? _value.currentIndex
          : currentIndex // ignore: cast_nullable_to_non_nullable
              as int,
      categoryCache: null == categoryCache
          ? _value._categoryCache
          : categoryCache // ignore: cast_nullable_to_non_nullable
              as Map<String, List<dynamic>>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      availableCategories: null == availableCategories
          ? _value._availableCategories
          : availableCategories // ignore: cast_nullable_to_non_nullable
              as List<String>,
      showingCachedContent: null == showingCachedContent
          ? _value.showingCachedContent
          : showingCachedContent // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$NewsFeedStateImpl implements _NewsFeedState {
  const _$NewsFeedStateImpl(
      {final List<dynamic> feedItems = const [],
      this.selectedCategory = 'All',
      this.currentIndex = 0,
      final Map<String, List<dynamic>> categoryCache = const {},
      this.isLoading = false,
      this.error,
      final List<String> availableCategories = const ['All'],
      this.showingCachedContent = false})
      : _feedItems = feedItems,
        _categoryCache = categoryCache,
        _availableCategories = availableCategories;

  /// List of feed items (articles + ads)
  final List<dynamic> _feedItems;

  /// List of feed items (articles + ads)
  @override
  @JsonKey()
  List<dynamic> get feedItems {
    if (_feedItems is EqualUnmodifiableListView) return _feedItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_feedItems);
  }

  /// Currently selected category
  @override
  @JsonKey()
  final String selectedCategory;

  /// Current article index in the feed
  @override
  @JsonKey()
  final int currentIndex;

  /// Cache of articles by category
  final Map<String, List<dynamic>> _categoryCache;

  /// Cache of articles by category
  @override
  @JsonKey()
  Map<String, List<dynamic>> get categoryCache {
    if (_categoryCache is EqualUnmodifiableMapView) return _categoryCache;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_categoryCache);
  }

  /// Loading state
  @override
  @JsonKey()
  final bool isLoading;

  /// Error message if any
  @override
  final String? error;

  /// Available categories
  final List<String> _availableCategories;

  /// Available categories
  @override
  @JsonKey()
  List<String> get availableCategories {
    if (_availableCategories is EqualUnmodifiableListView)
      return _availableCategories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_availableCategories);
  }

  /// Whether cached content is shown
  @override
  @JsonKey()
  final bool showingCachedContent;

  @override
  String toString() {
    return 'NewsFeedState(feedItems: $feedItems, selectedCategory: $selectedCategory, currentIndex: $currentIndex, categoryCache: $categoryCache, isLoading: $isLoading, error: $error, availableCategories: $availableCategories, showingCachedContent: $showingCachedContent)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NewsFeedStateImpl &&
            const DeepCollectionEquality()
                .equals(other._feedItems, _feedItems) &&
            (identical(other.selectedCategory, selectedCategory) ||
                other.selectedCategory == selectedCategory) &&
            (identical(other.currentIndex, currentIndex) ||
                other.currentIndex == currentIndex) &&
            const DeepCollectionEquality()
                .equals(other._categoryCache, _categoryCache) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error) &&
            const DeepCollectionEquality()
                .equals(other._availableCategories, _availableCategories) &&
            (identical(other.showingCachedContent, showingCachedContent) ||
                other.showingCachedContent == showingCachedContent));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_feedItems),
      selectedCategory,
      currentIndex,
      const DeepCollectionEquality().hash(_categoryCache),
      isLoading,
      error,
      const DeepCollectionEquality().hash(_availableCategories),
      showingCachedContent);

  /// Create a copy of NewsFeedState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NewsFeedStateImplCopyWith<_$NewsFeedStateImpl> get copyWith =>
      __$$NewsFeedStateImplCopyWithImpl<_$NewsFeedStateImpl>(this, _$identity);
}

abstract class _NewsFeedState implements NewsFeedState {
  const factory _NewsFeedState(
      {final List<dynamic> feedItems,
      final String selectedCategory,
      final int currentIndex,
      final Map<String, List<dynamic>> categoryCache,
      final bool isLoading,
      final String? error,
      final List<String> availableCategories,
      final bool showingCachedContent}) = _$NewsFeedStateImpl;

  /// List of feed items (articles + ads)
  @override
  List<dynamic> get feedItems;

  /// Currently selected category
  @override
  String get selectedCategory;

  /// Current article index in the feed
  @override
  int get currentIndex;

  /// Cache of articles by category
  @override
  Map<String, List<dynamic>> get categoryCache;

  /// Loading state
  @override
  bool get isLoading;

  /// Error message if any
  @override
  String? get error;

  /// Available categories
  @override
  List<String> get availableCategories;

  /// Whether cached content is shown
  @override
  bool get showingCachedContent;

  /// Create a copy of NewsFeedState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NewsFeedStateImplCopyWith<_$NewsFeedStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
