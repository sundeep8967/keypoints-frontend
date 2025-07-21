import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/news_article.dart';

class SupabaseService {
  static const String _supabaseUrl = 'https://sopxrwmeojcsclhokeuy.supabase.co';
  static const String _supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvcHhyd21lb2pjc2NsaG9rZXV5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk4NDAwMDMsImV4cCI6MjA2NTQxNjAwM30.3shfwkFgJPOQ_wuYvdVmIzZrNONtQiwQFoAe5tthgSQ';
  
  static SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseKey,
    );
  }

  /// Get news articles from Supabase
  static Future<List<NewsArticle>> getNews({int limit = 100}) async {
    try {
      final response = await client
          .from('news_articles')
          .select()
          .order('published', ascending: false)
          .limit(limit);

      return response.map<NewsArticle>((json) => NewsArticle.fromSupabase(json)).toList();
    } catch (e) {
      print('Error fetching news from Supabase: $e');
      return [];
    }
  }

  /// Get news articles stream for real-time updates
  static Stream<List<NewsArticle>> getNewsStream({int limit = 50}) {
    return client
        .from('news_articles')
        .stream(primaryKey: ['id'])
        .order('published', ascending: false)
        .limit(limit)
        .map((data) => data.map<NewsArticle>((json) => NewsArticle.fromSupabase(json)).toList());
  }

  /// Add a news article to Supabase
  static Future<bool> addNews(NewsArticle article) async {
    try {
      await client.from('news_articles').insert(article.toSupabaseMap());
      return true;
    } catch (e) {
      print('Error adding news to Supabase: $e');
      return false;
    }
  }

  /// Update a news article in Supabase
  static Future<bool> updateNews(NewsArticle article) async {
    try {
      await client
          .from('news_articles')
          .update(article.toSupabaseMap())
          .eq('id', article.id);
      return true;
    } catch (e) {
      print('Error updating news in Supabase: $e');
      return false;
    }
  }

  /// Delete a news article from Supabase
  static Future<bool> deleteNews(String articleId) async {
    try {
      await client.from('news_articles').delete().eq('id', articleId);
      return true;
    } catch (e) {
      print('Error deleting news from Supabase: $e');
      return false;
    }
  }

  /// Get news by category
  static Future<List<NewsArticle>> getNewsByCategory(String category, {int limit = 50}) async {
    try {
      final response = await client
          .from('news_articles')
          .select()
          .ilike('category', category)
          .order('published', ascending: false)
          .limit(limit);

      return response.map<NewsArticle>((json) => NewsArticle.fromSupabase(json)).toList();
    } catch (e) {
      print('Error fetching news by category from Supabase: $e');
      return [];
    }
  }

  /// Get unread news by category (excludes read article IDs)
  static Future<List<NewsArticle>> getUnreadNewsByCategory(String category, List<String> readIds, {int limit = 100}) async {
    try {
      var query = client
          .from('news_articles')
          .select()
          .ilike('category', category);
      
      // Exclude read articles if we have any - use neq for each ID or filter client-side
      if (readIds.isNotEmpty) {
        // For now, let's fetch more and filter client-side since Supabase syntax is tricky
        final response = await query
            .order('published', ascending: false)
            .limit(limit * 3); // Fetch more to account for filtering
            
        final allArticles = response.map<NewsArticle>((json) => NewsArticle.fromSupabase(json)).toList();
        
        // Filter out read articles client-side
        final unreadArticles = allArticles.where((article) => 
          !readIds.contains(article.id)
        ).take(limit).toList();
        
        return unreadArticles;
      } else {
        final response = await query
            .order('published', ascending: false)
            .limit(limit);
            
        return response.map<NewsArticle>((json) => NewsArticle.fromSupabase(json)).toList();
      }
    } catch (e) {
      print('Error fetching unread news by category from Supabase: $e');
      return [];
    }
  }

  /// Search news articles
  static Future<List<NewsArticle>> searchNews(String query, {int limit = 50}) async {
    try {
      final response = await client
          .from('news_articles')
          .select()
          .or('title.ilike.%$query%,summary.ilike.%$query%')
          .order('published', ascending: false)
          .limit(limit);

      return response.map<NewsArticle>((json) => NewsArticle.fromSupabase(json)).toList();
    } catch (e) {
      print('Error searching news in Supabase: $e');
      return [];
    }
  }
}