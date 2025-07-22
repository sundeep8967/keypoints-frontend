import '../../domain/entities/news_article_entity.dart';

class NewsArticleModel extends NewsArticleEntity {
  const NewsArticleModel({
    required super.id,
    required super.title,
    required super.description,
    required super.imageUrl,
    required super.timestamp,
    required super.category,
    super.keypoints,
    super.isRead,
  });

  factory NewsArticleModel.fromSupabase(Map<String, dynamic> json) {
    return NewsArticleModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['summary'] ?? '',
      imageUrl: json['image_url'] ?? '',
      timestamp: json['published'] != null 
          ? DateTime.tryParse(json['published']) ?? DateTime.now()
          : DateTime.now(),
      category: json['category'] ?? 'General',
      keypoints: json['keypoints'],
      isRead: false, // Will be determined by repository
    );
  }

  factory NewsArticleModel.fromCache(Map<String, dynamic> json) {
    return NewsArticleModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      category: json['category'] ?? 'General',
      keypoints: json['keypoints'],
      isRead: json['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'title': title,
      'summary': description,
      'image_url': imageUrl,
      'published': timestamp.toIso8601String(),
      'category': category,
      'keypoints': keypoints,
    };
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'timestamp': timestamp.toIso8601String(),
      'category': category,
      'keypoints': keypoints,
      'isRead': isRead,
    };
  }

  factory NewsArticleModel.fromEntity(NewsArticleEntity entity) {
    return NewsArticleModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      imageUrl: entity.imageUrl,
      timestamp: entity.timestamp,
      category: entity.category,
      keypoints: entity.keypoints,
      isRead: entity.isRead,
    );
  }
}