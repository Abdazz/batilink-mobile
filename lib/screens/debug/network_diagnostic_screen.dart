import 'package:flutter/material.dart';
import '../../services/network_diagnostic.dart';

class NetworkDiagnosticWidget extends StatelessWidget {
  const NetworkDiagnosticWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic Réseau'),
        backgroundColor: Colors.red,
      ),
      body: FutureBuilder<NetworkDiagnosisResult>(
        future: NetworkDiagnostic.diagnoseConnection(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Diagnostic en cours...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Erreur: ${snapshot.error}'),
            );
          }

          final result = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status général
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: result.isConnected ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        result.isConnected ? Icons.check_circle : Icons.error,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.isConnected ? 'Connexion OK' : 'Problème de connexion',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (result.isConnected) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${result.responseTime}ms',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Détails du diagnostic
                const Text(
                  'Diagnostic détaillé:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                if (!result.isConnected && result.errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Text(
                      result.errorMessage!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),

                const SizedBox(height: 24),

                // Solutions recommandées
                const Text(
                  'Solutions à essayer:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                _buildSolutionCard(
                  '1. Changer de réseau',
                  'Essayez de passer du WiFi au réseau mobile (4G/5G) ou vice versa',
                  Icons.network_wifi,
                ),

                _buildSolutionCard(
                  '2. Utiliser un VPN',
                  'Activez un VPN - les VPN ont souvent de meilleurs serveurs DNS',
                  Icons.vpn_key,
                ),

                _buildSolutionCard(
                  '3. Modifier les DNS',
                  'Paramètres → WiFi → Appui long → Modifier réseau → DNS: 8.8.8.8',
                  Icons.dns,
                ),

                _buildSolutionCard(
                  '4. Redémarrer',
                  'Redémarrez votre appareil et réessayez',
                  Icons.restart_alt,
                ),

                const SizedBox(height: 24),

                // Bouton de retest
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Recharger la page
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const NetworkDiagnosticWidget()),
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retester la connexion'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSolutionCard(String title, String description, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}
