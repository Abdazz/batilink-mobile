import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/professional.dart';

class ProfessionalService {
  final String baseUrl;
  
  ProfessionalService({required this.baseUrl});

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<List<Professional>> getInteractedProfessionals() async {
    final token = await _getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/professionals/interacted'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body)['data'] ?? [];
        return data.map((json) => Professional.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching professionals: $e');
      return [];
    }
  }

  Future<bool> toggleFavorite(String professionalId) async {
    final token = await _getToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/favorites/professionals/$professionalId/toggle'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error toggling favorite: $e');
      return false;
    }
  }
}
