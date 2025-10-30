import '../core/app_config.dart';

class Professional {
  final String id;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String profession;
  final double rating;
  final int reviewCount;
  final bool isFavorite;
  final DateTime? lastInteraction;
  final String? lastReview;
  final bool isAvailable;
  final String? description;
  final String? city;
  final String? postalCode;
  final List<String> skills;
  final List<Map<String, dynamic>> portfolios;
  final List<Map<String, dynamic>> reviews;
  final String? _companyName; // Stockage interne du nom d'entreprise

  // Nouveaux champs de l'API
  final String? companyName; // Changé en optionnel
  final String jobTitle;
  final int experienceYears;
  final double hourlyRate;
  final double minPrice;
  final double maxPrice;
  final String address;
  final int radiusKm;
  final int completedJobs;
  final List<ProfessionalSkill> detailedSkills;
  final Map<String, dynamic>? businessHours;

  Professional({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.profession,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isFavorite = false,
    this.lastInteraction,
    this.lastReview,
    this.isAvailable = false,
    this.description,
    this.city,
    this.postalCode,
    List<String>? skills,
    List<Map<String, dynamic>>? portfolios,
    List<Map<String, dynamic>>? reviews,
    String? companyName,
    this.jobTitle = '',
    this.experienceYears = 0,
    this.hourlyRate = 0.0,
    this.minPrice = 0.0,
    this.maxPrice = 0.0,
    this.address = '',
    this.radiusKm = 0,
    this.completedJobs = 0,
    List<ProfessionalSkill>? detailedSkills,
    this.businessHours,
  })  : skills = skills ?? [],
        portfolios = portfolios ?? [],
        reviews = reviews ?? [],
        _companyName = companyName,
        companyName = companyName,
        detailedSkills = detailedSkills ?? [];

  String get fullName => '$firstName $lastName';
  String get location => [city, postalCode].where((e) => e != null).join(', ');

  // Getter pour companyName avec fallback sur fullName
  String get displayName {
    if (_companyName?.isNotEmpty == true) {
      return _companyName!;
    }
    return fullName;
  }

  // Getter pour l'URL complète de l'avatar avec fallback sur l'URL Laravel
  String? get fullAvatarUrl {
    if (avatarUrl == null || avatarUrl!.isEmpty) return null;

    print('=== DEBUG AVATAR URL ===');
    print('avatarUrl brut: $avatarUrl');

    // Si l'URL commence par http, c'est déjà une URL complète
    if (avatarUrl!.startsWith('http://') || avatarUrl!.startsWith('https://')) {
      print('URL complète détectée: $avatarUrl');
      return avatarUrl;
    }

    // Si c'est un chemin relatif avec double /storage, corrige
    String url = avatarUrl!;
    if (url.startsWith('/storage/') || url.startsWith('storage/')) {
      final raw = url.startsWith('/') ? url : '/$url';
      String out = AppConfig.buildMediaUrl(raw);
      // Correction : enlève tous doublons /storage/
      while (out.contains('/storage/storage/')) {
        out = out.replaceAll('/storage/storage/', '/storage/');
      }
      return out;
    }

    // Si c'est juste un nom de fichier ou un placeholder, retourner null
    if (avatarUrl!.contains('via.placeholder.com') || avatarUrl!.contains('placeholder')) {
      print('Placeholder détecté, pas d\'affichage: $avatarUrl');
      return null;
    }

    // Par défaut, retourner l'URL telle quelle
    print('URL par défaut: $avatarUrl');
    return avatarUrl;
  }

  // Getter pour photoUrl depuis les données JSON brutes si disponibles (maintenu pour compatibilité)
  String? get photoUrl {
    return fullAvatarUrl;
  }

  factory Professional.fromJson(Map<String, dynamic> json) {
    return Professional(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name'] ?? json['user']?['first_name'] ?? '',
      lastName: json['last_name'] ?? json['user']?['last_name'] ?? '',
      avatarUrl: json['avatar_url'] ??
                 json['user']?['profile_photo_url'] ??
                 json['avatar'] ??
                 _extractProfilePhotoUrl(json['profile_photo']),
      profession: json['profession'] ?? json['job_title'] ?? 'Professionnel',
      rating: (json['rating'] ?? 0).toDouble(),
      reviewCount: json['review_count'] ?? json['reviews']?.length ?? 0,
      isFavorite: json['is_favorite'] ?? false,
      lastInteraction: json['last_interaction'] != null
          ? DateTime.tryParse(json['last_interaction'].toString())
          : null,
      lastReview: json['last_review'],
      isAvailable: json['is_available'] ?? false,
      description: json['description'],
      city: json['city'],
      postalCode: json['postal_code']?.toString(),
      skills: json['skills'] != null
          ? (json['skills'] as List<dynamic>).map((skill) =>
              skill is Map<String, dynamic> ? skill['name']?.toString() ?? '' : skill.toString()).toList()
          : [],
      portfolios: (json['portfolios'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      reviews: (json['reviews'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      companyName: json['company_name'],
      jobTitle: json['job_title'] ?? '',
      experienceYears: json['experience_years'] ?? 0,
      hourlyRate: double.tryParse(json['hourly_rate']?.toString() ?? '0') ?? 0.0,
      minPrice: double.tryParse(json['min_price']?.toString() ?? '0') ?? 0.0,
      maxPrice: double.tryParse(json['max_price']?.toString() ?? '0') ?? 0.0,
      address: json['address'] ?? '',
      radiusKm: json['radius_km'] ?? 0,
      completedJobs: json['completed_jobs'] ?? 0,
      detailedSkills: json['skills'] != null
          ? (json['skills'] as List<dynamic>).map((skill) =>
              ProfessionalSkill.fromJson(skill as Map<String, dynamic>)).toList()
          : [],
      businessHours: (json['business_hours'] as Map?)?.cast<String, dynamic>(),
    );
  }

  // Méthode helper pour extraire l'URL de la photo de profil depuis la nouvelle structure
  static String? _extractProfilePhotoUrl(dynamic profilePhotoData) {
    if (profilePhotoData == null) {
      print('=== DEBUG PROFILE PHOTO ===');
      print('profilePhotoData est null');
      return null;
    }

    print('=== DEBUG PROFILE PHOTO ===');
    print('profilePhotoData type: ${profilePhotoData.runtimeType}');
    print('profilePhotoData value: $profilePhotoData');

    if (profilePhotoData is Map<String, dynamic>) {
      // Nouvelle structure avec path, url, type
      final url = profilePhotoData['url']?.toString();
      print('Structure Map détectée, URL extraite: $url');
      return url;
    }

    if (profilePhotoData is String) {
      // Ancienne structure avec juste l'URL
      print('Structure String détectée: $profilePhotoData');
      return profilePhotoData;
    }

    print('Type non reconnu pour profilePhotoData');
    return null;
  }

  Map<String, dynamic> toJson() {
    final data = {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'avatar_url': avatarUrl,
      'profession': profession,
      'rating': rating,
      'review_count': reviewCount,
      'is_favorite': isFavorite,
      'last_interaction': lastInteraction?.toIso8601String(),
      'last_review': lastReview,
      'is_available': isAvailable,
      'description': description,
      'city': city,
      'postal_code': postalCode,
      'skills': skills,
      'portfolios': portfolios,
      'reviews': reviews,
      'company_name': _companyName,
      'job_title': jobTitle,
      'experience_years': experienceYears,
      'hourly_rate': hourlyRate,
      'min_price': minPrice,
      'max_price': maxPrice,
      'address': address,
      'radius_km': radiusKm,
      'completed_jobs': completedJobs,
      'detailed_skills': detailedSkills.map((skill) => skill.toJson()).toList(),
    };
    if (businessHours != null) {
      data['business_hours'] = businessHours;
    }
    return data;
  }

  Professional copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    String? profession,
    double? rating,
    int? reviewCount,
    bool? isFavorite,
    DateTime? lastInteraction,
    String? lastReview,
    bool? isAvailable,
    String? description,
    String? city,
    String? postalCode,
    List<String>? skills,
    List<Map<String, dynamic>>? portfolios,
    List<Map<String, dynamic>>? reviews,
    String? companyName,
    String? jobTitle,
    int? experienceYears,
    double? hourlyRate,
    double? minPrice,
    double? maxPrice,
    String? address,
    int? radiusKm,
    int? completedJobs,
    List<ProfessionalSkill>? detailedSkills,
    Map<String, dynamic>? businessHours,
  }) {
    return Professional(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      profession: profession ?? this.profession,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isFavorite: isFavorite ?? this.isFavorite,
      lastInteraction: lastInteraction ?? this.lastInteraction,
      lastReview: lastReview ?? this.lastReview,
      isAvailable: isAvailable ?? this.isAvailable,
      description: description ?? this.description,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      skills: skills ?? this.skills,
      portfolios: portfolios ?? this.portfolios,
      reviews: reviews ?? this.reviews,
      companyName: companyName ?? _companyName,
      jobTitle: jobTitle ?? this.jobTitle,
      experienceYears: experienceYears ?? this.experienceYears,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      address: address ?? this.address,
      radiusKm: radiusKm ?? this.radiusKm,
      completedJobs: completedJobs ?? this.completedJobs,
      detailedSkills: detailedSkills ?? this.detailedSkills,
      businessHours: businessHours ?? this.businessHours,
    );
  }
}

class ProfessionalSkill {
  final String name;
  final String slug;
  final int experienceYears;
  final String level;

  ProfessionalSkill({
    required this.name,
    required this.slug,
    required this.experienceYears,
    required this.level,
  });

  factory ProfessionalSkill.fromJson(Map<String, dynamic> json) {
    return ProfessionalSkill(
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      experienceYears: json['experience_years'] ?? 0,
      level: json['level'] ?? 'beginner',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'slug': slug,
      'experience_years': experienceYears,
      'level': level,
    };
  }
}
