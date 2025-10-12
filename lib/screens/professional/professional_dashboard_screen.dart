import 'package:flutter/material.dart';

class ProfessionalDashboardScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> profile;
  
  const ProfessionalDashboardScreen({
    super.key, 
    required this.token,
    required this.profile,
  });

  @override
  State<ProfessionalDashboardScreen> createState() => _ProfessionalDashboardScreenState();
}

class _ProfessionalDashboardScreenState extends State<ProfessionalDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord professionnel'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 20),
            _buildStatsGrid(),
            const SizedBox(height: 20),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bonjour, ${widget.profile['first_name'] ?? 'Professionnel'}'  ,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Bienvenue sur votre espace professionnel',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard('Rendez-vous', '12', Icons.calendar_today, Colors.blue),
        _buildStatCard('Clients', '8', Icons.people, Colors.green),
        _buildStatCard('Revenus', '1,450 €', Icons.euro, Colors.orange),
        _buildStatCard('Notes', '4.8/5', Icons.star, Colors.amber),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activité récente',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildActivityItem('Nouveau rendez-vous', 'Aujourd\'hui, 10:30', Icons.event),
            _buildDivider(),
            _buildActivityItem('Paiement reçu', 'Hier, 16:45', Icons.payment),
            _buildDivider(),
            _buildActivityItem('Nouveau message', 'Hier, 09:15', Icons.message),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // Gérer l'action de l'élément
      },
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: Divider(height: 1),
    );
  }
}
