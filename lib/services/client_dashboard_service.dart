import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:batilink_mobile_app/utils/error_handler.dart';

class ClientDashboardService {
  final String baseUrl;

  ClientDashboardService({required this.baseUrl});

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print('Token récupéré depuis SharedPreferences: ${token != null ? 'Présent (${token.length} caractères)' : 'Absent'}');
    return token;
  }

  /// Récupère les statistiques du dashboard client
  Future<Map<String, dynamic>> getDashboardStats() async {
    // Vérifier d'abord la connexion Internet
    final hasConnection = await ErrorHandler.checkInternetConnection();
    if (!hasConnection) {
      // Une notification est déjà affichée par ErrorHandler
      return _getDemoDashboardData();
    }

    final token = await _getToken();
    if (token == null) {
      await ErrorHandler.handleNetworkError(
        Exception('Token non trouvé'),
        StackTrace.current,
        customMessage: 'Session expirée. Veuillez vous reconnecter.',
      );
      return _getDemoDashboardData();
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dashboard/client'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final apiData = Map<String, dynamic>.from(data['data']);
          return _mapApiDataToDashboardFormat(apiData);
        } else {
          throw Exception('Format de réponse inattendu');
        }
      } else if (response.statusCode == 401) {
        await ErrorHandler.handleNetworkError(
          Exception('Non autorisé'),
          StackTrace.current,
          customMessage: 'Session expirée. Veuillez vous reconnecter.',
        );
        return _getDemoDashboardData();
      } else if (response.statusCode == 404) {
        print('Endpoint dashboard client non trouvé - utilisation des données de démonstration');
        return _getDemoDashboardData();
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Erreur lors de la récupération des statistiques client: $e');
      await ErrorHandler.handleNetworkError(e, stackTrace);
      return _getDemoDashboardData();
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
      final data = await getDashboardStats().catchError((e, stackTrace) {
        // La gestion d'erreur est déjà faite dans getDashboardStats
        return _getDemoDashboardData();
      });
      return data;
    } catch (e) {
      print('Erreur lors de la récupération des données du dashboard client: $e');
      return _getDemoDashboardData();
    }
  }
}
