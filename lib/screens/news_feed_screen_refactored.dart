import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/news_article.dart';
import '../controllers/news_feed_controller.dart';
import '../controllers/category_controller.dart';
import '../widgets/category_selector_widget.dart';
import '../widgets/news_card_stack.dart';
import '../widgets/loading_shimmer.dart';
import '../services/consolidated/news_facade.dart';
import 'settings_screen.dart';

class NewsFeedScreenRefactored extends StatefulWidget {
  const NewsFeedScreenRefactored({super.key});

  @override
  State<NewsFeedScreenRefactored> createState() => _NewsFeedScreenRefactoredState();
}

class _NewsFeedScreenRefactoredState extends State<NewsFeedScreenRefactored> 
    with TickerProviderStateMixin {
  
  late NewsFeedController _newsController;
  late CategoryController _categoryController;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadInitialData();
  }

  void _initializeControllers() {
    _newsController = NewsFeedController();
    _categoryController = CategoryController();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Listen to controller changes
    _newsController.addListener(_onNewsControllerChanged);
    _categoryController.addListener(_onCategoryControllerChanged);
  }

  void _loadInitialData() {
    // Load "All" category initially
    _newsController.loadAllCategoryArticles();
  }

  void _onNewsControllerChanged() {
    // Handle news controller state changes
    if (mounted) {
      setState(() {});
    }
  }

  void _onCategoryControllerChanged() {
    // Handle category controller state changes
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _newsController.removeListener(_onNewsControllerChanged);
    _categoryController.removeListener(_onCategoryControllerChanged);
    _newsController.dispose();
    _categoryController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildCategorySelector(),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'News',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.white,
            ),
          ),
          Row(
            children: [
              _buildRefreshButton(),
              const SizedBox(width: 12),
              _buildSettingsButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 0,
      onPressed: _handleRefresh,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          CupertinoIcons.refresh,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildSettingsButton() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 0,
      onPressed: _openSettings,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          CupertinoIcons.settings,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return CategorySelectorWidget(
      categories: _categoryController.categories,
      selectedCategory: _categoryController.selectedCategory,
      onCategorySelected: _handleCategorySelection,
      scrollController: _categoryController.scrollController,
      categoryKeys: _categoryController.categoryKeys,
    );
  }

  Widget _buildContent() {
    if (_newsController.isLoading) {
      return const LoadingShimmer();
    }

    if (_newsController.error.isNotEmpty) {
      return _buildErrorState();
    }

    return NewsCardStack(
      articles: _newsController.articles,
      currentIndex: _newsController.currentIndex,
      colorCache: _newsController.colorCache,
      onIndexChanged: _handleIndexChanged,
      onArticleRead: _handleArticleRead,
      onArticleShare: _handleArticleShare,
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 60,
            color: CupertinoColors.systemRed,
          ),
          const SizedBox(height: 20),
          Text(
            'Error Loading News',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _newsController.error,
            style: const TextStyle(
              fontSize: 16,
              color: CupertinoColors.systemGrey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          CupertinoButton(
            onPressed: _handleRefresh,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Event Handlers
  void _handleCategorySelection(String category) {
    _categoryController.selectCategory(category, onCategoryChanged: (selectedCategory) {
      if (selectedCategory == 'All') {
        _newsController.loadAllCategoryArticles();
      } else {
        _newsController.loadCategoryArticles(selectedCategory);
      }
    });
  }

  void _handleIndexChanged(int index) {
    _newsController.updateCurrentIndex(index);
  }

  void _handleArticleRead(NewsArticle article) {
    _newsController.markArticleAsRead(article);
    _showToast('Article marked as read');
  }

  void _handleArticleShare(NewsArticle article) {
    // Implement share functionality
    _showToast('Sharing: ${article.title}');
  }

  void _handleRefresh() {
    HapticFeedback.lightImpact();
    _newsController.clearCaches();
    
    if (_categoryController.selectedCategory == 'All') {
      _newsController.loadAllCategoryArticles();
    } else {
      _newsController.loadCategoryArticles(_categoryController.selectedCategory);
    }
    
    _showToast('Refreshing news...');
  }

  void _openSettings() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _showToast(String message) {
    NewsFacade().showToast(context, message);
  }
}