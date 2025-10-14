import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String baseUrl;
  AuthService({required this.baseUrl});

  // Retourne l'URL de base telle quelle (pas de conversion automatique)
  String get effectiveBaseUrl {
    String url = baseUrl;
    // Supprimer le slash final s'il existe
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Future<http.Response> loginWithDevice({
    required String email,
    required String password,
    String deviceName = 'batilink-mobile',
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/login');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_name': deviceName,
      }),
    );
    return response;
  }
  Future<http.Response> registerProfessional({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/register');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'role': 'professional',
      }),
    );
    return response;
  }

  Future<http.Response> login({
    required String email,
    required String password,
    String deviceName = 'batilink-mobile',
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/login');
    print('Tentative de connexion à: $url');
    print('Email: $email');
    print('Device: $deviceName');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_name': deviceName,
      }),
    );

    print('Réponse de connexion: ${response.statusCode}');
    print('Corps de la réponse: ${response.body}');
    return response;
  }

  Future<http.Response> getProfessionalProfile({
    required String accessToken,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/professional/profile');
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return response;
  }

  Future<http.Response> completeProfessionalProfile({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/professional/profile/complete');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );
    return response;
  }

  Future<http.StreamedResponse> uploadDocument({
    required String accessToken,
    required String filePath,
    required String type, // ex: 'id', 'kbis', 'professional_license', 'insurance_certificate', 'bank'
    String? name,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/professional/documents');
    final request = http.MultipartRequest('POST', url);
    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    });
    request.fields['type'] = type;
    if (name != null && name.isNotEmpty) {
      request.fields['name'] = name;
    }
    final file = await http.MultipartFile.fromPath('document', filePath);
    request.files.add(file);
    return await request.send();
  }

  Future<http.Response> registerUser({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String role,
  }) async {
    try {
      final fullUrl = '${effectiveBaseUrl}/api/register';
      print('Tentative d\'inscription vers: $fullUrl');
      
      final url = Uri.parse(fullUrl);
      final body = {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'role': role,
      };
      
      print('Corps de la requête: $body');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );
      
      print('Réponse du serveur (${response.statusCode}): ${response.body}');
      
      return response;
    } catch (e) {
      print('Erreur lors de l\'inscription: $e');
      rethrow;
    }
  }

  Future<bool> logout(String token) async {
    try {
      final url = Uri.parse('${effectiveBaseUrl}/api/logout');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Supprimer le token du stockage local
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        await prefs.remove('user');
        return true;
      }
      return false;
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
      return false;
    }
  }
}
