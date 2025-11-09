class Document {
  final String id;
  final String name;
  final String url;
  final String type;
  final DateTime uploadedAt;
  final String filePath;
  final int? size;
  final String? mimeType;

  Document({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.uploadedAt,
    this.filePath = '',
    this.size,
    this.mimeType,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      type: json['type'] ?? '',
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.tryParse(json['uploaded_at']) ?? DateTime.now()
          : DateTime.now(),
      // accept both 'path' and legacy 'file_path'
      filePath: json['path'] ?? json['file_path'] ?? '',
      size: json['size'],
      mimeType: json['mime_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type,
      'uploaded_at': uploadedAt.toIso8601String(),
      'path': filePath,
      'size': size,
      'mime_type': mimeType,
    };
  }

  /// Returns a copy of this Document with the provided fields replaced.
  Document copyWith({
    String? id,
    String? name,
    String? url,
    String? type,
    DateTime? uploadedAt,
    String? filePath,
    int? size,
    String? mimeType,
  }) {
    return Document(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      type: type ?? this.type,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      filePath: filePath ?? this.filePath,
      size: size ?? this.size,
      mimeType: mimeType ?? this.mimeType,
    );
  }
}
