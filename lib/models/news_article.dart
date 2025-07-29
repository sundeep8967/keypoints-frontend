class NewsArticle {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime timestamp;
  final String category;
  final String? keypoints; // Add keypoints field
  final double? score; // Add score field

  NewsArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.timestamp,
    this.category = 'General',
    this.keypoints,
    this.score,
  });


  factory NewsArticle.fromSupabase(Map<String, dynamic> data) {
    // Log keypoints data to see what we're getting
    if (data['key_points'] != null) {
      print('🔍 KEY_POINTS FOUND: ${data['key_points']}');
      print('🔍 KEY_POINTS TYPE: ${data['key_points'].runtimeType}');
    } else {
      print('❌ NO KEY_POINTS for article: ${data['title']}');
    }
    
    return NewsArticle(
      id: data['id']?.toString() ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['image_url'] ?? '',
      timestamp: data['published'] != null 
          ? DateTime.tryParse(data['published']) ?? DateTime.now()
          : DateTime.now(),
      category: data['category'] ?? 'General',
      keypoints: data['key_points'] is List 
          ? (data['key_points'] as List).join('|') // Convert list to string temporarily
          : data['key_points']?.toString(), // Get key_points from database
      score: data['quality_score']?.toDouble(), // Get quality_score from database
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
      'quality_score': score,
    };
  }
}