import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/portfolio_item.dart';

class PortfolioService {
  final String baseUrl;
  final String _basePath = '/api/professional/portfolios';

  PortfolioService({required this.baseUrl});

  // Récupérer la liste des portfolios
  Future<List<PortfolioItem>> getPortfolios(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$_basePath'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> portfolios = data['data'] ?? [];
          return portfolios
              .map((item) => PortfolioItem.fromJson(item))
              .toList();
        }
        throw Exception('Erreur lors de la récupération des portfolios');
      } else {
        throw Exception(
            'Erreur serveur: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // Créer un nouveau portfolio
  Future<PortfolioItem> createPortfolio({
    required String token,
    required String title,
    required String description,
    required String category,
    required List<String> tags,
    required String imagePath,
    bool isFeatured = false,
    DateTime? completedAt,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$_basePath'),
      );

      // Ajouter les champs texte
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['category'] = category;
      request.fields['is_featured'] = isFeatured.toString();
      if (completedAt != null) {
        request.fields['completed_at'] = completedAt.toIso8601String();
      }
      
      // Ajouter les tags
      for (var tag in tags) {
        request.fields['tags[]'] = tag;
      }

      // Ajouter le fichier image
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));

      // Ajouter le token d'authentification
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Envoyer la requête
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return PortfolioItem.fromJson(data['data']);
        }
        throw Exception('Erreur lors de la création du portfolio');
      } else {
        throw Exception(
            'Erreur serveur: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // Mettre à jour un portfolio existant
  Future<PortfolioItem> updatePortfolio({
    required String token,
    required String id,
    String? title,
    String? description,
    String? category,
    List<String>? tags,
    String? imagePath,
    bool? isFeatured,
    DateTime? completedAt,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$_basePath/$id?_method=PUT'),
      );

      // Ajouter les champs texte
      if (title != null) request.fields['title'] = title;
      if (description != null) request.fields['description'] = description;
      if (category != null) request.fields['category'] = category;
      if (isFeatured != null) {
        request.fields['is_featured'] = isFeatured.toString();
      }
      if (completedAt != null) {
        request.fields['completed_at'] = completedAt.toIso8601String();
      }
      
      // Ajouter les tags s'ils sont fournis
      if (tags != null) {
        for (var tag in tags) {
          request.fields['tags[]'] = tag;
        }
      }

      // Ajouter le fichier image s'il est fourni
      if (imagePath != null) {
        request.files.add(await http.MultipartFile.fromPath('image', imagePath));
      }

      // Ajouter le token d'authentification
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Envoyer la requête
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return PortfolioItem.fromJson(data['data']);
        }
        throw Exception('Erreur lors de la mise à jour du portfolio');
      } else {
        throw Exception(
            'Erreur serveur: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // Supprimer un portfolio
  Future<bool> deletePortfolio(String token, String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$_basePath/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        throw Exception(
            'Erreur serveur: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }
}
