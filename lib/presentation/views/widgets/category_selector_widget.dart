import 'package:flutter/cupertino.dart';

class CategorySelectorWidget extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final Function(String) onCategorySelected;
  final ScrollController scrollController;
  final List<GlobalKey> categoryKeys;

  const CategorySelectorWidget({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.scrollController,
    required this.categoryKeys,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListView.builder(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;
          
          return Container(
            key: categoryKeys.length > index ? categoryKeys[index] : null,
            margin: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => onCategorySelected(category),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected 
                    ? CupertinoColors.white 
                    : const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(25),
                  border: isSelected 
                    ? null 
                    : Border.all(color: const Color(0xFF3C3C3E), width: 1),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected 
                      ? CupertinoColors.black 
                      : CupertinoColors.white,
                    fontSize: 14,
                    fontWeight: isSelected 
                      ? FontWeight.w600 
                      : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}