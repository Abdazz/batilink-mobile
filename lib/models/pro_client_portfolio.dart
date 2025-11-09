import 'package:flutter/material.dart';

class ProClientPortfolio {
  final String id;
  final String title;
  final String description;
  final String? imagePath;
  final String? projectUrl;
  final List<String> skills;
  final bool isFeatured;
  final DateTime? projectDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProClientPortfolio({
    required this.id,
    required this.title,
    required this.description,
    this.imagePath,
    this.projectUrl,
    List<String>? skills,
    this.isFeatured = false,
    this.projectDate,
    required this.createdAt,
    required this.updatedAt,
  }) : skills = skills ?? [];

  factory ProClientPortfolio.fromJson(Map<String, dynamic> json) {
    return ProClientPortfolio(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imagePath: json['image_path'],
      projectUrl: json['project_url'],
      skills: (json['skills'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isFeatured: json['is_featured'] ?? false,
      projectDate: json['project_date'] != null ? DateTime.parse(json['project_date']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_path': imagePath,
      'project_url': projectUrl,
      'skills': skills,
      'is_featured': isFeatured,
      'project_date': projectDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProClientPortfolio copyWith({
    String? id,
    String? title,
    String? description,
    String? imagePath,
    String? projectUrl,
    List<String>? skills,
    bool? isFeatured,
    DateTime? projectDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProClientPortfolio(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      projectUrl: projectUrl ?? this.projectUrl,
      skills: skills ?? this.skills,
      isFeatured: isFeatured ?? this.isFeatured,
      projectDate: projectDate ?? this.projectDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  void operator [](String other) {}
}