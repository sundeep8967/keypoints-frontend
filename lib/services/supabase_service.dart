import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/entities/news_article_entity.dart';
import '../config/app_config.dart';

import '../utils/app_logger.dart';
/// Service class for handling all Supabase database operations.
/// 
/// This service provides methods for fetching, adding, updating, and deleting
/// news articles from the Supabase database. It includes proper error handling
/// and caching mechanisms for optimal performance.
class SupabaseService {
  /// Gets the current Supabase client instance.
  static SupabaseClient get client => Supabase.instance.client;

  /// Initializes Supabase with secure configuration.
  /// 
  /// Attempts to use environment variables first, then falls back to
  /// development credentials for local development. Throws an exception
  /// if no valid credentials are found.
  /// 
  /// Throws:
  /// * [Exception] if Supabase credentials are not configured
  /// * [Exception] if initialization fails
  static Future<void> initialize() async {
    try {
      // Try to use environment variables first
      if (AppConfig.isConfigured) {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          anonKey: AppConfig.supabaseAnonKey,
        );
        AppLogger.success(' Supabase initialized with environment credentials');
      } else if (AppConfig.isUsingDevCredentials) {
        // Fallback to development credentials (local development only)
        await Supabase.initialize(
          url: AppConfig.devSupabaseUrl,
          anonKey: AppConfig.devSupabaseAnonKey,
        );
        AppLogger.warning(' Supabase initialized with development credentials');
        AppLogger.log('🔒 WARNING: Configure environment variables for production');
      } else {
        throw Exception(
          'Supabase credentials not configured. Please set SUPABASE_URL and SUPABASE_ANON_KEY environment variables.'
        );
      }
    } catch (e) {
      AppLogger.error(' Supabase initialization failed: $e');
      rethrow;
    }
  }

  /// Fetches news articles from the Supabase database.
  /// 
  /// Retrieves articles ordered by publication date (newest first).
  /// Includes comprehensive error handling for network and database issues.
  /// 
  /// Parameters:
  /// * [limit] - Maximum number of articles to fetch (default: 100)
  /// 
  /// Returns:
  /// * A [Future<List<NewsArticle>>] containing the fetched articles
  /// 
  /// Throws:
  /// * [Exception] with "No articles found" if database is empty
  /// * [Exception] with "Database error" for Supabase-specific issues
  /// * [Exception] with "Network connection failed" for connectivity issues
  /// * [Exception] with "Failed to load news articles" for other errors
  static Future<List<NewsArticleEntity>> getNews({int limit = 1000}) async {
    try {
      final response = await client
          .from('news_articles')
          .select()
          .order('id', ascending: false)
          .limit(limit);

      if (response.isEmpty) {
        throw Exception('NO_ARTICLES_IN_DATABASE');
      }

      final articles = response.map<NewsArticleEntity>((json) => NewsArticleEntity.fromSupabase(json)).toList();
      
      // LOG RAW SUPABASE ARTICLE IDS (first 5)
      if (articles.isNotEmpty) {
        AppLogger.log('🗄️ RAW SUPABASE IDs (latest ${articles.length > 5 ? 5 : articles.length} from DB):');
        for (int i = 0; i < articles.length && i < 5; i++) {
          AppLogger.log('  ${i+1}. ${articles[i].id}');
        }
      }
      
      return articles;
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } on SocketException catch (e) {
      throw Exception('Network connection failed. Please check your internet connection.');
    } catch (e) {
      throw Exception('Failed to load news articles: ${e.toString()}');
    }
  }

  /// Get news articles stream for real-time updates
  static Stream<List<NewsArticleEntity>> getNewsStream({int limit = 50}) {
    return client
        .from('news_articles')
        .stream(primaryKey: ['id'])
        .order('id', ascending: false)
        .limit(limit)
        .map((data) {
          final articles = data.map<NewsArticleEntity>((json) => NewsArticleEntity.fromSupabase(json)).toList();
          return articles;
        });
  }

  /// Add a news article to Supabase
  static Future<bool> addNews(NewsArticleEntity article) async {
    try {
      await client.from('news_articles').insert(article.toSupabaseMap());
      return true;
    } catch (e) {
      AppLogger.log('Error adding news to Supabase: $e');
      return false;
    }
  }

  /// Update a news article in Supabase
  static Future<bool> updateNews(NewsArticleEntity article) async {
    try {
      await client
          .from('news_articles')
          .update(article.toSupabaseMap())
          .eq('id', article.id);
      return true;
    } catch (e) {
      AppLogger.log('Error updating news in Supabase: $e');
      return false;
    }
  }

  /// Delete a news article from Supabase
  static Future<bool> deleteNews(String articleId) async {
    try {
      await client.from('news_articles').delete().eq('id', articleId);
      return true;
    } catch (e) {
      AppLogger.log('Error deleting news from Supabase: $e');
      return false;
    }
  }

  /// Fetches news articles filtered by category.
  /// 
  /// Retrieves articles from a specific category, ordered by publication date.
  /// Performs case-insensitive category matching.
  /// 
  /// Parameters:
  /// * [category] - The category to filter by (cannot be empty)
  /// * [limit] - Maximum number of articles to fetch (default: 50)
  /// 
  /// Returns:
  /// * A [Future<List<NewsArticle>>] containing articles from the specified category
  /// 
  /// Throws:
  /// * [ArgumentError] if category is empty or null
  /// * [Exception] with "Database error" for Supabase-specific issues
  /// * [Exception] with "Network connection failed" for connectivity issues
  /// * [Exception] with "Failed to load [category] articles" for other errors
  static Future<List<NewsArticleEntity>> getNewsByCategory(String category, {int limit = 500}) async {
    if (category.trim().isEmpty) {
      throw ArgumentError('Category cannot be empty');
    }

    try {
      final response = await client
          .from('news_articles')
          .select()
          .ilike('category', category)
          .order('id', ascending: false)
          .limit(limit);

      final articles = response.map<NewsArticleEntity>((json) => NewsArticleEntity.fromSupabase(json)).toList();
      return articles;
    } on PostgrestException catch (e) {
      throw Exception('Database error while fetching $category articles: ${e.message}');
    } on SocketException catch (e) {
      throw Exception('Network connection failed. Please check your internet connection.');
    } catch (e) {
      throw Exception('Failed to load $category articles: ${e.toString()}');
    }
  }

  /// Get unread news by category (excludes read article IDs)
  static Future<List<NewsArticleEntity>> getUnreadNewsByCategory(String category, List<String> readIds, {int limit = 1000, int offset = 0}) async {
    if (category.trim().isEmpty) {
      throw ArgumentError('Category cannot be empty');
    }

    if (limit <= 0) {
      throw ArgumentError('Limit must be greater than 0');
    }

    if (offset < 0) {
      throw ArgumentError('Offset must be greater than or equal to 0');
    }

    try {
      var query = client
          .from('news_articles')
          .select()
          .ilike('category', category);
      
      // Exclude read articles if we have any - use neq for each ID or filter client-side
      if (readIds.isNotEmpty) {
        // Fetch more and filter client-side since Supabase syntax is tricky
        // Increase fetch size to account for filtering and offset - use much larger multiplier
        final fetchLimit = (limit * 10) + offset;
        final response = await query
            .order('id', ascending: false)
            .limit(fetchLimit);
            
        final allArticles = response.map<NewsArticleEntity>((json) => NewsArticleEntity.fromSupabase(json)).toList();
        
        // Filter out read articles client-side
        final unreadArticles = allArticles.where((article) => 
          !readIds.contains(article.id)
        ).toList();
        
        // Apply offset and limit after filtering
        final paginatedArticles = unreadArticles.skip(offset).take(limit).toList();
        return paginatedArticles;
      } else {
        final response = await query
            .order('id', ascending: false)
            .range(offset, offset + limit - 1); // Use Supabase range for pagination
            
        final articles = response.map<NewsArticleEntity>((json) => NewsArticleEntity.fromSupabase(json)).toList();
        return articles;
      }
    } on PostgrestException catch (e) {
      throw Exception('Database error while fetching unread $category articles: ${e.message}');
    } on SocketException catch (e) {
      throw Exception('Network connection failed. Please check your internet connection.');
    } on FormatException catch (e) {
      throw Exception('Invalid data format received from server: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load unread $category articles: ${e.toString()}');
    }
  }

  /// Search news articles
  static Future<List<NewsArticleEntity>> searchNews(String query, {int limit = 50}) async {
    try {
      final response = await client
          .from('news_articles')
          .select()
          .or('title.ilike.%$query%,summary.ilike.%$query%')
          .order('id', ascending: false)
          .limit(limit);

      final articles = response.map<NewsArticleEntity>((json) => NewsArticleEntity.fromSupabase(json)).toList();
      return articles;
    } catch (e) {
      AppLogger.log('Error searching news in Supabase: $e');
      return [];
    }
  }
}