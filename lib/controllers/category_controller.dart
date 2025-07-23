import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import '../services/news_ui_service.dart';
import '../services/category_scroll_service.dart';

class CategoryController extends ChangeNotifier {
  String _selectedCategory = 'All';
  late PageController _pageController;
  late ScrollController _scrollController;
  final List<GlobalKey> _categoryKeys = [];

  // Getters
  String get selectedCategory => _selectedCategory;
  PageController get pageController => _pageController;
  ScrollController get scrollController => _scrollController;
  List<GlobalKey> get categoryKeys => _categoryKeys;
  List<String> get categories => NewsUIService.getInitializeCategories();

  CategoryController() {
    _initializeControllers();
  }

  void _initializeControllers() {
    final categories = NewsUIService.getInitializeCategories();
    
    // Initialize page controller
    final currentCategoryIndex = categories.indexOf(_selectedCategory);
    _pageController = PageController(
      initialPage: currentCategoryIndex >= 0 ? currentCategoryIndex : 0
    );
    
    // Initialize scroll controller for horizontal pills
    _scrollController = ScrollController();
    
    // Initialize category keys
    _categoryKeys.clear();
    for (int i = 0; i < categories.length; i++) {
      _categoryKeys.add(GlobalKey());
    }
  }

  /// Select a category and handle navigation
  void selectCategory(String category, {Function(String)? onCategoryChanged}) {
    final categories = NewsUIService.getInitializeCategories();
    
    final categoryIndex = categories.indexOf(category);
    if (categoryIndex != -1) {
      _pageController.animateToPage(
        categoryIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    
    _selectedCategory = category;
    notifyListeners();
    
    // Notify parent about category change
    onCategoryChanged?.call(category);
    
    print('CategoryController: Switched to $category');
  }

  /// Handle category tap with scroll animation
  void onCategoryTapped(String category, int index, BuildContext context, 
      {Function(String)? onCategoryChanged}) {
    selectCategory(category, onCategoryChanged: onCategoryChanged);
    
    // Scroll to tapped category with delay
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        try {
          final categories = NewsUIService.getInitializeCategories();
          CategoryScrollService.scrollToSelectedCategoryAccurate(
            context, _scrollController, index, categories);
        } catch (e) {
          print('CategoryController: ScrollController error on tap: $e');
        }
      }
    });
  }

  /// Get categories with detected states from articles
  List<String> getCategoriesWithStates(List<dynamic> articles) {
    final baseCategories = NewsUIService.getHorizontalCategories();
    // Note: This would need to be implemented based on your article structure
    // For now, returning base categories
    return baseCategories;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}