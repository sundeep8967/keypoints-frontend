class NewsArticleEntity {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime timestamp;
  final String category;
  final String? keypoints;
  final bool isRead;

  const NewsArticleEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.timestamp,
    required this.category,
    this.keypoints,
    this.isRead = false,
  });

  NewsArticleEntity copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    DateTime? timestamp,
    String? category,
    String? keypoints,
    bool? isRead,
  }) {
    return NewsArticleEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      keypoints: keypoints ?? this.keypoints,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NewsArticleEntity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}