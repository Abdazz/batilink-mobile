import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProClientDashboardService {
  final String baseUrl;

  ProClientDashboardService({required this.baseUrl});

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();

    // Essaie d'abord la clé principale 'token'
    String? token = prefs.getString('token');

    // Si pas trouvé, essaie l'ancienne clé 'access_token' pour compatibilité
    if (token == null) {
      token = prefs.getString('access_token');
      if (token != null) {
        print('Token trouvé avec l\'ancienne clé access_token - migration recommandée');
        // Migre vers la nouvelle clé pour éviter la confusion
        await prefs.setString('token', token);
        await prefs.remove('access_token');
        print('Token migré vers la clé principale');
      }
    }

    print('Token récupéré depuis SharedPreferences: ${token != null ? 'Présent (${token.length} caractères)' : 'Absent'}');
    return token;
  }

  /// Récupère les statistiques du dashboard pro-client
  Future<Map<String, dynamic>> getDashboardStats() async {
    final token = await _getToken();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dashboard/pro-client'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final apiData = Map<String, dynamic>.from(data['data']);

          // Mapper les données de l'API vers le format attendu par l'interface
          return _mapApiDataToDashboardFormat(apiData);
        } else {
          throw Exception('Format de réponse inattendu');
        }
      } else if (response.statusCode == 404) {
        print('Endpoint dashboard pro-client non trouvé - utilisation des données de démonstration');
        return _getDemoDashboardData();
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors de la récupération des statistiques pro-client: $e');
      if (e.toString().contains('Token non trouvé') || token == null) {
        print('Token manquant - utilisation des données de démonstration');
        return _getDemoDashboardData();
      }
      throw e;
    }
  }

  /// Mappe les données de l'API vers le format attendu par l'interface
  Map<String, dynamic> _mapApiDataToDashboardFormat(Map<String, dynamic> apiData) {
    return {
      'total_jobs_as_client': apiData['total_jobs_as_client'] ?? 0,
      'total_jobs_as_professional': apiData['total_jobs_as_professional'] ?? 0,
      'total_pending_quotations': apiData['total_pending_quotations'] ?? 0,
      'total_active_jobs': apiData['total_active_jobs'] ?? 0,
      'total_favorites': apiData['total_favorites'] ?? 0,
      'total_reviews_received': apiData['total_reviews_received'] ?? 0,
      'professional_profile_completed': apiData['professional_profile_completed'] ?? false,
      'professional_profile_approved': apiData['professional_profile_approved'] ?? false,
      // Données brutes pour extensions futures
      'raw_api_data': apiData,
    };
  }

  /// Retourne des données de démonstration réalistes pour le pro-client
  Map<String, dynamic> _getDemoDashboardData() {
    return {
      'total_jobs_as_client': 0,
      'total_jobs_as_professional': 0,
      'total_pending_quotations': 0,
      'total_active_jobs': 0,
      'total_favorites': 0,
      'total_reviews_received': 0,
      'professional_profile_completed': false,
      'professional_profile_approved': false,
    };
  }

  /// Méthode principale pour récupérer toutes les données du dashboard pro-client
  Future<Map<String, dynamic>> getAllDashboardData() async {
    try {
      final data = await getDashboardStats();
      return data;
    } catch (e) {
      print('Erreur lors de la récupération des données du dashboard pro-client: $e');
      return _getDemoDashboardData();
    }
  }
}
