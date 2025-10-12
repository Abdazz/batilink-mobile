class PortfolioItem {
  final String id;
  final String title;
  final String description;
  final String category;
  final List<String> tags;
  final String? imageUrl;
  final bool isFeatured;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PortfolioItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.tags,
    this.imageUrl,
    this.isFeatured = false,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    return PortfolioItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      imageUrl: json['image_url'],
      isFeatured: json['is_featured'] ?? false,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'tags': tags,
      'image_url': imageUrl,
      'is_featured': isFeatured,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Pour le formulaire d'édition
  PortfolioItem copyWith({
    String? title,
    String? description,
    String? category,
    List<String>? tags,
    String? imageUrl,
    bool? isFeatured,
    DateTime? completedAt,
  }) {
    return PortfolioItem(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      imageUrl: imageUrl ?? this.imageUrl,
      isFeatured: isFeatured ?? this.isFeatured,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
