import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String baseUrl;
  AuthService({required this.baseUrl});

  // Utilitaire pour l'émulateur Android : remplace localhost/127.0.0.1 par 10.0.2.2
  String get effectiveBaseUrl {
    if (baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1')) {
      return baseUrl.replaceAll('localhost', '10.0.2.2').replaceAll('127.0.0.1', '10.0.2.2');
    }
    return baseUrl;
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
    String deviceName = 'FlutterApp',
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
        'role': role,
      }),
    );
    return response;
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
