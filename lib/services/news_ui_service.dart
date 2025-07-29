import 'package:flutter/cupertino.dart';

class NewsUIService {
  static void showToast(BuildContext context, String message, {VoidCallback? onDismiss}) {
    print('TOAST: $message');
    
    // Show a Cupertino-style alert dialog for better visibility
    if (context.mounted) {
      showCupertinoDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text('Info'),
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  onDismiss?.call();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      
      // Auto-dismiss after 3 seconds and handle category switch
      Future.delayed(const Duration(seconds: 3), () {
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
          onDismiss?.call();
        }
      });
    }
  }

  /// Legacy method - use getCategories() instead
  @deprecated
  static List<String> getBaseCategories() => getCategories();

  /// Single source of truth for all categories
  /// This prevents navigation mismatches and gesture crashes
  static List<String> getCategories() {
    return [
      'All',
      'Tech',
      'Science',
      'Business',
      'Entertainment',
      'Health',
      'Sports',
      'World',
      'Trending',
      'Viral',        // 25 articles - ADDED
      'Celebrity',    // 20 articles - ADDED
      'Scandal',      // 15 articles - ADDED
      'India',        // ADDED
      'State',        // ADDED
      'Environment'
    ];
  }

  /// Get categories for horizontal pills (same as main categories)
  static List<String> getHorizontalCategories() => getCategories();

  /// Get categories for initialization (same as main categories)
  static List<String> getInitializeCategories() => getCategories();

  /// Get categories for selection (same as main categories)
  static List<String> getSelectCategories() => getCategories();

  /// Get categories for preloading (same as main categories)
  static List<String> getPreloadCategories() => getCategories();

  static List<String> getPopularCategories() {
    // Pre-load the most commonly accessed categories
    return ['Sports', 'Trending', 'Science', 'Tech', 'Viral', 'Celebrity'];
  }
}