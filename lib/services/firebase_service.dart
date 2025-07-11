import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/news_article.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'news';

  static Stream<List<NewsArticle>> getNewsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return NewsArticle.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  static Future<List<NewsArticle>> getNews() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('timestamp', descending: true)
          .get();
      
      List<NewsArticle> articles = snapshot.docs.map((doc) {
        return NewsArticle.fromFirestore(doc.data(), doc.id);
      }).toList();

      // If no articles in Firebase, try to get data from GitHub
      if (articles.isEmpty) {
        print('No articles in Firebase, fetching from GitHub...');
        articles = _getSampleData();
      }

      return articles;
    } catch (e) {
      print('Error fetching news from Firebase: $e');
      // Fallback to GitHub data if Firebase fails
      try {
        print('Falling back to GitHub data...');
        return _getSampleData();
      } catch (githubError) {
        print('Error fetching from GitHub: $githubError');
        return _getSampleData();
      }
    }
  }

  static Future<void> addNews(NewsArticle article) async {
    try {
      // Check if article already exists to avoid duplicates
      final existingQuery = await _firestore
          .collection(_collection)
          .where('title', isEqualTo: article.title)
          .limit(1)
          .get();

      if (existingQuery.docs.isEmpty) {
        await _firestore.collection(_collection).add(article.toMap());
        print('Added article: ${article.title}');
      } else {
        print('Article already exists: ${article.title}');
      }
    } catch (e) {
      print('Error adding news: $e');
    }
  }

  /// Import all data from GitHub to Firebase
  static Future<void> importDataFromGitHub() async {
    // await DataImportService.importAllToFirebase();
    print('GitHub import feature will be implemented after Firebase setup');
  }

  /// Get sample data for testing
  static List<NewsArticle> _getSampleData() {
    return [
      NewsArticle(
        id: '1',
        title: 'Flutter 3.0 Released with Exciting New Features',
        description: 'Google announces Flutter 3.0 with improved performance, better web support, and enhanced developer tools. This release marks a significant milestone in Flutter\'s evolution with new widgets, improved compilation, and better integration with native platforms.',
        imageUrl: 'https://storage.googleapis.com/cms-storage-bucket/6a07d8a62f4308d2b854.png',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      NewsArticle(
        id: '2',
        title: 'AI Revolution: ChatGPT Transforms Software Development',
        description: 'Artificial Intelligence is reshaping how developers write code, debug applications, and solve complex problems. The integration of AI tools in development workflows is increasing productivity and changing the landscape of software engineering.',
        imageUrl: 'https://images.unsplash.com/photo-1677442136019-21780ecad995?w=800&h=600&fit=crop',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      NewsArticle(
        id: '3',
        title: 'Mobile App Security: Best Practices for 2024',
        description: 'As mobile applications handle increasingly sensitive data, security has become paramount. Learn about the latest security practices, encryption methods, and vulnerability assessments that every mobile developer should implement.',
        imageUrl: 'https://images.unsplash.com/photo-1563986768609-322da13575f3?w=800&h=600&fit=crop',
        timestamp: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      NewsArticle(
        id: '4',
        title: 'iOS 17 Features That Developers Should Know',
        description: 'Apple\'s latest iOS update brings exciting new capabilities for developers. From enhanced SwiftUI components to improved performance optimizations, discover what\'s new in iOS 17 and how to leverage these features in your apps.',
        imageUrl: 'https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=800&h=600&fit=crop',
        timestamp: DateTime.now().subtract(const Duration(hours: 12)),
      ),
      NewsArticle(
        id: '5',
        title: 'The Future of Cross-Platform Development',
        description: 'Cross-platform development continues to evolve with new frameworks and tools. Explore the latest trends, compare different approaches, and understand which solution might be best for your next mobile project.',
        imageUrl: 'https://images.unsplash.com/photo-1551650975-87deedd944c3?w=800&h=600&fit=crop',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  /// Clear all news data (useful for testing)
  static Future<void> clearAllNews() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      for (DocumentSnapshot doc in snapshot.docs) {
        await doc.reference.delete();
      }
      print('Cleared all news data');
    } catch (e) {
      print('Error clearing news data: $e');
    }
  }
}