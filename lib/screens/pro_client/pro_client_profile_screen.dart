import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_config.dart';

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
        Uri.parse('${AppConfig.baseUrl}/api/professional/profile/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Réponse reçue - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Données décodées: $data');

        if (data is Map<String, dynamic>) {
          print('=== DEBUG STRUCTURE API PRO-CLIENT ===');
          print('Clés disponibles dans la réponse: ${data.keys}');

          // L'API /api/professional/profile/me retourne directement les données du professionnel
          Map<String, dynamic>? profileData;

          // Si la structure contient 'data', utilise data
          if (data.containsKey('data')) {
            final apiData = data['data'];
            if (apiData is Map<String, dynamic>) {
              profileData = apiData;
            }
          } else {
            // Si pas de 'data', utilise directement le contenu (structure alternative)
            profileData = data;
          }

          print('Données de profil pro-client finales: $profileData');

          if (profileData != null && profileData.isNotEmpty) {
            final finalProfileData = profileData;

            // Les données sont directement dans finalProfileData
            setState(() {
              _professionalData = finalProfileData;
            });

            // Pour pro-client, on utilise les données directement depuis le profil professionnel
            setState(() {
              _totalJobsAsClient = finalProfileData['total_jobs_as_client'] ?? 0;
              _totalJobsAsProfessional = finalProfileData['total_jobs_as_professional'] ?? finalProfileData['completed_jobs'] ?? 0;
              _totalPendingQuotations = finalProfileData['total_pending_quotations'] ?? 0;
              _totalActiveJobs = finalProfileData['total_active_jobs'] ?? 0;
              _totalFavorites = finalProfileData['total_favorites'] ?? 0;
              _totalReviewsReceived = finalProfileData['total_reviews_received'] ?? 0;
            });

            setState(() {
              _isLoading = false;
            });

            print('Profil pro-client chargé avec succès depuis API /api/professional/profile/me');
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
          : _professionalData == null || (_professionalData?.isEmpty ?? true)
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
                  child: _professionalData?['profile_photo'] != null || _professionalData?['avatar'] != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: (_professionalData?['profile_photo'] as Map<String, dynamic>?)?['url'] ?? _professionalData?['avatar'] ?? '',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const CircularProgressIndicator(
                              color: Color(0xFFFFCC00),
                            ),
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
                        _professionalData?['company_name'] ?? 'Entreprise non définie',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _professionalData?['email'] ?? 'Email non défini',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      if (_professionalData?['phone'] != null || _professionalData?['phone_number'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _professionalData?['phone'] ?? _professionalData?['phone_number'] ?? '',
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
            if (_professionalData?['created_at'] != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow('Membre depuis', _formatDate(_professionalData!['created_at'])),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(
          context,
          '/pro-client/professional-profile',
          arguments: {
            'token': widget.token,
            'userData': widget.userData,
          },
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
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCC00).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: const Color(0xFFFFCC00),
                      size: 16,
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
              const SizedBox(height: 8),
              Row(
                children: [
                  const Spacer(),
                  _getStatusBadge(_professionalData?['status']),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getStatusBadge(String? status) {
    final statusText = _getProfessionalStatusText(status);
    final statusColor = _getStatusColor(status ?? '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor),
      ),
      child: Text(
        statusText,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: statusColor,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF4CAF50); // Vert pour approuvé
      case 'pending':
        return const Color(0xFFFFCC00); // Jaune pour en attente
      case 'rejected':
        return const Color(0xFFF44336); // Rouge pour rejeté
      default:
        return Colors.grey;
    }
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
              color: const Color(0xFF1E3A5F),
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
        // _buildActionButton(
        //   icon: Icons.add_business,
        //   title: 'Créer une demande de devis',
        //   subtitle: 'Trouvez des professionnels pour vos projets',
        //   onTap: () => Navigator.pushNamed(
        //     context,
        //     '/pro-client/create-quotation',
        //     arguments: {
        //       'token': widget.token,
        //       'userData': widget.userData,
        //     },
        //   ),
        // ),
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
          icon: Icons.business_center,
          title: 'Profil professionnel complet',
          subtitle: 'Voir tous les détails, horaires, documents',
          onTap: () => Navigator.pushNamed(
            context,
            '/pro-client/professional-profile',
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
