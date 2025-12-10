import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../notifiers/news_feed_notifier.dart';
import '../../states/news_feed_state.dart';
import '../widgets/news_feed_widgets.dart';
import '../widgets/news_feed_page_builder.dart';
import '../../../data/services/category_scroll_service.dart';
import '../../../data/services/admob_service.dart';
import '../../../data/models/native_ad_model.dart';
import '../../../core/utils/app_logger.dart';
import 'settings_screen.dart';

/// NewsFeedScreen - Clean MVVM implementation
/// Pure UI layer - all business logic is in NewsFeedNotifier
class NewsFeedScreen extends ConsumerStatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  ConsumerState<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends ConsumerState<NewsFeedScreen> 
    with TickerProviderStateMixin {
  
  // UI-only controllers
  late PageController _categoryPageController;
  late ScrollController _categoryScrollController;
  final Map<String, PageController> _articlePageControllers = {};
  final Set<String> _pendingOnDemandAds = {};

  @override
  void initState() {
    super.initState();
    _categoryPageController = PageController(initialPage: 0);
    _categoryScrollController = ScrollController();
  }

  @override
  void dispose() {
    _categoryPageController.dispose();
    _categoryScrollController.dispose();
    for (final controller in _articlePageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch state from Riverpod
    final state = ref.watch(newsFeedNotifierProvider);
    final notifier = ref.read(newsFeedNotifierProvider.notifier);

    // Show loading screen during initial load
    if (state.isLoading && state.feedItems.isEmpty) {
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.black,
        child: Stack(
          children: [
            NewsFeedWidgets.buildLoadingPage(),
            _buildCleanHeader(state, notifier),
          ],
        ),
      );
    }

    // Show error if no articles and not loading
    if (state.feedItems.isEmpty && state.error != null) {
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.black,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.news,
                    size: 64,
                    color: CupertinoColors.systemGrey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.error!,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            _buildCleanHeader(state, notifier),
          ],
        ),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Stack(
        children: [
          _buildCategoryPageView(state, notifier),
          _buildCleanHeader(state, notifier),
        ],
      ),
    );
  }

  Widget _buildCategoryPageView(NewsFeedState state, NewsFeedNotifier notifier) {
    final categories = state.availableCategories;

    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => notifier.refreshCurrentCategory(),
        ),
        SliverFillRemaining(
          child: NewsFeedPageBuilder.buildCategoryPageView(
            context,
            categories,
            _categoryPageController,
            state.selectedCategory,
            state.currentIndex,
            state.categoryCache,
            {}, // Loading states handled by notifier
            state.error ?? '',
            (newCategory) {
              // Category changed via swipe
              notifier.switchCategory(newCategory);
              _scrollToCategory(categories.indexOf(newCategory));
            },
            (index) {
              // Article index changed
              notifier.updateCurrentIndex(index);
            },
            (category) {
              // Load more articles
              notifier.loadMoreArticles();
            },
            () {
              // Load all category (not used in  MVVM)
            },
            _articlePageControllers,
            _onDemandAdAtIndex,
          ),
        ),
      ],
    );
  }

  Widget _buildCleanHeader(NewsFeedState state, NewsFeedNotifier notifier) {
    return Positioned(
      top: MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: Container(
        height: 60,
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildHorizontalCategories(state, notifier),
              ),
              const SizedBox(width: 12),
              _buildSettingsButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalCategories(NewsFeedState state, NewsFeedNotifier notifier) {
    final categories = state.availableCategories;

    return SizedBox(
      height: 40,
      child: ListView.builder(
        controller: _categoryScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == state.selectedCategory;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: () {
                notifier.switchCategory(category);
                _scrollToCategory(index);
                
                // Also update page controller
                _categoryPageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.black : Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingsButton() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 0,
      onPressed: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => const SettingsScreen(),
          ),
        );
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: const Icon(
          CupertinoIcons.settings,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  void _scrollToCategory(int index) {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && _categoryScrollController.hasClients) {
        try {
          final categories = ref.read(newsFeedNotifierProvider).availableCategories;
          CategoryScrollService.scrollToSelectedCategoryAccurate(
            context,
            _categoryScrollController,
            index,
            categories,
          );
        } catch (e) {
          AppLogger.log('ScrollController error: $e');
        }
      }
    });
  }

  /// On-demand ad loading - called by page builder when needed
  Future<void> _onDemandAdAtIndex(String category, int afterIndex) async {
    try {
      final slotKey = '$category|$afterIndex';
      if (_pendingOnDemandAds.contains(slotKey)) return;
      _pendingOnDemandAds.add(slotKey);

      // Try to get an ad
      NativeAdModel? adModel;
      adModel = await AdMobService.createBannerFallback();
      adModel ??= await AdMobService.createNativeAd();

      if (adModel != null) {
        // Insert ad into category cache via state update
        final state = ref.read(newsFeedNotifierProvider);
        final items = List.from(state.categoryCache[category] ?? []);
        final insertIndex = (afterIndex + 1).clamp(0, items.length);
        items.insert(insertIndex, adModel);

        // Update via notifier (would need to add this method)
        // For now, ads are managed separately
        AppLogger.success('📣 ON-DEMAND AD: Inserted ad after index $afterIndex in $category');
      }
    } catch (e) {
      AppLogger.error('❌ ON-DEMAND AD ERROR: $e');
    } finally {
      _pendingOnDemandAds.remove('$category|$afterIndex');
    }
  }
}