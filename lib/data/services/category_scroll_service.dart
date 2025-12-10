import 'package:flutter/material.dart';
import '../../core/utils/app_logger.dart';
class CategoryScrollService {
  static void scrollToSelectedCategoryAccurate(
    BuildContext context,
    ScrollController categoryScrollController,
    int categoryIndex,
    List<String> categories,
  ) {
    // Add safety checks and delay to ensure ScrollController is ready
    if (!categoryScrollController.hasClients) {
      // Try again after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (categoryScrollController.hasClients) {
          scrollToSelectedCategoryAccurate(context, categoryScrollController, categoryIndex, categories);
        }
      });
      return;
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!categoryScrollController.hasClients) return;
      
      try {
        final double screenWidth = MediaQuery.of(context).size.width;
        final double spacing = 8.0; // Space between items
        final double padding = 20.0; // Left padding
        
        // Calculate cumulative position by measuring each category
        double itemPosition = padding;
        for (int i = 0; i < categoryIndex; i++) {
          final double itemWidth = _estimateCategoryWidth(categories[i]);
          itemPosition += itemWidth + spacing;
        }
        
        // Get current category width
        final double currentItemWidth = _estimateCategoryWidth(categories[categoryIndex]);
        
        final double currentScroll = categoryScrollController.position.pixels;
        final double maxScroll = categoryScrollController.position.maxScrollExtent;
        
        // Calculate visible area
        final double visibleStart = currentScroll;
        final double visibleEnd = currentScroll + screenWidth - 40;
        
        double targetScroll = currentScroll;
        
        // If category is going off-screen to the RIGHT, scroll right
        if (itemPosition + currentItemWidth > visibleEnd) {
          targetScroll = itemPosition + currentItemWidth - screenWidth + 60;
        }
        // If category is off-screen to the LEFT, scroll left
        else if (itemPosition < visibleStart + 40) {
          targetScroll = itemPosition - 60;
        }
        
        // Ensure we stay within bounds
        targetScroll = targetScroll.clamp(0.0, maxScroll);
        
        AppLogger.log('Category "${categories[categoryIndex]}" ($categoryIndex): pos=$itemPosition, width=$currentItemWidth, visible=$visibleStart-$visibleEnd, scroll=$currentScroll->$targetScroll');
        
        // Only animate if we need to scroll significantly
        if ((targetScroll - currentScroll).abs() > 10) {
          categoryScrollController.animateTo(
            targetScroll,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      } catch (e) {
        AppLogger.log('Scroll error: $e');
      }
    });
  }

  static void scrollToSelectedCategory(
    BuildContext context,
    ScrollController categoryScrollController,
    int categoryIndex,
  ) {
    // Add delay to ensure the scroll controller is ready
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!categoryScrollController.hasClients) {
        AppLogger.log('ScrollController not ready yet');
        return;
      }
      
      try {
        // Get current scroll position and viewport info
        final double currentPosition = categoryScrollController.position.pixels;
        final double viewportWidth = categoryScrollController.position.viewportDimension;
        final double maxScroll = categoryScrollController.position.maxScrollExtent;
        
        // Calculate item position more accurately
        const double itemWidth = 90.0; // Wider estimate for category pills
        const double itemSpacing = 8.0; // Space between pills
        const double leftPadding = 20.0; // Initial padding
        
        // Calculate where the selected category starts
        final double itemStartPosition = leftPadding + (categoryIndex * (itemWidth + itemSpacing));
        final double itemEndPosition = itemStartPosition + itemWidth;
        
        // Check if item is already visible
        final double visibleStart = currentPosition;
        final double visibleEnd = currentPosition + viewportWidth;
        
        double targetScroll = currentPosition;
        
        // If item is off-screen to the right, scroll to show it
        if (itemEndPosition > visibleEnd) {
          targetScroll = itemEndPosition - viewportWidth + 40; // 40px margin
        }
        // If item is off-screen to the left, scroll to show it  
        else if (itemStartPosition < visibleStart) {
          targetScroll = itemStartPosition - 40; // 40px margin
        }
        
        // Ensure we don't scroll beyond bounds
        targetScroll = targetScroll.clamp(0.0, maxScroll);
        
        AppLogger.log('Category $categoryIndex: start=$itemStartPosition, end=$itemEndPosition, visible=$visibleStart-$visibleEnd, scrollTo=$targetScroll');
        
        // Only scroll if we need to
        if ((targetScroll - currentPosition).abs() > 5) {
          categoryScrollController.animateTo(
            targetScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      } catch (e) {
        AppLogger.log('Error scrolling to category: $e');
      }
    });
  }

  /// Estimate category pill width based on text length
  static double _estimateCategoryWidth(String category) {
    // Approximate: 8 pixels per character + 32 pixels padding
    return (category.length * 8.0) + 32.0;
  }
}