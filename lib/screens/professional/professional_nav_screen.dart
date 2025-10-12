import 'package:flutter/material.dart';

import 'professional_complete_profile_screen.dart';
import 'professional_dashboard_screen.dart';
import 'professional_settings_screen.dart';
import 'quotations_screen.dart';

class ProfessionalNavScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> profile;
  const ProfessionalNavScreen({super.key, required this.token, required this.profile});

  @override
  State<ProfessionalNavScreen> createState() => _ProfessionalNavScreenState();
}

class _ProfessionalNavScreenState extends State<ProfessionalNavScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DashboardTab(token: widget.token, profile: widget.profile),
      const _ClientsTab(),
      _QuotationsTab(token: widget.token),
      _SettingsTab(token: widget.token),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Mes clients'),
          NavigationDestination(icon: Icon(Icons.request_quote_outlined), selectedIcon: Icon(Icons.request_quote), label: 'Mes devis'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Paramètres'),
        ],
      ),
    );
  }
}

// Nouvel onglet pour les devis
class _QuotationsTab extends StatelessWidget {
  final String token;
  const _QuotationsTab({required this.token});

  @override
  Widget build(BuildContext context) {
    return QuotationsScreen(token: token);
  }
}

class _DashboardTab extends StatelessWidget {
  final String token;
  final Map<String, dynamic> profile;
  const _DashboardTab({required this.token, required this.profile});

  @override
  Widget build(BuildContext context) {
    return ProfessionalDashboardScreen(
      token: token,
      profile: profile,
    );
  }
}

class _ClientsTab extends StatelessWidget {
  const _ClientsTab();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Mes clients'));
  }
}

class _SettingsTab extends StatelessWidget {
  final String token;
  const _SettingsTab({required this.token});
  
  @override
  Widget build(BuildContext context) {
    return ProfessionalSettingsScreen(token: token);
  }
}
