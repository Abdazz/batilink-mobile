import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/auth_service.dart';
import 'client_dashboard_screen.dart';
import 'professional_search_screen.dart';

class ClientProfileScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> userData;

  const ClientProfileScreen({
    Key? key,
    required this.token,
    required this.userData,
  }) : super(key: key);

  @override
  _ClientProfileScreenState createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  int _selectedIndex = 3; // Index pour l'onglet Profil

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final token = widget.token;

      if (token == null || token.isEmpty) {
        _showError('Token d\'authentification manquant');
        return;
      }

      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/client/profile'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _userData = data['data'];
          _isLoading = false;
        });
      } else {
        // Si l'API ne fonctionne pas, utiliser des données de test
        _loadTestData();
      }
    } catch (e) {
      // En cas d'erreur, utiliser des données de test
      _loadTestData();
    }
  }

  void _loadTestData() {
    setState(() {
      _userData = {
        'id': '05fbf42b-469b-4743-a7ac-c1d77f0be3cd',
        'first_name': 'John',
        'last_name': 'Doe',
        'email': 'johndoe20@gmail.com',
        'phone': '+12345678911',
        'role': 'client',
        'avatar': null,
        'created_at': '2025-10-13T09:57:39.000000Z',
        'updated_at': '2025-10-13T09:57:39.000000Z',
      };
      _isLoading = false;
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onNavigationTap(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0: // Accueil
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClientDashboardScreen(
              token: widget.token,
              userData: widget.userData,
              profile: {},
            ),
          ),
        );
        break;
      case 1: // Recherche
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProfessionalSearchScreen(
              token: widget.token,
              userData: widget.userData,
            ),
          ),
        );
        break;
      case 2: // Rendez-vous
        // TODO: Implémenter la page des rendez-vous
        break;
      case 3: // Profil (page actuelle)
        break;
    }
  }

  Future<void> _logout() async {
    try {
      final token = widget.token;

      if (token != null) {
        final authService = AuthService(baseUrl: 'http://10.0.2.2:8000');
        await authService.logout(token);
      }

      // Supprimer les données locales après l'appel API
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user');
      await prefs.remove('user_role');

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/welcome',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la déconnexion'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mon Profil',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        // Enlever le bouton retour
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4CAF50),
              ),
            )
          : _userData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur lors du chargement du profil',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUserProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Réessayer',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Informations personnelles
                      _buildSectionTitle('Informations personnelles'),
                      const SizedBox(height: 12),
                      _buildInfoCard(),

                      const SizedBox(height: 24),

                      // Section Actions rapides
                      _buildSectionTitle('Actions rapides'),
                      const SizedBox(height: 12),
                      _buildActionButtons(),

                      const SizedBox(height: 24),

                      // Section Statistiques (optionnel)
                      _buildSectionTitle('Activité'),
                      const SizedBox(height: 12),
                      _buildStatsCard(),

                      const SizedBox(height: 32),

                      // Bouton de déconnexion (en bas)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: Text(
                            'Déconnexion',
                            style: GoogleFonts.poppins(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavigationTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4CAF50),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Recherche',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Rendez-vous',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF4CAF50),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Avatar et nom
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                    border: Border.all(
                      color: const Color(0xFF4CAF50),
                      width: 2,
                    ),
                  ),
                  child: _userData?['avatar'] != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: _userData!['avatar'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const CircularProgressIndicator(),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.person,
                              color: Color(0xFF4CAF50),
                              size: 30,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color: Color(0xFF4CAF50),
                          size: 30,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_userData?['first_name'] ?? ''} ${_userData?['last_name'] ?? ''}'.trim(),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _userData?['email'] ?? '',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      if (_userData?['phone'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _userData!['phone'],
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Informations détaillées
            _buildInfoRow('Rôle', _getRoleDisplayName(_userData?['role'])),
            if (_userData?['created_at'] != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow('Membre depuis', _formatDate(_userData!['created_at'])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildActionButton(
          icon: Icons.request_quote,
          title: 'Mes demandes de devis',
          subtitle: 'Voir toutes vos demandes et leurs réponses',
          onTap: () => Navigator.pushNamed(context, '/client/quotations'),
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          icon: Icons.favorite,
          title: 'Mes professionnels favoris',
          subtitle: 'Accéder rapidement à vos professionnels préférés',
          onTap: () => Navigator.pushNamed(context, '/client/favorites'),
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          icon: Icons.settings,
          title: 'Paramètres du profil',
          subtitle: 'Modifier vos informations personnelles',
          onTap: () => Navigator.pushNamed(context, '/client/profile/edit'),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF4CAF50),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('0', 'Devis envoyés'),
            _buildStatItem('0', 'Professionnels favoris'),
            _buildStatItem('0', 'Projets terminés'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF4CAF50),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getRoleDisplayName(String? role) {
    switch (role) {
      case 'client':
        return 'Client';
      case 'professional':
        return 'Professionnel';
      default:
        return role ?? 'Utilisateur';
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }
}
