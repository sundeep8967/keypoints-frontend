import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_article_model.dart';
import '../../services/read_articles_service.dart';

abstract class NewsLocalDataSource {
  Future<List<NewsArticleModel>> getCachedNews();
  Future<void> cacheNews(List<NewsArticleModel> articles);
  Future<void> markArticleAsRead(String articleId);
  Future<bool> isArticleRead(String articleId);
  Future<List<String>> getReadArticleIds();
  Future<void> clearCache();
}

class NewsLocalDataSourceImpl implements NewsLocalDataSource {
  static const String _articlesKey = 'cached_news_articles';
  // Deprecated: use ReadArticlesService for read IDs storage to avoid key mismatch
  // static const String _readArticlesKey = 'read_articles';
  static const String _lastFetchKey = 'last_fetch_timestamp';

  @override
  Future<List<NewsArticleModel>> getCachedNews() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final articlesJson = prefs.getString(_articlesKey);
      
      if (articlesJson == null) return [];
      
      final List<dynamic> articlesList = json.decode(articlesJson);
      return articlesList.map((json) => NewsArticleModel.fromCache(json)).toList();
    } catch (e) {
      throw Exception('Failed to get cached news: $e');
    }
  }

  @override
  Future<void> cacheNews(List<NewsArticleModel> articles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final articlesJson = articles.map((article) => article.toCacheMap()).toList();
      await prefs.setString(_articlesKey, json.encode(articlesJson));
      await prefs.setInt(_lastFetchKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      throw Exception('Failed to cache news: $e');
    }
  }

  @override
  Future<void> markArticleAsRead(String articleId) async {
    try {
      await ReadArticlesService.markAsRead(articleId);
    } catch (e) {
      throw Exception('Failed to mark article as read: $e');
    }
  }

  @override
  Future<bool> isArticleRead(String articleId) async {
    try {
      return await ReadArticlesService.isRead(articleId);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<String>> getReadArticleIds() async {
    try {
      return await ReadArticlesService.getReadArticleIds();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_articlesKey);
      await prefs.remove(_lastFetchKey);
    } catch (e) {
      throw Exception('Failed to clear cache: $e');
    }
  }

}