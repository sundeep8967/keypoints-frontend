import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/news_article.dart';
import 'firebase_service.dart';

class DataImportService {
  static const String githubApiBase = 'https://api.github.com/repos/sundeep8967/keypoints-backend/contents/data';
  static const String githubRawBase = 'https://raw.githubusercontent.com/sundeep8967/keypoints-backend/main/data';

  /// Fetch list of JSON files from GitHub repository
  static Future<List<String>> getDataFiles() async {
    try {
      print('Fetching data files from GitHub...');
      final response = await http.get(Uri.parse(githubApiBase));
      
      if (response.statusCode == 200) {
        final List<dynamic> files = json.decode(response.body);
        final jsonFiles = files
            .where((file) => file['name'].toString().endsWith('.json'))
            .map((file) => file['name'].toString())
            .toList();
        
        print('Found JSON files: $jsonFiles');
        return jsonFiles;
      } else {
        print('Failed to access data folder: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching data files: $e');
      return [];
    }
  }

  /// Import news data from a specific JSON file
  static Future<List<NewsArticle>> importFromFile(String fileName) async {
    try {
      final url = '$githubRawBase/$fileName';
      print('Fetching data from: $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final dynamic jsonData = json.decode(response.body);
        
        // Handle your specific data format
        List<dynamic> articles;
        if (jsonData is Map && jsonData.containsKey('articles')) {
          articles = jsonData['articles'];
        } else if (jsonData is List) {
          articles = jsonData;
        } else {
          // Assume it's a single article
          articles = [jsonData];
        }

        return articles.map((articleData) => _parseArticle(articleData)).toList();
      }
      return [];
    } catch (e) {
      print('Error importing from file $fileName: $e');
      return [];
    }
  }

  /// Import all news data from GitHub and save to Firebase
  static Future<void> importAllToFirebase() async {
    try {
      final files = await getDataFiles();
      print('Found ${files.length} data files');

      for (String file in files) {
        print('Importing $file...');
        final articles = await importFromFile(file);
        
        for (NewsArticle article in articles) {
          await FirebaseService.addNews(article);
        }
        
        print('Imported ${articles.length} articles from $file');
      }
      
      print('Import completed successfully!');
    } catch (e) {
      print('Error during import: $e');
    }
  }

  /// Parse article data from your specific format
  static NewsArticle _parseArticle(Map<String, dynamic> data) {
    // Handle your specific data format
    String title = data['title'] ?? 'No Title';
    String description = data['summary'] ?? data['description'] ?? '';
    String imageUrl = data['image_url'] ?? data['image'] ?? 'https://via.placeholder.com/800x600/E0E0E0/808080?text=No+Image';
    
    // Handle timestamp - your format uses 'published'
    DateTime timestamp;
    try {
      if (data['published'] != null) {
        timestamp = DateTime.parse(data['published']);
      } else {
        timestamp = DateTime.now();
      }
    } catch (e) {
      timestamp = DateTime.now();
    }

    return NewsArticle(
      id: data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      imageUrl: imageUrl,
      timestamp: timestamp,
    );
  }

  /// Get sample data directly from GitHub for testing
  static Future<List<NewsArticle>> getSampleData() async {
    try {
      final files = await getDataFiles();
      if (files.isNotEmpty) {
        // Get data from the first file as sample
        return await importFromFile(files.first);
      }
      return [];
    } catch (e) {
      print('Error getting sample data: $e');
      return [];
    }
  }
}