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
          .order('published', ascending: false)
          .limit(limit);

      final articles = response.map<NewsArticleModel>((json) => NewsArticleModel.fromSupabase(json)).toList();
      
      // Sort by quality score after fetching (highest quality first)
      articles.sort((a, b) {
        final scoreA = a.score ?? 0.0;
        final scoreB = b.score ?? 0.0;
        return scoreB.compareTo(scoreA); // Descending order (highest first)
      });
      
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
          .order('published', ascending: false)
          .limit(limit);

      final articles = response.map<NewsArticleModel>((json) => NewsArticleModel.fromSupabase(json)).toList();
      
      // Sort by quality score after fetching (highest quality first)
      articles.sort((a, b) {
        final scoreA = a.score ?? 0.0;
        final scoreB = b.score ?? 0.0;
        return scoreB.compareTo(scoreA); // Descending order (highest first)
      });
      
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
          .order('published', ascending: false)
          .limit(limit);

      final articles = response.map<NewsArticleModel>((json) => NewsArticleModel.fromSupabase(json)).toList();
      
      // Sort by quality score after fetching (highest quality first)
      articles.sort((a, b) {
        final scoreA = a.score ?? 0.0;
        final scoreB = b.score ?? 0.0;
        return scoreB.compareTo(scoreA); // Descending order (highest first)
      });
      
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
        .order('published', ascending: false)
        .limit(limit)
        .map((data) {
          final articles = data.map<NewsArticleModel>((json) => NewsArticleModel.fromSupabase(json)).toList();
          
          // Sort by quality score after fetching (highest quality first)
          articles.sort((a, b) {
            final scoreA = a.score ?? 0.0;
            final scoreB = b.score ?? 0.0;
            return scoreB.compareTo(scoreA); // Descending order (highest first)
          });
          
          return articles;
        });
  }
}