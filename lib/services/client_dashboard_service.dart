import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ClientDashboardService {
  final String baseUrl;

  ClientDashboardService({required this.baseUrl});

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

  /// Récupère les statistiques du dashboard client
  Future<Map<String, dynamic>> getDashboardStats() async {
    final token = await _getToken();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dashboard/client'),
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
        print('Endpoint dashboard client non trouvé - utilisation des données de démonstration');
        return _getDemoDashboardData();
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors de la récupération des statistiques client: $e');
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
      'total_favoris': apiData['total_favoris'] ?? 0,
      'total_professionnels': apiData['total_professionnels'] ?? 0,
      'prochain_rendez_vous': apiData['prochain_rendez_vous'],
      'dernier_devis_envoye': apiData['dernier_devis_envoye'],
      'dernier_devis_accepte': apiData['dernier_devis_accepte'],
      'dernier_pro_devis': apiData['dernier_pro_devis'],
      // Ajouter les données brutes pour d'éventuelles extensions futures
      'raw_api_data': apiData,
    };
  }

  /// Retourne des données de démonstration réalistes pour le client
  Map<String, dynamic> _getDemoDashboardData() {
    return {
      'total_favoris': 0,
      'total_professionnels': 0,
      'prochain_rendez_vous': null,
      'dernier_devis_envoye': null,
      'dernier_devis_accepte': null,
      'dernier_pro_devis': null,
    };
  }

  /// Méthode principale pour récupérer toutes les données du dashboard client
  Future<Map<String, dynamic>> getAllDashboardData() async {
    try {
      final data = await getDashboardStats();
      return data;
    } catch (e) {
      print('Erreur lors de la récupération des données du dashboard client: $e');
      return _getDemoDashboardData();
    }
  }
}
