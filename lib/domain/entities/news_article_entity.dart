class NewsArticleEntity {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime timestamp;
  final String category;
  final bool isRead;
  final String? sourceUrl;
  final String? source;
  final String? displayCategory; // Override for UI display (tracks source endpoint)

  const NewsArticleEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.timestamp,
    required this.category,
    this.isRead = false,
    this.sourceUrl,
    this.source,
    this.displayCategory,
  });

  /// Get the category to display in UI (prioritizes source-tracked category)
  String get effectiveCategory => displayCategory ?? category;

  NewsArticleEntity copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    DateTime? timestamp,
    String? category,
    bool? isRead,
    String? sourceUrl,
    String? source,
    String? displayCategory,
  }) {
    return NewsArticleEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      isRead: isRead ?? this.isRead,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      source: source ?? this.source,
      displayCategory: displayCategory ?? this.displayCategory,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NewsArticleEntity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// Convert entity to Supabase map for database operations
  Map<String, dynamic> toSupabaseMap() {
    return {
      'title': title,
      'summary': description,
      'image_url': imageUrl,
      'published': timestamp.toIso8601String(),
      'category': category,
      'link': sourceUrl,
    };
  }

  /// Factory constructor from Supabase data
  factory NewsArticleEntity.fromSupabase(Map<String, dynamic> json) {
    return NewsArticleEntity(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['summary'] ?? json['description'] ?? '',
      imageUrl: json['image_url'] ?? '',
      timestamp: json['published'] != null 
          ? DateTime.tryParse(json['published']) ?? DateTime.now()
          : DateTime.now(),
      category: json['category'] ?? 'General',
      isRead: false, // Will be determined by repository
      sourceUrl: json['link'] ?? json['source_url'] ?? json['original_url'],
      source: json['source'],
    );
  }
}