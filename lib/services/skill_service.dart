import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart' as app_constants;

class SkillService {
  // Utilisation de la constante apiBaseUrl avec le préfixe
  final String baseUrl = '${app_constants.apiBaseUrl}/professional/skills';
  
  // Récupérer toutes les compétences disponibles
  Future<List<dynamic>> getAvailableSkills() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      final response = await http.get(
        Uri.parse('$baseUrl/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes))['data'];
      } else {
        throw Exception('Failed to load skills');
      }
    } catch (e) {
      throw Exception('Error fetching skills: $e');
    }
  }

  // Récupérer les compétences de l'utilisateur
  Future<List<dynamic>> getUserSkills() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      final response = await http.get(
        Uri.parse('$baseUrl/me/list'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes))['data'];
      } else {
        throw Exception('Failed to load user skills');
      }
    } catch (e) {
      throw Exception('Error fetching user skills: $e');
    }
  }

  // Ajouter une compétence
  Future<dynamic> addSkill(String skillId, int experienceYears, String level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      final response = await http.post(
        Uri.parse('$baseUrl/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'skill_id': skillId,
          'experience_years': experienceYears,
          'level': level,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes))['data'];
      } else {
        throw Exception('Failed to add skill');
      }
    } catch (e) {
      throw Exception('Error adding skill: $e');
    }
  }

  // Mettre à jour une compétence
  Future<dynamic> updateSkill(String skillId, {int? experienceYears, String? level}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      final Map<String, dynamic> body = {};
      if (experienceYears != null) body['experience_years'] = experienceYears;
      if (level != null) body['level'] = level;
      
      final response = await http.put(
        Uri.parse('$baseUrl/me/$skillId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes))['data'];
      } else {
        throw Exception('Failed to update skill');
      }
    } catch (e) {
      throw Exception('Error updating skill: $e');
    }
  }

  // Supprimer une compétence
  Future<bool> deleteSkill(String skillId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/me/$skillId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      throw Exception('Error deleting skill: $e');
    }
  }
}
