/// Configuration centralisée de l'application
/// Ce fichier gère toutes les URLs et configurations réseau de manière centralisée
class AppConfig {
  // Configuration des environnements
  static const Environment environment = Environment.production;

  // Configuration des URLs de base selon l'environnement
  static String get baseUrl {
    switch (environment) {
      case Environment.development:
        return 'http://10.0.2.2:8000';
      case Environment.staging:
        return 'https://staging-api.batilink.com';
      case Environment.production:
        return 'https://batilink.golden-technologies.com';
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
}

/// Enumération des environnements
enum Environment {
  development,
  staging,
  production,
}
