import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_config.dart';

class ApiService {
  // Configuration centralisée via AppConfig
  // Plus besoin d'URL hardcodée - tout est géré dans AppConfig

  // Méthode pour effectuer une requête GET
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? prefs.getString('token');

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Méthode pour effectuer une requête GET
  static Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParams}) async {
    try {
      final uri = Uri.parse(AppConfig.buildUrl(endpoint, queryParams: queryParams));

      print('Requête GET vers: ${uri.toString()}');

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Méthode pour effectuer une requête POST
  static Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final uri = Uri.parse(AppConfig.buildUrl(endpoint, queryParams: queryParams));

      print('Requête POST vers: ${uri.toString()}');

      final response = await http.post(
        uri,
        headers: await _getHeaders(),
        body: data != null ? json.encode(data) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Méthode utilitaire pour récupérer le token avec fallback
  static Future<String?> getTokenWithFallback({String? providedToken}) async {
    if (providedToken != null && providedToken.isNotEmpty) {
      return providedToken;
    }

    // Fallback vers SharedPreferences si aucun token fourni
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? prefs.getString('token');
    return token;
  }

  // Méthode pour effectuer une requête GET avec token personnalisé
  static Future<dynamic> getWithToken(
    String endpoint, {
    String? token,
    Map<String, dynamic>? queryParams
  }) async {
    try {
      final authToken = await getTokenWithFallback(providedToken: token);
      final uri = Uri.parse(AppConfig.buildUrl(endpoint, queryParams: queryParams));

      print('Requête GET vers: ${uri.toString()}');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Méthode pour effectuer une requête POST avec token personnalisé
  static Future<dynamic> postWithToken(
    String endpoint, {
    String? token,
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final authToken = await getTokenWithFallback(providedToken: token);
      final uri = Uri.parse(AppConfig.buildUrl(endpoint, queryParams: queryParams));

      print('Requête POST vers: ${uri.toString()}');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: data != null ? json.encode(data) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Gestion de la réponse
  static dynamic _handleResponse(http.Response response) {
    final responseBody = json.decode(utf8.decode(response.bodyBytes));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    } else {
      final error = responseBody['message'] ?? 'Une erreur est survenue';
      throw Exception(error);
    }
  }
}
