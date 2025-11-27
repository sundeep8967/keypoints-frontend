import '../models/news_article_model.dart';

abstract class NewsRemoteDataSource {
  Future<List<NewsArticleModel>> getNews({int limit = 20});
  Future<List<NewsArticleModel>> getNewsByCategory(String category, {int limit = 20});
  Future<List<NewsArticleModel>> searchNews(String query, {int limit = 20});
  Stream<List<NewsArticleModel>> getNewsStream({int limit = 20});
}

class NewsRemoteDataSourceImpl implements NewsRemoteDataSource {
  // We'll inject the actual Supabase service here
  final dynamic supabaseClient; // Will be SupabaseClient
  
  NewsRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<NewsArticleModel>> getNews({int limit = 20}) async {
    try {
      final response = await supabaseClient
          .from('news_articles')
          .select()
          .order('id', ascending: false)
          .limit(limit);

      final articles = response.map<NewsArticleModel>((json) => NewsArticleModel.fromSupabase(json)).toList();
      
      return articles;
    } catch (e) {
      throw Exception('Failed to fetch news: $e');
    }
  }

  @override
  Future<List<NewsArticleModel>> getNewsByCategory(String category, {int limit = 20}) async {
    try {
      final response = await supabaseClient
          .from('news_articles')
          .select()
          .ilike('category', category)
          .order('id', ascending: false)
          .limit(limit);

      final articles = response.map<NewsArticleModel>((json) => NewsArticleModel.fromSupabase(json)).toList();
      
      return articles;
    } catch (e) {
      throw Exception('Failed to fetch news by category: $e');
    }
  }

  @override
  Future<List<NewsArticleModel>> searchNews(String query, {int limit = 20}) async {
    try {
      final response = await supabaseClient
          .from('news_articles')
          .select()
          .or('title.ilike.%$query%,summary.ilike.%$query%')
          .order('id', ascending: false)
          .limit(limit);

      final articles = response.map<NewsArticleModel>((json) => NewsArticleModel.fromSupabase(json)).toList();
      
      return articles;
    } catch (e) {
      throw Exception('Failed to search news: $e');
    }
  }

  @override
  Stream<List<NewsArticleModel>> getNewsStream({int limit = 20}) {
    return supabaseClient
        .from('news_articles')
        .stream(primaryKey: ['id'])
        .order('id', ascending: false)
        .limit(limit)
        .map((data) {
          final articles = data.map<NewsArticleModel>((json) => NewsArticleModel.fromSupabase(json)).toList();
          
          return articles;
        });
  }
}