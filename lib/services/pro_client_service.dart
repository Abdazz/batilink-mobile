import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ProClientService {
  final String baseUrl;
  final AuthService authService;

  ProClientService({required this.baseUrl, required this.authService});

  // Retourne l'URL de base telle quelle (pas de conversion automatique)
  String get effectiveBaseUrl {
    String url = baseUrl;
    // Supprimer le slash final s'il existe
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  // ==================== PROFIL ====================

  Future<http.Response> getProClientProfile({
    required String accessToken,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/pro-client/complete-profile');
    print('=== DEBUG - Récupération profil complet pro-client ===');
    print('Base URL: $effectiveBaseUrl');
    print('Full URL: $url');
    print('Token reçu: $accessToken');
    print('Token longueur: ${accessToken.length}');

    // Vérifier si le token est vide
    if (accessToken.isEmpty) {
      print('ERREUR: Token vide reçu !');
      return http.Response('{"message":"Token manquant"}', 401);
    }

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 10));

      print('Réponse profil complet pro-client: ${response.statusCode}');
      print('Headers: ${response.headers}');
      print('Corps réponse profil complet pro-client: ${response.body}');

      if (response.statusCode == 404) {
        print('ENDPOINT NON TROUVÉ: /api/pro-client/complete-profile');
        print('Vérifiez que cet endpoint existe côté serveur');
      }

      return response;
    } catch (e) {
      print('Erreur lors de la requête profil: $e');
      rethrow;
    }
  }

  Future<http.Response> completeProClientProfile({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/pro-client/profile/complete');
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

  Future<http.Response> updateProClientProfile({
    required String accessToken,
    required Map<String, dynamic> payload,
    String? profileId,
  }) async {
    final url = profileId != null && profileId.isNotEmpty
        ? '${effectiveBaseUrl}/api/pro-client/profile/$profileId'
        : '${effectiveBaseUrl}/api/pro-client/profile';

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );

    return response;
  }

  Future<http.Response> getProClientDashboard({
    required String accessToken,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/pro-client/dashboard');
    print('=== DEBUG - Récupération dashboard pro-client ===');
    print('Base URL: $effectiveBaseUrl');
    print('Full URL: $url');
    print('Token reçu: $accessToken');
    print('Token longueur: ${accessToken.length}');

    // Vérifier si le token est vide
    if (accessToken.isEmpty) {
      print('ERREUR: Token vide reçu pour dashboard !');
      return http.Response('{"message":"Token manquant"}', 401);
    }

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 10));

      print('Réponse dashboard pro-client: ${response.statusCode}');
      print('Corps réponse dashboard pro-client: ${response.body}');

      if (response.statusCode == 404) {
        print('ENDPOINT NON TROUVÉ: /api/pro-client/dashboard');
        print('Vérifiez que cet endpoint existe côté serveur');
      }

      return response;
    } catch (e) {
      print('Erreur lors de la requête dashboard: $e');
      rethrow;
    }
  }

  // ==================== MODE CLIENT ====================

  Future<http.Response> getClientJobs({
    required String accessToken,
    Map<String, dynamic>? filters,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/pro-client/jobs/client');
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final response = filters != null && filters.isNotEmpty
        ? await http.post(url, headers: headers, body: jsonEncode(filters))
        : await http.get(url, headers: headers);

    print('Réponse jobs client pro-client: ${response.statusCode}');
    return response;
  }

  Future<http.Response> createClientJob({
    required String accessToken,
    required Map<String, dynamic> jobData,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/pro-client/jobs/client');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(jobData),
    );

    print('Réponse création job client pro-client: ${response.statusCode}');
    return response;
  }

  // ==================== MODE PROFESSIONNEL ====================

  Future<http.Response> getProfessionalJobs({
    required String accessToken,
    Map<String, dynamic>? filters,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/pro-client/jobs/professional');
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final response = filters != null && filters.isNotEmpty
        ? await http.post(url, headers: headers, body: jsonEncode(filters))
        : await http.get(url, headers: headers);

    print('Réponse jobs professionnel pro-client: ${response.statusCode}');
    return response;
  }

  Future<http.Response> submitProfessionalProposal({
    required String accessToken,
    required String jobId,
    required Map<String, dynamic> proposalData,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/pro-client/jobs/$jobId/proposals/professional');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(proposalData),
    );

    print('Réponse soumission proposition pro-client: ${response.statusCode}');
    return response;
  }

  // ==================== QUOTATIONS (endpoints existants) ====================

  Future<http.Response> getQuotations({
    required String accessToken,
    String? context, // 'client', 'professional', ou null pour automatique
  }) async {
    // Construire l'URL avec les paramètres de requête
    final Uri url;
    if (context != null) {
      url = Uri.parse('${effectiveBaseUrl}/api/quotations?context=$context');
    } else {
      url = Uri.parse('${effectiveBaseUrl}/api/quotations');
    }

    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final response = await http.get(url, headers: headers);

    print('Réponse quotations pro-client: ${response.statusCode}');
    print('URL appelée: $url');
    return response;
  }

  Future<http.Response> updateQuotation({
    required String accessToken,
    required String quotationId,
    required Map<String, dynamic> quotationData,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/quotations/$quotationId');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(quotationData),
    );

    print('Réponse mise à jour quotation pro-client: ${response.statusCode}');
    return response;
  }

  Future<http.Response> acceptQuotation({
    required String accessToken,
    required String quotationId,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/quotations/$quotationId/accept');
    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    print('Réponse acceptation quotation pro-client: ${response.statusCode}');
    return response;
  }

  Future<http.Response> startJob({
    required String accessToken,
    required String quotationId,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/quotations/$quotationId/start');
    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    print('Réponse démarrage job pro-client: ${response.statusCode}');
    return response;
  }

  Future<http.Response> completeJob({
    required String accessToken,
    required String quotationId,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/quotations/$quotationId/complete');
    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    print('Réponse finalisation job pro-client: ${response.statusCode}');
    return response;
  }

  Future<http.Response> cancelQuotation({
    required String accessToken,
    required String quotationId,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/quotations/$quotationId/cancel');
    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    print('Réponse annulation quotation pro-client: ${response.statusCode}');
    return response;
  }

  // ==================== JOBS GÉNÉRIQUES ====================

  Future<http.Response> getJobs({
    required String accessToken,
    Map<String, dynamic>? filters,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/jobs');
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final response = filters != null && filters.isNotEmpty
        ? await http.post(url, headers: headers, body: jsonEncode(filters))
        : await http.get(url, headers: headers);

    print('Réponse jobs génériques pro-client: ${response.statusCode}');
    return response;
  }

  Future<http.Response> getJobById({
    required String accessToken,
    required String jobId,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/jobs/$jobId');
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    print('Réponse job par ID pro-client: ${response.statusCode}');
    return response;
  }

  // ==================== PARSING ====================

  Future<Map<String, dynamic>?> parseProClientProfileResponse(http.Response response) async {
    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['success'] == true && data['data'] != null) {
        final profileData = data['data'];

        // Structure complète: user, professional, stats, recent_activity
        if (profileData is Map<String, dynamic>) {
          return profileData;
        }
      }
    }
    return null;
  }

  Future<List<dynamic>?> parseJobsResponse(http.Response response) async {
    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['success'] == true && data['data'] != null) {
        final jobsData = data['data'];

        if (jobsData is List) {
          return jobsData;
        }
      }
    }
    return null;
  }
}
