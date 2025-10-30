/// Configuration centralisée de l'application
/// Ce fichier gère toutes les URLs et configurations réseau de manière centralisée
import 'package:http/http.dart' as http;
class AppConfig {
  // Configuration des environnements
  static const Environment environment = Environment.development;

  // Configuration alternative - IP directe (si DNS pose problème)
  static const bool useDirectIP = true; // Mettez à true si vous avez des problèmes DNS
  static const bool ignoreSSLCertificate = false; // Ignorer validation SSL (pour tests IP directe)
  static const bool useHTTP = false; // Utiliser HTTP au lieu de HTTPS (non sécurisé, pour tests)
  static const String directIP = '147.79.115.191'; // IP réelle du serveur (résolue via nslookup)

  // Configuration des URLs de base selon l'environnement
  /// Corrige une URL d'avatar qui pourrait utiliser localhost
  static String fixAvatarUrl(String url) {
    if (url.startsWith('http://localhost') || url.startsWith('https://localhost')) {
      // Récupérer le chemin après localhost
      final uri = Uri.parse(url);
      final path = uri.path;
      
      // Construire la nouvelle URL avec la baseUrl
      final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      final newUrl = '${base}${path.startsWith('/') ? path.substring(1) : path}';
      
      // Conserver les paramètres de requête s'ils existent
      if (uri.queryParameters.isNotEmpty) {
        return '$newUrl?${uri.query}';
      }
      return newUrl;
    }
    return url;
  }

  static String get baseUrl {
    String protocol = 'https://';

    // Si on utilise HTTP (non sécurisé, pour tests seulement)
    if (useHTTP) {
      protocol = 'http://';
    }

    // Si on utilise l'IP directe (pour éviter les problèmes DNS)
    if (useDirectIP) {
      switch (environment) {
        case Environment.development:
          return 'http://10.0.2.2:8000';
        case Environment.staging:
          return '${protocol}staging-api.batilink.com';
        case Environment.production:
          return '${protocol}$directIP';
      }
    }

    // Configuration normale avec nom de domaine
    switch (environment) {
      case Environment.development:
        return 'http://10.0.2.2:8000';
      case Environment.staging:
        return '${protocol}staging-api.batilink.com';
      case Environment.production:
        return '${protocol}batilink.golden-technologies.com';
    }
  }

  // URL de l'API avec le endpoint
  static String get apiBaseUrl => '$baseUrl/api';

  // URL pour les images et médias
  static String get mediaBaseUrl => '$baseUrl/storage';

  // Configuration des timeouts
  static const int connectTimeout = 30000; // 30 secondes
  static const int receiveTimeout = 30000; // 30 secondes

  // Configuration des retries
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);

  // Helper method pour construire une URL complète
  static String buildUrl(String endpoint, {Map<String, dynamic>? queryParams}) {
    String url = endpoint.startsWith('/') ? '$apiBaseUrl$endpoint' : '$apiBaseUrl/$endpoint';

    if (queryParams != null && queryParams.isNotEmpty) {
      final params = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      url += '?$params';
    }

    return url;
  }

  // Helper method pour construire une URL de média
  static String buildMediaUrl(String? mediaPath) {
    if (mediaPath == null || mediaPath.isEmpty) {
      return '';
    }

    // Si c'est déjà une URL complète (http/https)
    if (mediaPath.startsWith('http://') || mediaPath.startsWith('https://')) {
      return mediaPath;
    }

    // Si c'est un placeholder ou URL externe
    if (mediaPath.contains('placeholder') || mediaPath.contains('via.placeholder')) {
      return mediaPath;
    }

    // Construire l'URL complète du média
    return mediaPath.startsWith('/') ? '$mediaBaseUrl$mediaPath' : '$mediaBaseUrl/$mediaPath';
  }

  // Validation de la connectivité
  static bool isValidUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  // Test de connectivité réseau (utile pour diagnostiquer les problèmes)
  static Future<bool> testConnectivity() async {
    try {
      final url = Uri.parse('$baseUrl/api/health');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print('Test de connectivité échoué: $e');
      return false;
    }
  }

  // Diagnostiquer les problèmes réseau
  static Future<String> diagnoseNetworkIssue() async {
    // Test 1: Vérifier si on peut résoudre le nom de domaine
    try {
      final url = Uri.parse('$baseUrl/api/register');
      await http.get(url).timeout(const Duration(seconds: 5));
      return 'Connexion OK';
    } catch (e) {
      if (e.toString().contains('Failed host lookup') || e.toString().contains('No address')) {
        return 'PROBLEME_DNS: Le nom de domaine ne peut pas être résolu. Essayez avec l\'IP directe.';
      } else if (e.toString().contains('TimeoutException')) {
        return 'PROBLEME_TIMEOUT: Le serveur ne répond pas. Vérifiez que le serveur est en ligne.';
      } else if (e.toString().contains('connection')) {
        return 'PROBLEME_CONNEXION: Problème de connectivité réseau.';
      }
      return 'ERREUR_INCONNUE: $e';
    }
  }
}

/// Enumération des environnements
enum Environment {
  development,
  staging,
  production,
}
