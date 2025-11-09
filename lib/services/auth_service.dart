import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:batilink_mobile_app/core/app_config.dart';
import 'package:batilink_mobile_app/utils/error_handler.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final String baseUrl;
  AuthService({required this.baseUrl});

  // Méthode utilitaire pour gérer les erreurs
  Future<void> _handleError(dynamic error, StackTrace stackTrace, {String? customMessage}) async {
    // Journalisation de l'erreur complète pour le débogage
    debugPrint('Erreur d\'authentification: $error');
    debugPrint('Stack trace: $stackTrace');

    // Gestion des erreurs spécifiques
    String errorMessage = customMessage ?? 'Une erreur est survenue';
    
    if (error is SocketException) {
      errorMessage = 'Impossible de se connecter au serveur. Vérifiez votre connexion Internet.';
    } else if (error is TimeoutException) {
      errorMessage = 'La connexion a expiré. Veuillez réessayer.';
    } else if (error is http.ClientException) {
      errorMessage = 'Erreur de communication avec le serveur.';
    } else if (error is FormatException) {
      errorMessage = 'Erreur de format des données reçues du serveur.';
    }

    // Afficher une notification à l'utilisateur
    await ErrorHandler.handleNetworkError(
      error,
      stackTrace,
      customMessage: errorMessage,
    );
  }

  // Retourne l'URL de base telle quelle (pas de conversion automatique)
  String get effectiveBaseUrl {
    String url = baseUrl;
    // Supprimer le slash final s'il existe
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  // Configuration intelligente - essaie le nom de domaine, bascule sur IP si DNS échoue
  bool _useDirectIPFallback = false;
  
  // Récupère le token JWT de l'utilisateur connecté
  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Utiliser la même clé que SessionService
      return prefs.getString('token');
    } catch (e) {
      print('Erreur lors de la récupération du token: $e');
      return null;
    }
  }

  // Test de connectivité avec diagnostic intelligent
  static Future<String> diagnoseConnection() async {
    print('🔍 DIAGNOSTIC DE CONNEXION...');

    // Test 1: Vérifier la connectivité Internet de base
    try {
      final testUrl = Uri.parse('https://www.google.com');
      await http.get(testUrl).timeout(const Duration(seconds: 5));
      print('✅ Connectivité Internet OK');
    } catch (e) {
      print('❌ Pas de connectivité Internet: $e');
      return 'PAS_DE_CONNEXION_INTERNET';
    }

    // Test 2: Tester le nom de domaine principal
    try {
      final domainUrl = Uri.parse('${AppConfig.baseUrl}/api/health');
      final response = await http.get(domainUrl).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        print('✅ Nom de domaine accessible: ${AppConfig.baseUrl}');
        return 'DOMAINE_OK';
      }
    } catch (e) {
      print('❌ Problème avec le nom de domaine: $e');

      // Test 3: Si c'est une erreur de sécurité réseau, tester l'IP directe
      if (e.toString().contains('Operation not permitted') ||
          e.toString().contains('errno = 1') ||
          e.toString().contains('Failed host lookup')) {

        try {
          final ipUrl = Uri.parse('https://${AppConfig.directIP}/api/health');
          final response = await http.get(ipUrl).timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            print('✅ IP directe accessible: ${AppConfig.directIP}');
            return 'IP_DIRECTE_OK';
          }
        } catch (ipError) {
          print('❌ IP directe aussi inaccessible: $ipError');
          return 'IP_DIRECTE_ECHEC';
        }
      }
    }

    return 'ERREUR_INCONNUE';
  }

  // URL intelligente qui bascule automatiquement
  String get _smartBaseUrl {
    if (_useDirectIPFallback) {
      return AppConfig.useDirectIP
          ? 'https://${AppConfig.directIP}'
          : AppConfig.baseUrl;
    }
    return AppConfig.baseUrl;
  }

  // Client HTTP intelligent
  http.Client get _smartHttpClient {
    if (_useDirectIPFallback && AppConfig.ignoreSSLCertificate) {
      final ioClient = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;
      return IOClient(ioClient);
    }
    return http.Client();
  }

  Future<http.Response> loginWithDevice({
    required String email,
    required String password,
    String deviceName = 'batilink-mobile',
  }) async {
    try {
      final url = Uri.parse('${_smartBaseUrl}/api/login');
      final response = await _smartHttpClient.post(
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
      ).timeout(const Duration(seconds: 30));

      // Débogage pour voir la réponse brute
      print('=== DEBUG LOGIN RESPONSE ===');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('Headers: ${response.headers}');

      return response;

    } catch (e) {
      print('Erreur lors de la connexion device: $e');

      // Si c'est une erreur DNS et qu'on n'utilise pas encore l'IP, bascule automatiquement
      if ((e.toString().contains('Failed host lookup') ||
           e.toString().contains('No address') ||
           e.toString().contains('Operation not permitted')) &&
          !_useDirectIPFallback) {

        print('🔄 BASCULE AUTOMATIQUE: Tentative de connexion device avec l\'IP directe...');
        _useDirectIPFallback = true;

        try {
          final ipUrl = 'https://${AppConfig.directIP}/api/login';
          print('Tentative de connexion device avec IP directe: $ipUrl');

          final url = Uri.parse(ipUrl);
          final response = await _smartHttpClient.post(
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
          ).timeout(const Duration(seconds: 30));

          print('✅ Réponse de connexion device via IP (${response.statusCode})');
          return response;

        } catch (ipError) {
          print('❌ Échec de connexion device aussi avec l\'IP directe: $ipError');
          _useDirectIPFallback = false;
          rethrow;
        }
      }

      rethrow;
    }
  }
  Future<http.Response> registerProfessional({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) async {
    final url = Uri.parse('${_smartBaseUrl}/api/register');
    final response = await _smartHttpClient.post(
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
    ).timeout(const Duration(seconds: 30));
    return response;
  }

  Future<http.Response> login({
    required String email,
    required String password,
    String deviceName = 'batilink-mobile',
  }) async {
    try {
      // Essaie d'abord le nom de domaine (solution sécurisée)
      final url = Uri.parse('${_smartBaseUrl}/api/login');
      print('Tentative de connexion à: $url');
      print('Email: $email');
      print('Device: $deviceName');

      final response = await _smartHttpClient.post(
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
      ).timeout(const Duration(seconds: 30));

      print('Réponse de connexion: ${response.statusCode}');
      print('Corps de la réponse: ${response.body}');
      return response;

    } catch (e) {
      print('Erreur lors de la connexion: $e');

      // Diagnostic intelligent avant de basculer
      final diagnosis = await diagnoseConnection();

      if (diagnosis == 'IP_DIRECTE_OK' && !_useDirectIPFallback) {
        print('🔄 BASCULE AUTOMATIQUE: Tentative de connexion avec l\'IP directe...');
        _useDirectIPFallback = true;

        try {
          // Réessaie avec l'IP directe
          final ipUrl = 'https://${AppConfig.directIP}/api/login';
          print('Tentative de connexion avec IP directe: $ipUrl');

          final url = Uri.parse(ipUrl);
          final response = await _smartHttpClient.post(
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
          ).timeout(const Duration(seconds: 30));

          print('✅ Réponse de connexion via IP (${response.statusCode}): ${response.body}');
          return response;

        } catch (ipError) {
          print('❌ Échec de connexion aussi avec l\'IP directe: $ipError');
          _useDirectIPFallback = false; // Reset pour les prochaines tentatives
        }
      }

      // Messages d'erreur spécifiques selon le diagnostic
      if (diagnosis == 'PAS_DE_CONNEXION_INTERNET') {
        print('ERREUR: Aucune connexion Internet détectée');
        print('Solution: Vérifiez votre connexion WiFi ou mobile');
      } else if (diagnosis == 'IP_DIRECTE_ECHEC') {
        print('ERREUR: Serveur inaccessible');
        print('Le serveur ${AppConfig.directIP} ne répond pas');
      } else if (e.toString().contains('Operation not permitted') || e.toString().contains('errno = 1')) {
        print('ERREUR SECURITE RESEAU: L\'appareil bloque la connexion HTTPS');
        print('Solutions recommandées:');
        print('- Changez de réseau WiFi (certains réseaux d\'entreprise bloquent HTTPS)');
        print('- Utilisez un réseau mobile (4G/5G) au lieu du WiFi');
        print('- Activez un VPN pour contourner les restrictions');
        print('- Redémarrez votre application après avoir changé de réseau');
      }

      rethrow;
    }
  }

  Future<http.Response> getProfessionalProfile({
    required String accessToken,
  }) async {
    final url = Uri.parse('${_smartBaseUrl}/api/professional/profile/me');
    print('=== DEBUG - Récupération profil professionnel ===');
    print('URL: $url');

    final response = await _smartHttpClient.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    ).timeout(const Duration(seconds: 30));

    print('Réponse profil: ${response.statusCode}');
    print('Corps réponse profil: ${response.body}');
    return response;
  }

  Future<http.Response> getCurrentUser({
    required String accessToken,
  }) async {
    final url = Uri.parse('${_smartBaseUrl}/api/user');
    print('=== DEBUG - Récupération utilisateur actuel ===');
    print('URL: $url');

    final response = await _smartHttpClient.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    ).timeout(const Duration(seconds: 30));

    print('Réponse user: ${response.statusCode}');
    print('Corps réponse user: ${response.body}');
    return response;
  }

  Future<http.Response> getClientProfile({
    required String accessToken,
  }) async {
    final url = Uri.parse('${_smartBaseUrl}/api/client/profile');
    print('=== DEBUG - Récupération profil client ===');
    print('URL: $url');

    final response = await _smartHttpClient.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    ).timeout(const Duration(seconds: 30));

    print('Réponse profil client: ${response.statusCode}');
    print('Corps réponse profil client: ${response.body}');
    return response;
  }

  Future<http.Response> completeProfessionalProfile({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final url = Uri.parse('${_smartBaseUrl}/api/professional/profile/complete');
    final response = await _smartHttpClient.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 30));
    return response;
  }

  Future<http.Response> updateBusinessHours({
    required String accessToken,
    required String businessHoursJson,
  }) async {
    final url = Uri.parse('${_smartBaseUrl}/api/professional/profile/update-hours');
    final response = await _smartHttpClient.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'business_hours': businessHoursJson,
      }),
    ).timeout(const Duration(seconds: 30));
    return response;
  }

  Future<http.Response> getProClientProfile({
    required String accessToken,
  }) async {
    final url = Uri.parse('${_smartBaseUrl}/api/pro-client/profile/me');
    print('=== DEBUG - Récupération profil pro-client ===');
    print('URL: $url');

    final response = await _smartHttpClient.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    ).timeout(const Duration(seconds: 30));

    print('Réponse profil pro-client: ${response.statusCode}');
    print('Corps réponse profil pro-client: ${response.body}');
    return response;
  }

  Future<http.Response> completeProClientProfile({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final url = Uri.parse('${_smartBaseUrl}/api/pro-client/profile/complete');
    final response = await _smartHttpClient.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 30));
    return response;
  }

  Future<http.Response> updateProClientProfile({
    required String accessToken,
    required Map<String, dynamic> payload,
    String? profileId,
  }) async {
    final url = profileId != null && profileId.isNotEmpty
        ? '${_smartBaseUrl}/api/pro-client/profile/$profileId'
        : '${_smartBaseUrl}/api/pro-client/profile';

    print('=== DEBUG UPDATE PRO-CLIENT PROFILE ===');
    print('URL: $url');
    print('Profile ID: $profileId');
    print('Payload: $payload');
    print('===========================');

    final response = await _smartHttpClient.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 30));

    print('Réponse update profil pro-client: ${response.statusCode}');
    print('Corps réponse: ${response.body}');
    return response;
  }

  Future<http.StreamedResponse> uploadDocument({
    required String accessToken,
    required String filePath,
    required String type, // ex: 'id', 'kbis', 'professional_license', 'insurance_certificate', 'bank'
    String? name,
  }) async {
    final url = Uri.parse('${_smartBaseUrl}/api/professional/documents');
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
    // Vérifier d'abord la connexion Internet
    final hasConnection = await ErrorHandler.checkInternetConnection();
    if (!hasConnection) {
      throw SocketException('Aucune connexion Internet');
    }

    // Fonction pour effectuer l'inscription
    Future<http.Response> performRegistration(String url) async {
      debugPrint('Tentative d\'inscription vers: $url');

      final uri = Uri.parse(url);
      final body = {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'role': role,
      };

      debugPrint('Corps de la requête: $body');

      final response = await _smartHttpClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      debugPrint('Réponse du serveur (${response.statusCode}): ${response.body}');
      
      // Gestion des erreurs HTTP
      if (response.statusCode >= 400) {
        String errorMessage = 'Erreur lors de l\'inscription';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {
          // En cas d'erreur de parsing, on garde le message par défaut
        }
        
        await _handleError(
          Exception('Erreur HTTP ${response.statusCode}'),
          StackTrace.current,
          customMessage: errorMessage,
        );
      }
      
      return response;
    }

    try {
      // Essaie d'abord avec l'URL de base
      return await performRegistration('${_smartBaseUrl}/api/register');
    } catch (e, stackTrace) {
      await _handleError(e, stackTrace);
      
      // Tentative de basculement automatique si nécessaire
      if (!_useDirectIPFallback) {
        final connectionStatus = await diagnoseConnection();
        if (connectionStatus == 'IP_DIRECTE_OK') {
          debugPrint('🔄 BASCULE AUTOMATIQUE: Utilisation de l\'IP directe...');
          _useDirectIPFallback = true;

          try {
            // Réessaie avec l'IP directe
            return await performRegistration('https://${AppConfig.directIP}/api/register');
          } catch (ipError, ipStack) {
            debugPrint('❌ Échec aussi avec l\'IP directe: $ipError');
            _useDirectIPFallback = false; // Reset pour les prochaines tentatives
            await _handleError(ipError, ipStack);
          }
        }
      }

      // Messages d'erreur spécifiques
      if (e is SocketException) {
        await _handleError(
          e,
          stackTrace,
          customMessage: 'Impossible de se connecter au serveur. Vérifiez votre connexion Internet.',
        );
      } else if (e is TimeoutException) {
        await _handleError(
          e,
          stackTrace,
          customMessage: 'La connexion a expiré. Veuillez réessayer.',
        );
      }

      // Relancer l'erreur pour permettre une gestion supplémentaire si nécessaire
      rethrow;
    }
  }

  Future<bool> logout(String token) async {
    try {
      final url = Uri.parse('${_smartBaseUrl}/api/logout');
      final response = await _smartHttpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Supprimer le token du stockage local
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token'); // Utiliser la même clé que SessionService
        await prefs.remove('user');
        return true;
      }
      return false;
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> parseProfessionalProfileResponse(http.Response response) async {
    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['success'] == true && data['data'] != null) {
        final profileData = data['data'];

        // Nouvelle structure: data.data est un tableau
        if (profileData is Map && profileData['data'] != null && (profileData['data'] as List).isNotEmpty) {
          final profiles = profileData['data'] as List;

          // Chercher le profil avec les données les plus récentes (pas par défaut)
          for (var profile in profiles) {
            if (profile is Map<String, dynamic>) {
              final companyName = profile['company_name'] ?? '';
              if (companyName != 'Entreprise par défaut' && companyName.isNotEmpty) {
                return profile;
              }
            }
          }

          // Si pas trouvé, retourner le premier profil valide
          for (var profile in profiles) {
            if (profile is Map<String, dynamic> && profile['id'] != null) {
              return profile;
            }
          }
        }
        // Ancienne structure: data est directement le profil
        else if (profileData is Map<String, dynamic>) {
          return profileData;
        }
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> parseProClientProfileResponse(http.Response response) async {
    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['success'] == true && data['data'] != null) {
        final profileData = data['data'];

        // Nouvelle structure: data.data est un tableau
        if (profileData is Map && profileData['data'] != null && (profileData['data'] as List).isNotEmpty) {
          final profiles = profileData['data'] as List;

          // Chercher le profil avec les données les plus récentes (pas par défaut)
          for (var profile in profiles) {
            if (profile is Map<String, dynamic>) {
              final companyName = profile['company_name'] ?? '';
              if (companyName != 'Entreprise par défaut' && companyName.isNotEmpty) {
                return profile;
              }
            }
          }

          // Si pas trouvé, retourner le premier profil valide
          for (var profile in profiles) {
            if (profile is Map<String, dynamic> && profile['id'] != null) {
              return profile;
            }
          }
        }
        // Ancienne structure: data est directement le profil
        else if (profileData is Map<String, dynamic>) {
          return profileData;
        }
      }
    }
    return null;
  }
}
