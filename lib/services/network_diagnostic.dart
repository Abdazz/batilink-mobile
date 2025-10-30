import 'package:http/http.dart' as http;
import '../core/app_config.dart';

class NetworkDiagnostic {
  /// Diagnostiquer les problèmes de connectivité
  static Future<NetworkDiagnosisResult> diagnoseConnection() async {
    print('=== DIAGNOSTIC RESEAU ===');
    print('URL configurée: ${AppConfig.baseUrl}');
    print('Environnement: ${AppConfig.environment}');
    print('Utilise IP directe: ${AppConfig.useDirectIP}');

    try {
      // Test 1: Résolution DNS / Connectivité de base
      print('\nTest 1: Résolution DNS et connectivité...');
      final url = Uri.parse('${AppConfig.baseUrl}/api/register');

      final stopwatch = Stopwatch()..start();
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      stopwatch.stop();

      print('✅ Connexion réussie en ${stopwatch.elapsedMilliseconds}ms');
      print('Status: ${response.statusCode}');
      print('Headers: ${response.headers}');

      return NetworkDiagnosisResult(
        isConnected: true,
        responseTime: stopwatch.elapsedMilliseconds,
        statusCode: response.statusCode,
        errorMessage: null,
      );

    } catch (e) {
      print('❌ Erreur de connexion: $e');

      String diagnosis = '';
      if (e.toString().contains('Failed host lookup') || e.toString().contains('No address')) {
        diagnosis = 'PROBLEME_DNS: Le nom de domaine "${AppConfig.baseUrl.replaceAll('https://', '').replaceAll('http://', '')}" ne peut pas être résolu.\n\nSolutions:\n1. Vérifiez votre connexion internet\n2. Changez de réseau (WiFi ↔ Mobile)\n3. Utilisez un VPN\n4. Modifiez les DNS: 8.8.8.8 / 8.8.4.4';
      } else if (e.toString().contains('Operation not permitted') || e.toString().contains('errno = 1')) {
        diagnosis = 'PROBLEME_SECURITE: L\'appareil bloque la connexion sécurisée.\n\nSolutions:\n1. Changez de réseau WiFi\n2. Utilisez un réseau mobile (4G/5G)\n3. Activez un VPN\n4. Vérifiez les paramètres de sécurité du réseau WiFi';
      } else if (e.toString().contains('TimeoutException')) {
        diagnosis = 'PROBLEME_TIMEOUT: Le serveur ne répond pas.\n\nSolutions:\n1. Vérifiez que le serveur est en ligne\n2. Vérifiez votre connexion internet\n3. Essayez plus tard';
      } else if (e.toString().contains('connection')) {
        diagnosis = 'PROBLEME_CONNEXION: Problème de connectivité réseau.\n\nSolutions:\n1. Vérifiez votre connexion internet\n2. Essayez de vous connecter à un autre site web\n3. Redémarrez votre connexion WiFi/mobile';
      } else {
        diagnosis = 'ERREUR_INCONNUE: $e';
      }

      return NetworkDiagnosisResult(
        isConnected: false,
        responseTime: 0,
        statusCode: 0,
        errorMessage: diagnosis,
      );
    }
  }

  /// Obtenir l'IP du nom de domaine (pour diagnostic)
  static Future<String?> resolveDomainToIP(String domain) async {
    try {
      // Note: Flutter ne peut pas directement résoudre DNS
      // Cette méthode est pour documentation
      print('Pour résoudre $domain en IP:');
      print('1. Ouvrez le terminal');
      print('2. Tapez: nslookup $domain');
      print('3. Ou: ping $domain');
      return null;
    } catch (e) {
      print('Erreur lors de la résolution: $e');
      return null;
    }
  }
}

class NetworkDiagnosisResult {
  final bool isConnected;
  final int responseTime;
  final int statusCode;
  final String? errorMessage;

  NetworkDiagnosisResult({
    required this.isConnected,
    required this.responseTime,
    required this.statusCode,
    required this.errorMessage,
  });

  @override
  String toString() {
    if (isConnected) {
      return '✅ Connexion OK (${responseTime}ms, Status: $statusCode)';
    } else {
      return '❌ Connexion échouée: $errorMessage';
    }
  }
}
