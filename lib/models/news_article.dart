class NewsArticle {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime timestamp;

  NewsArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.timestamp,
  });

  factory NewsArticle.fromFirestore(Map<String, dynamic> data, String id) {
    return NewsArticle(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['image'] ?? '',
      timestamp: data['timestamp']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'image': imageUrl,
      'timestamp': timestamp,
    };
  }
}