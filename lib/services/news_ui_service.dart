import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

  static List<String> getBaseCategories() {
    return [
      'All',
      'Sports',      // 58 articles
      'Top',         // 56 articles  
      'Trending',    // 53 articles
      'Science',     // 51 articles
      'World',       // 51 articles
      'Health',      // 49 articles
      'Business',    // 47 articles
      'Tech',        // 46 articles
      'Entertainment', // 35 articles
      'Travel',      // 9 articles
      'Startups',    // 6 articles
      'Politics',    // 5 articles
      'National',    // 5 articles
      'India',       // 5 articles
      'Education',   // 5 articles
      'Celebrity',   // New category
      'Scandal',     // New category
      'Viral',       // New category
    ];
  }

  static List<String> getHorizontalCategories() {
    return [
      'All',
      'Sports', 'Top', 'Trending', 'Science', 'World', 'Health', 'Business', 
      'Tech', 'Entertainment', 'Travel', 'Startups', 'Politics', 'National', 
      'India', 'Education', 'Celebrity', 'Scandal', 'Viral'
    ];
  }

  static List<String> getInitializeCategories() {
    return [
      'All',
      'Tech',
      'Science',
      'Environment',
      'Energy',
      'Lifestyle',
      'Business',
      'Entertainment',
      'Health',
      'Sports',
      'World',
      'Trending'
    ];
  }

  static List<String> getSelectCategories() {
    return [
      'All',
      'Tech',
      'Science',
      'Environment',
      'Energy',
      'Lifestyle',
      'Business',
      'Entertainment',
      'Health',
      'Sports',
      'World',
      'Trending'
    ];
  }

  static List<String> getPreloadCategories() {
    return [
      'All',
      'Tech',
      'Science',
      'Environment',
      'Energy',
      'Lifestyle',
      'Business',
      'Entertainment',
      'Health',
      'Sports',
      'World',
      'Trending'
    ];
  }

  static List<String> getPopularCategories() {
    // Pre-load the most commonly accessed categories
    return ['Sports', 'Top', 'Trending', 'Science', 'Tech'];
  }
}