import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Pour émulateur Android : 10.0.2.2 pointe vers localhost de la machine hôte
  // Pour émulateur iOS : utilisez localhost normalement
  static const String baseUrl = 'http://10.0.2.2:8000';
  
  // Si vous testez sur un appareil physique, utilisez l'adresse IP de votre machine
  // et assurez-vous que le port 8000 est accessible depuis le réseau
  // static const String baseUrl = 'http://VOTRE_IP_LOCALE:8000';
  
  // Méthode pour effectuer une requête GET
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  
  // Méthode pour effectuer une requête GET
  static Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParams}) async {
    try {
      // S'assurer qu'il y a un seul slash entre la base et l'endpoint
      final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
      final uri = Uri.parse('$baseUrl$path').replace(
        queryParameters: queryParams?.map((key, value) => 
          MapEntry(key, value.toString())
        ),
      );
      
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
      // S'assurer qu'il y a un seul slash entre la base et l'endpoint
      final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
      final uri = Uri.parse('$baseUrl$path').replace(
        queryParameters: queryParams?.map((key, value) => 
          MapEntry(key, value.toString())
        ),
      );
      
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
