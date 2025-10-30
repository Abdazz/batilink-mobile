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
    String? status,
    String? userId,
  }) async {
    // Créer une copie des filtres pour les modifier
    final requestFilters = Map<String, dynamic>.from(filters ?? {});
    
    // Ajouter les filtres de statut et d'utilisateur s'ils sont fournis
    if (status != null) requestFilters['status'] = status;
    if (userId != null) requestFilters['user_id'] = userId;
    
    final url = Uri.parse('${effectiveBaseUrl}/api/pro-client/jobs/client');
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    print('Filtres de requête: $requestFilters');
    
    final response = requestFilters.isNotEmpty
        ? await http.post(
            url, 
            headers: {
              ...headers,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestFilters),
          )
        : await http.get(url, headers: headers);

    print('Réponse jobs client pro-client: ${response.statusCode}');
    print('Corps de la réponse: ${response.body}');
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

  Future<http.Response> getQuotationById({
    required String accessToken,
    required String quotationId,
  }) async {
    final url = Uri.parse('${effectiveBaseUrl}/api/quotations/$quotationId');
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    print('Réponse quotation par ID: ${response.statusCode}');
    print('URL appelée: $url');
    return response;
  }

  Future<http.Response> getQuotations({
    required String accessToken,
    String? context, // 'client', 'professional', ou null pour automatique
    String? status, // Filtre par statut
    String? userId, // Filtre par utilisateur
  }) async {
    try {
      // Construire l'URL avec les paramètres de requête
      final params = <String, dynamic>{};
      
      // Ajouter les paramètres de requête uniquement s'ils ne sont pas null
      if (context != null && context.isNotEmpty) {
        params['context'] = context;
      }
      
      if (status != null && status.isNotEmpty) {
        params['status'] = status;
      }
      
      if (userId != null && userId.isNotEmpty) {
        params['user_id'] = userId;
      }
      
      // Construire l'URL de base
      final baseUrl = '${effectiveBaseUrl}/api/quotations';
      
      // Créer l'URI avec les paramètres de requête
      final uri = Uri.parse(baseUrl).replace(
        queryParameters: params.isNotEmpty ? params : null,
      );
      
      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

      print('Envoi de la requête GET vers: $uri');
      print('Headers: $headers');
      print('Paramètres: $params');

      final response = await http.get(uri, headers: headers);

      print('Réponse reçue - Statut: ${response.statusCode}');
      print('Headers de la réponse: ${response.headers}');
      
      if (response.statusCode != 200) {
        print('Erreur dans la réponse: ${response.body}');
      }
      
      return response;
    } catch (e) {
      print('Erreur lors de la récupération des devis: $e');
      rethrow;
    }
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
      try {
        final data = json.decode(response.body);
        print('Données brutes de la réponse: $data');
        
        // Vérifier si la réponse contient directement les données du profil
        if (data is Map && data['data'] != null) {
          if (data['data'] is Map) {
            return data['data'] as Map<String, dynamic>;
          } else if (data['data'] is List) {
            return {'quotations': data['data']};
          }
        }
        
        // Si la réponse est directement une liste de devis
        if (data is Map && data['quotations'] is List) {
          return {'quotations': data['quotations']};
        }
        
        // Si la réponse est une liste directe (format alternatif)
        if (data is List) {
          return {'quotations': data};
        }
        
        // Si nous avons une clé 'data' mais qu'elle n'est ni une Map ni une List
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        
        print('Format de réponse non reconnu');
        return null;
      } catch (e) {
        print('Erreur lors de l\'analyse de la réponse: $e');
        return null;
      }
    } else {
      print('Erreur HTTP ${response.statusCode}: ${response.body}');
      return null;
    }
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
