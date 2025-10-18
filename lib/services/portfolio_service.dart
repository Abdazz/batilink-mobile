import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

class PortfolioService {
  final String baseUrl;

  PortfolioService({required this.baseUrl});

  String get effectiveBaseUrl {
    String url = baseUrl;
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Récupère la liste des portfolios du professionnel connecté
  Future<http.Response> getPortfolios({required String accessToken}) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/professional/portfolios');
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return response;
  }

  /// Récupère un portfolio spécifique
  Future<http.Response> getPortfolio({
    required String accessToken,
    required String portfolioId,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/professional/portfolios/$portfolioId/');
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return response;
  }

  /// Crée un nouveau portfolio
  Future<http.StreamedResponse> createPortfolio({
    required String accessToken,
    required String title,
    required String description,
    required String category,
    required String filePath,
    List<String>? tags,
    bool? isFeatured,
    String? completedAt,
    String? fileName,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/professional/portfolios'); // Ajout du slash final comme attendu par Laravel
    final request = http.MultipartRequest('POST', url);

    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    });

    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['category'] = category; // Laravel attend 'category', pas 'project_type'

    if (tags != null && tags.isNotEmpty) {
      request.fields['tags'] = jsonEncode(tags);
      print('🏷️ tags envoyés: $tags');
    }

    if (isFeatured != null) {
      // Laravel peut attendre un entier (1/0) pour les champs booléens
      request.fields['is_featured'] = isFeatured ? '1' : '0';
      print('🔧 is_featured envoyé: ${isFeatured ? '1' : '0'}');
    }

    if (completedAt != null && completedAt.isNotEmpty) {
      request.fields['project_date'] = completedAt; // Laravel attend 'project_date', pas 'completed_at'
      print('📅 project_date envoyé: $completedAt');
    }

    print('📁 Chemin du fichier image: $filePath');
    final file = await http.MultipartFile.fromPath(
      'image',
      filePath,
      // Spécifier explicitement le type MIME pour aider l'API
    );
    print('✅ Fichier image préparé pour envoi avec type MIME: ${file.contentType}');
    request.files.add(file);

    print('🚀 Envoi de la requête avec les champs: ${request.fields}');
    print('📎 Nombre de fichiers attachés: ${request.files.length}');

    return await request.send();
  }

  /// Met à jour un portfolio existant
  Future<http.StreamedResponse> updatePortfolio({
    required String accessToken,
    required String portfolioId,
    required String title,
    required String description,
    required String category,
    List<String>? tags,
    bool? isFeatured,
    String? completedAt,
    String? filePath,
    String? fileName,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/professional/portfolios/$portfolioId'); // Ajout du slash final
    final request = http.MultipartRequest('POST', url);

    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    });

    // Utiliser _method=PUT pour simuler une requête PUT
    request.fields['_method'] = 'PUT';
    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['category'] = category; // Laravel attend 'category', pas 'project_type'

    if (tags != null && tags.isNotEmpty) {
      request.fields['tags'] = jsonEncode(tags);
      print('🏷️ tags envoyés: $tags');
    }

    if (isFeatured != null) {
      // Laravel peut attendre un entier (1/0) pour les champs booléens
      request.fields['is_featured'] = isFeatured ? '1' : '0';
      print('🔧 is_featured envoyé: ${isFeatured ? '1' : '0'}');
    }

    if (completedAt != null && completedAt.isNotEmpty) {
      request.fields['project_date'] = completedAt; // Laravel attend 'project_date', pas 'completed_at'
      print('📅 project_date envoyé: $completedAt');
    }

    if (filePath != null) {
      print('📁 Chemin du fichier image: $filePath');
      final file = await http.MultipartFile.fromPath(
        'image',
        filePath,
        // Spécifier explicitement le type MIME pour aider l'API
      );
      print('✅ Fichier image préparé pour envoi avec type MIME: ${file.contentType}');
      request.files.add(file);
    }

    print('🚀 Envoi de la requête avec les champs: ${request.fields}');
    print('📎 Nombre de fichiers attachés: ${request.files.length}');

    return await request.send();
  }

  /// Supprime un portfolio
  Future<http.Response> deletePortfolio({
    required String accessToken,
    required String portfolioId,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/professional/portfolios/$portfolioId'); // Ajout du slash final
    final response = await http.delete(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return response;
  }

  /// Sélectionne un fichier image pour le portfolio
  Future<FilePickerResult?> pickImage() async {
    try {
      return await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      );
    } catch (e) {
      print('Erreur lors de la sélection du fichier: $e');
      return null;
    }
  }

  /// Valide les données du portfolio avant envoi
  Map<String, String> validatePortfolioData({
    required String title,
    required String description,
    required String category,
    String? filePath,
  }) {
    final errors = <String, String>{};

    if (title.trim().isEmpty) {
      errors['title'] = 'Le titre est requis';
    } else if (title.trim().length > 255) {
      errors['title'] = 'Le titre ne peut pas dépasser 255 caractères';
    } else if (title.trim().length < 3) {
      errors['title'] = 'Le titre doit contenir au moins 3 caractères';
    }

    if (description.trim().isNotEmpty && description.trim().length > 255) {
      errors['description'] = 'La description ne peut pas dépasser 255 caractères';
    } else if (description.trim().isEmpty) {
      errors['description'] = 'La description est requise';
    } else if (description.trim().length < 10) {
      errors['description'] = 'La description doit contenir au moins 10 caractères';
    }

    if (category.trim().isEmpty) {
      errors['category'] = 'La catégorie est requise';
    } else if (category.trim().length > 100) {
      errors['category'] = 'La catégorie ne peut pas dépasser 100 caractères';
    }

    if (filePath == null || filePath.isEmpty) {
      errors['image'] = 'Une image est requise';
    }

    return errors;
  }
}