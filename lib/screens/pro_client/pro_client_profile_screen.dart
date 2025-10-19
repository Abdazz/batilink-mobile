import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

class ProClientProfileScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> userData;

  const ProClientProfileScreen({
    Key? key,
    required this.token,
    required this.userData,
  }) : super(key: key);

  @override
  _ProClientProfileScreenState createState() => _ProClientProfileScreenState();
}

class _ProClientProfileScreenState extends State<ProClientProfileScreen> {
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _professionalData;
  bool _isLoading = true;
  int _selectedIndex = 3; // Index pour l'onglet Profil
  String? _errorMessage;
  String _token = '';

  // Statistiques du pro-client
  int _totalJobsAsClient = 0;
  int _totalJobsAsProfessional = 0;
  int _totalPendingQuotations = 0;
  int _totalActiveJobs = 0;
  int _totalFavorites = 0;
  int _totalReviewsReceived = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Récupérer le token depuis SharedPreferences comme secours
    final prefs = await SharedPreferences.getInstance();
    final tokenFromPrefs = prefs.getString('token') ?? '';

    // Utiliser le token passé en argument, ou celui de SharedPreferences comme secours
    final finalToken = widget.token.isNotEmpty ? widget.token : tokenFromPrefs;

    if (finalToken.isEmpty) {
      _showError('Token d\'authentification manquant. Veuillez vous reconnecter.');
      return;
    }

    // Mettre à jour le token du widget
    setState(() {
      _token = finalToken;
    });

    _loadProClientProfile();
  }

  Future<void> _loadProClientProfile() async {
    try {
      final token = _token;
      if (token.isEmpty) {
        _showError('Token d\'authentification manquant');
        return;
      }

      print('=== DEBUG PROFIL PRO-CLIENT ===');
      print('Token utilisé: ${token.substring(0, 20)}...');

      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/pro-client/complete-profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Réponse reçue - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Données décodées: $data');

        if (data is Map<String, dynamic> && data.containsKey('data')) {
          final profileData = data['data'];
          print('Données de profil trouvées: $profileData');

          if (profileData is Map<String, dynamic>) {
            // Extraire les données utilisateur
            if (profileData.containsKey('user')) {
              final userData = profileData['user'];
              if (userData is Map<String, dynamic>) {
                setState(() {
                  _userData = userData;
                });
              }
            }

            // Extraire les données professionnel
            if (profileData.containsKey('professional')) {
              final professionalData = profileData['professional'];
              if (professionalData is Map<String, dynamic>) {
                setState(() {
                  _professionalData = professionalData;
                });
              }
            }

            // Extraire les statistiques
            if (profileData.containsKey('stats')) {
              final stats = profileData['stats'];
              if (stats is Map<String, dynamic>) {
                setState(() {
                  _totalJobsAsClient = stats['total_jobs_as_client'] ?? 0;
                  _totalJobsAsProfessional = stats['total_jobs_as_professional'] ?? 0;
                  _totalPendingQuotations = stats['total_pending_quotations'] ?? 0;
                  _totalActiveJobs = stats['total_active_jobs'] ?? 0;
                  _totalFavorites = stats['total_favorites'] ?? 0;
                  _totalReviewsReceived = stats['total_reviews_received'] ?? 0;
                });
              }
            }

            setState(() {
              _isLoading = false;
            });

            print('Profil pro-client chargé avec succès');
            return;
          }
        }

        print('Problème avec la structure de la réponse API');
        _showError('Format de réponse inattendu du serveur');
        return;
      } else {
        print('Échec API - Status: ${response.statusCode}');
        print('Corps de l\'erreur: ${response.body}');
        setState(() {
          _errorMessage = 'Erreur lors de la récupération du profil (${response.statusCode})';
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      print('Exception lors du chargement du profil pro-client: $e');
      setState(() {
        _errorMessage = 'Erreur de connexion lors du chargement du profil';
        _isLoading = false;
      });
      return;
    }
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
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/pro-client/dashboard',
          (route) => false,
        );
        break;
      case 1: // Mode Client
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/pro-client/dashboard',
          (route) => false,
          arguments: {'initialTab': 1},
        );
        break;
      case 2: // Mode Professionnel
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/pro-client/dashboard',
          (route) => false,
          arguments: {'initialTab': 2},
        );
        break;
      case 3: // Profil (page actuelle)
        break;
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/onboarding-role',
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
          'Mon Profil Pro-Client',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFFFCC00),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFFCC00),
              ),
            )
          : _userData == null && _professionalData == null
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
                        _errorMessage ?? 'Erreur lors du chargement du profil',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProClientProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFCC00),
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

                      // Section Profil professionnel
                      if (_professionalData != null) ...[
                        _buildSectionTitle('Profil professionnel'),
                        const SizedBox(height: 12),
                        _buildProfessionalCard(),
                        const SizedBox(height: 24),
                      ],

                      // Section Actions rapides
                      _buildSectionTitle('Actions rapides'),
                      const SizedBox(height: 12),
                      _buildActionButtons(),

                      const SizedBox(height: 24),

                      // Section Statistiques
                      _buildSectionTitle('Activité'),
                      const SizedBox(height: 12),
                      _buildStatsCard(),

                      const SizedBox(height: 32),

                      // Bouton de déconnexion
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
        selectedItemColor: const Color(0xFFFFCC00),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Client',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            label: 'Professionnel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
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
        color: const Color(0xFFFFCC00),
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
                      color: const Color(0xFFFFCC00),
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
                              color: Color(0xFFFFCC00),
                              size: 30,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color: Color(0xFFFFCC00),
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
            _buildInfoRow('Rôle', 'Pro-Client'),
            if (_userData?['created_at'] != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow('Membre depuis', _formatDate(_userData!['created_at'])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business_center, color: const Color(0xFFFFCC00)),
                const SizedBox(width: 8),
                Text(
                  'Profil professionnel',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFFCC00),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Entreprise', _professionalData?['company_name'] ?? 'Non définie'),
            const SizedBox(height: 8),
            _buildInfoRow('Poste', _professionalData?['job_title'] ?? 'Non défini'),
            const SizedBox(height: 8),
            _buildInfoRow('Statut', _getProfessionalStatusText(_professionalData?['status'])),
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
          icon: Icons.add_business,
          title: 'Créer une demande de devis',
          subtitle: 'Trouvez des professionnels pour vos projets',
          onTap: () => Navigator.pushNamed(
            context,
            '/pro-client/create-quotation',
            arguments: {
              'token': widget.token,
              'userData': widget.userData,
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          icon: Icons.inbox,
          title: 'Mes devis reçus',
          subtitle: 'Consulter les propositions des professionnels',
          onTap: () => Navigator.pushNamed(
            context,
            '/pro-client/quotations',
            arguments: {
              'token': widget.token,
              'userData': widget.userData,
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          icon: Icons.work,
          title: 'Mes jobs actifs',
          subtitle: 'Suivre l\'avancement de vos projets',
          onTap: () => Navigator.pushNamed(
            context,
            '/pro-client/client-jobs',
            arguments: {
              'token': widget.token,
              'userData': widget.userData,
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          icon: Icons.reply,
          title: 'Répondre aux devis',
          subtitle: 'Proposer vos services aux clients',
          onTap: () => Navigator.pushNamed(
            context,
            '/pro-client/respond-quotations',
            arguments: {
              'token': widget.token,
              'userData': widget.userData,
            },
          ),
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
                  color: const Color(0xFFFFCC00).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFFFCC00),
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
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(_totalJobsAsClient.toString(), 'Jobs Client'),
                _buildStatItem(_totalJobsAsProfessional.toString(), 'Jobs Pro'),
                _buildStatItem(_totalPendingQuotations.toString(), 'Devis en attente'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(_totalActiveJobs.toString(), 'Jobs actifs'),
                _buildStatItem(_totalFavorites.toString(), 'Favoris'),
                _buildStatItem(_totalReviewsReceived.toString(), 'Avis reçus'),
              ],
            ),
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
            color: const Color(0xFFFFCC00),
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

  String _getProfessionalStatusText(String? status) {
    switch (status) {
      case 'approved':
        return 'Approuvé';
      case 'pending':
        return 'En attente';
      case 'rejected':
        return 'Rejeté';
      default:
        return 'Non défini';
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
