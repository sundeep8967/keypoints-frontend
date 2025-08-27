class NewsArticle {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime timestamp;
  final String category;
  final String? keypoints; // Add keypoints field
  final String? sourceUrl; // Add source URL field
  final String? source; // Add source field from Supabase table

  NewsArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.timestamp,
    this.category = 'General',
    this.keypoints,
    this.sourceUrl,
    this.source,
  });


  factory NewsArticle.fromSupabase(Map<String, dynamic> data) {
    // Debug logging removed for cleaner console output
    
    return NewsArticle(
      id: data['id']?.toString() ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['image_url'] ?? '',
      timestamp: data['published'] != null 
          ? DateTime.tryParse(data['published']) ?? DateTime.now()
          : DateTime.now(),
      category: data['category'] ?? 'General',
      keypoints: _parseKeyPoints(data['key_points']),
      sourceUrl: data['link'] ?? data['source_url'] ?? data['original_url'], // Get source URL from database
      source: data['source'], // Get source field from database
    );
  }

  static String? _parseKeyPoints(dynamic keyPointsData) {
    if (keyPointsData == null) {
      return null;
    }

    if (keyPointsData is String) {
      return keyPointsData.trim().isEmpty ? null : keyPointsData.trim();
    }

    if (keyPointsData is List) {
      final stringList = keyPointsData.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      return stringList.isEmpty ? null : stringList.join(' | ');
    }

    return null;
  }


  Map<String, dynamic> toSupabaseMap() {
    return {
      'title': title,
      'summary': description,
      'image_url': imageUrl,
      'published': timestamp.toIso8601String(),
      'category': category,
      'keypoints': keypoints,
      'link': sourceUrl, // Store in 'link' field to match database
      'source': source, // Store source field
    };
  }
}