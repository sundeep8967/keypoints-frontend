class NewsArticle {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime timestamp;
  final String category;

  NewsArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.timestamp,
    this.category = 'General',
  });

  factory NewsArticle.fromFirestore(Map<String, dynamic> data, String id) {
    return NewsArticle(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['image'] ?? '',
      timestamp: data['timestamp']?.toDate() ?? DateTime.now(),
      category: data['category'] ?? 'General',
    );
  }

  factory NewsArticle.fromSupabase(Map<String, dynamic> data) {
    return NewsArticle(
      id: data['id']?.toString() ?? '',
      title: data['title'] ?? '',
      description: data['summary'] ?? '',
      imageUrl: data['image_url'] ?? '',
      timestamp: data['published'] != null 
          ? DateTime.tryParse(data['published']) ?? DateTime.now()
          : DateTime.now(),
      category: data['category'] ?? 'General',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'image': imageUrl,
      'timestamp': timestamp,
      'category': category,
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'title': title,
      'summary': description,
      'image_url': imageUrl,
      'published': timestamp.toIso8601String(),
      'category': category,
    };
  }
}