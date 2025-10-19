class ProClientProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String? avatarUrl;

  // Informations professionnelles
  final String? companyName;
  final String jobTitle;
  final String profession;
  final int experienceYears;
  final double hourlyRate;
  final double minPrice;
  final double maxPrice;
  final String address;
  final String city;
  final String postalCode;
  final int radiusKm;
  final int completedJobs;
  final String? description;
  final List<ProfessionalSkill> skills;

  // Informations client
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProClientProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.avatarUrl,
    this.companyName,
    this.jobTitle = '',
    this.profession = '',
    this.experienceYears = 0,
    this.hourlyRate = 0.0,
    this.minPrice = 0.0,
    this.maxPrice = 0.0,
    this.address = '',
    this.city = '',
    this.postalCode = '',
    this.radiusKm = 0,
    this.completedJobs = 0,
    this.description,
    List<ProfessionalSkill>? skills,
    this.isActive = false,
    this.createdAt,
    this.updatedAt,
  }) : skills = skills ?? [];

  String get fullName => '$firstName $lastName';
  String get location => [city, postalCode].where((e) => e.isNotEmpty).join(', ');

  // Getter pour le nom d'affichage (entreprise si disponible, sinon nom complet)
  String get displayName {
    if (companyName?.isNotEmpty == true) {
      return companyName!;
    }
    return fullName;
  }

  // Getter pour l'URL complète de l'avatar
  String? get fullAvatarUrl {
    if (avatarUrl == null || avatarUrl!.isEmpty) return null;

    // Si l'URL commence par http, c'est déjà une URL complète
    if (avatarUrl!.startsWith('http://') || avatarUrl!.startsWith('https://')) {
      return avatarUrl;
    }

    // Si c'est un chemin relatif, construire l'URL complète Laravel
    if (avatarUrl!.startsWith('/storage/') || avatarUrl!.startsWith('storage/')) {
      final cleanPath = avatarUrl!.startsWith('/') ? avatarUrl!.substring(1) : avatarUrl!;
      return 'http://10.0.2.2:8000/$cleanPath';
    }

    return avatarUrl;
  }

  // Méthode pour créer une instance depuis JSON
  factory ProClientProfile.fromJson(Map<String, dynamic> json) {
    return ProClientProfile(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      avatarUrl: json['avatar_url'],
      companyName: json['company_name'],
      jobTitle: json['job_title'] ?? '',
      profession: json['profession'] ?? '',
      experienceYears: json['experience_years'] ?? 0,
      hourlyRate: (json['hourly_rate'] ?? 0).toDouble(),
      minPrice: (json['min_price'] ?? 0).toDouble(),
      maxPrice: (json['max_price'] ?? 0).toDouble(),
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      postalCode: json['postal_code'] ?? '',
      radiusKm: json['radius_km'] ?? 0,
      completedJobs: json['completed_jobs'] ?? 0,
      description: json['description'],
      skills: json['skills'] != null
          ? (json['skills'] as List).map((skill) => ProfessionalSkill.fromJson(skill)).toList()
          : [],
      isActive: json['is_active'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  // Méthode pour convertir en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'company_name': companyName,
      'job_title': jobTitle,
      'profession': profession,
      'experience_years': experienceYears,
      'hourly_rate': hourlyRate,
      'min_price': minPrice,
      'max_price': maxPrice,
      'address': address,
      'city': city,
      'postal_code': postalCode,
      'radius_km': radiusKm,
      'completed_jobs': completedJobs,
      'description': description,
      'skills': skills.map((skill) => skill.toJson()).toList(),
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Méthode pour vérifier si le profil professionnel est complet
  bool isProfessionalProfileComplete() {
    return companyName?.isNotEmpty == true &&
           jobTitle.isNotEmpty &&
           profession.isNotEmpty &&
           address.isNotEmpty &&
           city.isNotEmpty &&
           postalCode.isNotEmpty;
  }

  // Copier avec des modifications
  ProClientProfile copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? avatarUrl,
    String? companyName,
    String? jobTitle,
    String? profession,
    int? experienceYears,
    double? hourlyRate,
    double? minPrice,
    double? maxPrice,
    String? address,
    String? city,
    String? postalCode,
    int? radiusKm,
    int? completedJobs,
    String? description,
    List<ProfessionalSkill>? skills,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProClientProfile(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      companyName: companyName ?? this.companyName,
      jobTitle: jobTitle ?? this.jobTitle,
      profession: profession ?? this.profession,
      experienceYears: experienceYears ?? this.experienceYears,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      radiusKm: radiusKm ?? this.radiusKm,
      completedJobs: completedJobs ?? this.completedJobs,
      description: description ?? this.description,
      skills: skills ?? this.skills,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Classe pour représenter les compétences professionnelles détaillées
class ProfessionalSkill {
  final String id;
  final String name;
  final String category;
  final int level; // 1-5

  ProfessionalSkill({
    required this.id,
    required this.name,
    required this.category,
    this.level = 1,
  });

  factory ProfessionalSkill.fromJson(Map<String, dynamic> json) {
    return ProfessionalSkill(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      level: json['level'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'level': level,
    };
  }
}
