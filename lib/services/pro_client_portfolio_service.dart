import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import '../models/pro_client_portfolio.dart';
import '../core/app_config.dart';

class ProClientPortfolioService {
  final String baseUrl;

  ProClientPortfolioService({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.baseUrl;

  String get effectiveBaseUrl {
    String url = baseUrl;
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Récupère la liste des portfolios du pro-client connecté
  Future<List<ProClientPortfolio>> getPortfolios({required String token}) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/pro-client/portfolios');
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = json.decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (data['data'] != null) {
        return List<ProClientPortfolio>.from(
          data['data'].map((x) => ProClientPortfolio.fromJson(x))
        );
      }
      return [];
    }
    throw Exception(data['message'] ?? 'Une erreur est survenue');
  }

  /// Récupère un portfolio spécifique
  Future<ProClientPortfolio> getPortfolio({
    required String token,
    required String portfolioId,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/pro-client/portfolios/$portfolioId');
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = json.decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (data['data'] != null) {
        return ProClientPortfolio.fromJson(data['data']);
      }
      throw Exception('Format de données invalide');
    }
    throw Exception(data['message'] ?? 'Une erreur est survenue');
  }

  /// Crée un nouveau portfolio
  Future<ProClientPortfolio> createPortfolio({
    required String token,
    required String title,
    required String description,
    required String projectType,
    required File imageFile,
    String? category,
    String? projectUrl,
    String? projectDate,
    String? location,
    int? projectBudget,
    bool isFeatured = false,
    bool isVisible = true,
    List<String>? tags,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/pro-client/portfolios');
    final request = http.MultipartRequest('POST', url);

    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    // Ajouter les champs texte requis par l'API
    request.fields.addAll({
      'title': title,
      'description': description,
      'project_type': projectType,
      'is_featured': isFeatured ? '1' : '0',
      'is_visible': isVisible ? '1' : '0',
      if (category != null) 'category': category,
      if (projectUrl != null) 'project_url': projectUrl,
      if (projectDate != null) 'project_date': projectDate,
      if (location != null) 'location': location,
      if (projectBudget != null) 'project_budget': projectBudget.toString(),
      if (tags != null) 'tags': json.encode(tags),
    });

    // Ajouter l'image
    final imageStream = http.ByteStream(imageFile.openRead());
    final imageLength = await imageFile.length();
    final fileName = path.basename(imageFile.path);
    final multipartFile = http.MultipartFile(
      'image',
      imageStream,
      imageLength,
      filename: fileName,
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send();
    return _handlePortfolioResponse(streamedResponse);
  }

  Future<ProClientPortfolio> _handlePortfolioResponse(http.StreamedResponse response) async {
    final responseBody = await response.stream.bytesToString();
    final data = json.decode(responseBody);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (data['data'] != null) {
        return ProClientPortfolio.fromJson(data['data']);
      }
      throw Exception('Format de données invalide');
    }
    throw Exception(data['message'] ?? 'Une erreur est survenue');
  }

  /// Met à jour un portfolio existant
  Future<ProClientPortfolio> updatePortfolio({
    required String token,
    required String portfolioId,
    required String title,
    required String description,
    required String projectType,
    File? imageFile,
    String? category,
    String? projectUrl,
    String? projectDate,
    String? location,
    int? projectBudget,
    bool isFeatured = false,
    bool? isVisible,
    List<String>? tags,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/pro-client/portfolios/$portfolioId');
    final request = http.MultipartRequest('POST', url);

    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    // Utiliser _method=PUT pour simuler une requête PUT
    request.fields.addAll({
      '_method': 'PUT',
      'title': title,
      'description': description,
      'project_type': projectType,
      'is_featured': isFeatured ? '1' : '0',
      if (isVisible != null) 'is_visible': isVisible ? '1' : '0',
      if (category != null) 'category': category,
      if (projectUrl != null) 'project_url': projectUrl,
      if (projectDate != null) 'project_date': projectDate,
      if (location != null) 'location': location,
      if (projectBudget != null) 'project_budget': projectBudget.toString(),
      if (tags != null) 'tags': json.encode(tags),
    });

    // Ajouter l'image si une nouvelle est fournie
    if (imageFile != null) {
      final imageStream = http.ByteStream(imageFile.openRead());
      final imageLength = await imageFile.length();
      final fileName = path.basename(imageFile.path);
      final multipartFile = http.MultipartFile(
        'image',
        imageStream,
        imageLength,
        filename: fileName,
      );
      request.files.add(multipartFile);
    }

    final streamedResponse = await request.send();
    return _handlePortfolioResponse(streamedResponse);
  }

  /// Supprime un portfolio
  Future<bool> deletePortfolio({
    required String token,
    required String portfolioId,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/pro-client/portfolios/$portfolioId');
    final response = await http.delete(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return true;
    }
    final data = json.decode(response.body);
    throw Exception(data['message'] ?? 'Une erreur est survenue');
  }

  /// Sélectionne une image depuis la galerie
  Future<XFile?> pickImage() async {
    try {
      final picker = ImagePicker();
      return await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
      );
    } catch (e) {
      print('Erreur lors de la sélection de l\'image: $e');
      return null;
    }
  }

  /// Valide les données du portfolio
  Map<String, String> validatePortfolioData({
    required String title,
    required String description,
    File? imageFile,
    String? projectUrl,
  }) {
    final errors = <String, String>{};

    // Validation du titre
    if (title.trim().isEmpty) {
      errors['title'] = 'Le titre est requis';
    } else if (title.trim().length > 255) {
      errors['title'] = 'Le titre ne peut pas dépasser 255 caractères';
    } else if (title.trim().length < 3) {
      errors['title'] = 'Le titre doit contenir au moins 3 caractères';
    }

    // Validation de la description
    if (description.trim().isEmpty) {
      errors['description'] = 'La description est requise';
    } else if (description.trim().length > 1000) {
      errors['description'] = 'La description ne peut pas dépasser 1000 caractères';
    } else if (description.trim().length < 10) {
      errors['description'] = 'La description doit contenir au moins 10 caractères';
    }

    // Validation de l'image
    if (imageFile == null) {
      errors['image'] = 'Une image est requise';
    }

    // Validation optionnelle de l'URL du projet
    if (projectUrl != null && projectUrl.isNotEmpty) {
      final urlPattern = RegExp(
        r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
      );
      if (!urlPattern.hasMatch(projectUrl)) {
        errors['project_url'] = 'L\'URL du projet n\'est pas valide';
      }
    }

    return errors;
  }
}