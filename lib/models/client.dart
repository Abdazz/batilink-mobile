import '../core/app_config.dart';

class Client {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? profilePhotoUrl;
  final int quotationsCount;
  final LastQuotation? lastQuotation;

  Client({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.profilePhotoUrl,
    this.quotationsCount = 0,
    this.lastQuotation,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      profilePhotoUrl: json['profile_photo_url'],
      quotationsCount: _parseInt(json['quotations_count'], 0),
      lastQuotation: json['last_quotation'] != null
          ? LastQuotation.fromJson(json['last_quotation'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'profile_photo_url': profilePhotoUrl,
      'quotations_count': quotationsCount,
      'last_quotation': lastQuotation?.toJson(),
    };
  }

  // Getter pour l'URL complète de la photo de profil
  String? get fullProfilePhotoUrl {
    if (profilePhotoUrl == null || profilePhotoUrl!.isEmpty) return null;
    
    // Si l'URL commence par http, c'est déjà une URL complète
    if (profilePhotoUrl!.startsWith('http://') || profilePhotoUrl!.startsWith('https://')) {
      return profilePhotoUrl;
    }
    
    // Construire l'URL complète
    return AppConfig.buildMediaUrl(profilePhotoUrl);
  }
}

class LastQuotation {
  final String id;
  final String status;
  final String? amount;
  final DateTime? createdAt;

  LastQuotation({
    required this.id,
    required this.status,
    this.amount,
    this.createdAt,
  });

  factory LastQuotation.fromJson(Map<String, dynamic> json) {
    return LastQuotation(
      id: json['id']?.toString() ?? '',
      status: json['status'] ?? 'pending',
      amount: json['amount']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'amount': amount,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String get statusText {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'accepted':
        return 'Accepté';
      case 'rejected':
        return 'Refusé';
      case 'completed':
        return 'Terminé';
      case 'expired':
        return 'Expiré';
      default:
        return status;
    }
  }
}

class ClientDetails extends Client {
  final DateTime? createdAt;
  final ClientStats stats;
  final List<ClientQuotation> quotations;
  final List<ClientReview> reviews;

  ClientDetails({
    required super.id,
    required super.name,
    required super.email,
    super.phone,
    super.profilePhotoUrl,
    required super.quotationsCount,
    super.lastQuotation,
    this.createdAt,
    required this.stats,
    required this.quotations,
    required this.reviews,
  });

  factory ClientDetails.fromJson(Map<String, dynamic> json) {
    final clientData = json['client'] ?? json;
    
    return ClientDetails(
      id: clientData['id']?.toString() ?? '',
      name: clientData['name'] ?? '',
      email: clientData['email'] ?? '',
      phone: clientData['phone'],
      profilePhotoUrl: clientData['profile_photo_url'],
      quotationsCount: _parseInt(clientData['quotations_count'], 0),
      lastQuotation: clientData['last_quotation'] != null
          ? LastQuotation.fromJson(clientData['last_quotation'])
          : null,
      createdAt: clientData['created_at'] != null
          ? DateTime.tryParse(clientData['created_at'].toString())
          : null,
      stats: json['stats'] != null
          ? ClientStats.fromJson(json['stats'])
          : ClientStats(),
      quotations: json['quotations'] != null
          ? (json['quotations'] as List).map((q) => ClientQuotation.fromJson(q)).toList()
          : [],
      reviews: json['reviews'] != null
          ? (json['reviews'] as List).map((r) => ClientReview.fromJson(r)).toList()
          : [],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'client': {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'profile_photo_url': profilePhotoUrl,
        'quotations_count': quotationsCount,
        'last_quotation': lastQuotation?.toJson(),
        'created_at': createdAt?.toIso8601String(),
      },
      'stats': stats.toJson(),
      'quotations': quotations.map((q) => q.toJson()).toList(),
      'reviews': reviews.map((r) => r.toJson()).toList(),
    };
  }
}

class ClientStats {
  final int quotationsCount;
  final int completedQuotations;
  final int reviewsCount;
  final double averageRating;

  ClientStats({
    this.quotationsCount = 0,
    this.completedQuotations = 0,
    this.reviewsCount = 0,
    this.averageRating = 0.0,
  });

  factory ClientStats.fromJson(Map<String, dynamic> json) {
    return ClientStats(
      quotationsCount: _parseInt(json['quotations_count'], 0),
      completedQuotations: _parseInt(json['completed_quotations'], 0),
      reviewsCount: _parseInt(json['reviews_count'], 0),
      averageRating: _parseDouble(json['average_rating'], 0.0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quotations_count': quotationsCount,
      'completed_quotations': completedQuotations,
      'reviews_count': reviewsCount,
      'average_rating': averageRating,
    };
  }
}

class ClientQuotation {
  final String id;
  final String jobTitle;
  final String status;
  final String? amount;
  final DateTime? createdAt;

  ClientQuotation({
    required this.id,
    required this.jobTitle,
    required this.status,
    this.amount,
    this.createdAt,
  });

  factory ClientQuotation.fromJson(Map<String, dynamic> json) {
    return ClientQuotation(
      id: json['id']?.toString() ?? '',
      jobTitle: json['job_title'] ?? '',
      status: json['status'] ?? 'pending',
      amount: json['amount']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_title': jobTitle,
      'status': status,
      'amount': amount,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String get statusText {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'accepted':
        return 'Accepté';
      case 'rejected':
        return 'Refusé';
      case 'completed':
        return 'Terminé';
      case 'expired':
        return 'Expiré';
      default:
        return status;
    }
  }
}

class ClientReview {
  final String id;
  final String jobTitle;
  final int overallRating;
  final String? comment;
  final DateTime? createdAt;
  final bool hasResponse;

  ClientReview({
    required this.id,
    required this.jobTitle,
    required this.overallRating,
    this.comment,
    this.createdAt,
    this.hasResponse = false,
  });

  factory ClientReview.fromJson(Map<String, dynamic> json) {
    return ClientReview(
      id: json['id']?.toString() ?? '',
      jobTitle: json['job_title'] ?? '',
      overallRating: _parseInt(json['overall_rating'], 0),
      comment: json['comment'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      hasResponse: json['has_response'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_title': jobTitle,
      'overall_rating': overallRating,
      'comment': comment,
      'created_at': createdAt?.toIso8601String(),
      'has_response': hasResponse,
    };
  }
}

// Helper functions for safe type conversion
int _parseInt(dynamic value, int defaultValue) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? defaultValue;
  if (value is double) return value.toInt();
  return defaultValue;
}

double _parseDouble(dynamic value, double defaultValue) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return defaultValue;
}
