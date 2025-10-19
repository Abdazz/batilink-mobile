import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/pro_client_service.dart';
import '../../services/auth_service.dart';

class ProClientDashboardScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> userData;
  final int initialTab; // 0: Accueil, 1: Client, 2: Professionnel

  const ProClientDashboardScreen({
    Key? key,
    required this.token,
    required this.userData,
    this.initialTab = 0,
  }) : super(key: key);

  @override
  State<ProClientDashboardScreen> createState() => _ProClientDashboardScreenState();
}

class _ProClientDashboardScreenState extends State<ProClientDashboardScreen> {
  late int _selectedIndex;
  String _finalToken = '';

  // Données du dashboard hybride
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _profileData;

  // Statistiques hybrides
  int _totalJobsAsClient = 0;
  int _totalJobsAsProfessional = 0;
  int _totalPendingQuotations = 0;

  final ProClientService _proClientService = ProClientService(
    baseUrl: 'http://10.0.2.2:8000',
    authService: AuthService(baseUrl: 'http://10.0.2.2:8000'),
  );

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    print('=== INIT DASHBOARD ===');
    print('Token reçu: ${widget.token}');
    print('Token longueur: ${widget.token.length}');
    print('UserData reçu: ${widget.userData}');
    print('UserData type: ${widget.userData.runtimeType}');
    print('Initial tab: ${widget.initialTab}');
    _initializeTokenAndLoadData();
  }

  Future<void> _initializeTokenAndLoadData() async {
    // Récupérer le token depuis SharedPreferences comme secours
    final prefs = await SharedPreferences.getInstance();
    final tokenFromPrefs = prefs.getString('token') ?? '';

    // Utiliser le token passé en argument, ou celui de SharedPreferences comme secours
    _finalToken = widget.token.isNotEmpty ? widget.token : tokenFromPrefs;

    if (_finalToken.isEmpty) {
      print('ERREUR: Aucun token disponible !');
      return;
    }

    print('Token final utilisé: ${_finalToken.substring(0, 20)}...');
    _loadDashboardData();
    _loadProfileData();
  }

  Future<void> _loadDashboardData() async {
    try {
      print('=== CHARGEMENT DASHBOARD PRO-CLIENT ===');
      print('Token passé au service: ${_finalToken.substring(0, 20)}...');
      final response = await _proClientService.getProClientDashboard(
        accessToken: _finalToken,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final dashboardData = data['data'];
          print('Données dashboard reçues: $dashboardData');

          if (mounted) {
            setState(() {
              _dashboardData = dashboardData;
              _totalJobsAsClient = dashboardData['stats']?['jobs_as_client'] ?? 0;
              _totalJobsAsProfessional = dashboardData['stats']?['jobs_as_professional'] ?? 0;
              _totalPendingQuotations = dashboardData['stats']?['pending_quotations'] ?? 0;
            });
          }
        }
      }
    } catch (e) {
      print('Erreur lors du chargement du dashboard: $e');
    }
  }

  Future<void> _loadProfileData() async {
    try {
      print('=== CHARGEMENT PROFIL PRO-CLIENT ===');
      print('Token passé au service profil: ${_finalToken.substring(0, 20)}...');
      final response = await _proClientService.getProClientProfile(
        accessToken: _finalToken,
      );

      if (response.statusCode == 200) {
        final profileData = await _proClientService.parseProClientProfileResponse(response);
        if (profileData != null && mounted) {
          print('=== DEBUG PROFILE DATA ===');
          print('Profile data reçu: $profileData');
          print('Profile data type: ${profileData.runtimeType}');
          print('Profile data keys: ${profileData.keys.toList()}');

          if (profileData.containsKey('user')) {
            final user = profileData['user'];
            print('User trouvé: $user');
            print('User type: ${user.runtimeType}');
            if (user is Map<String, dynamic>) {
              print('User keys: ${user.keys.toList()}');
              print('User role: ${user['role']}');
            }
          }

          setState(() {
            _profileData = profileData;
          });
        }
      }
    } catch (e) {
      print('Erreur lors du chargement du profil: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Tableau de bord Pro-Client',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black54),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedIndex == 0) ...[
              // Mode Accueil (hybride)
              _buildWelcomeCard(),
              const SizedBox(height: 24),
              _buildStatsRow(),
              const SizedBox(height: 24),
              _buildRecentActivity(),
              const SizedBox(height: 24),
              _buildQuickActions(),
            ] else if (_selectedIndex == 1) ...[
              // Mode Client
              _buildClientModeView(),
            ] else if (_selectedIndex == 2) ...[
              // Mode Professionnel
              _buildProfessionalModeView(),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          switch (index) {
            case 0: // Accueil (page actuelle)
              break;
            case 1: // Mode Client
              print('=== DEBUG NAVIGATION MODE CLIENT ===');
              print('Token: $_finalToken');
              print('UserData: ${widget.userData}');
              Navigator.pushReplacementNamed(
                context,
                '/pro-client/dashboard',
                arguments: {'initialTab': 1, 'token': _finalToken, 'userData': widget.userData},
              );
              break;
            case 2: // Mode Professionnel
              print('=== DEBUG NAVIGATION MODE PROFESSIONNEL ===');
              print('Token: $_finalToken');
              print('UserData: ${widget.userData}');
              Navigator.pushReplacementNamed(
                context,
                '/pro-client/dashboard',
                arguments: {'initialTab': 2, 'token': _finalToken, 'userData': widget.userData},
              );
              break;
            case 3: // Profil
              print('=== DEBUG NAVIGATION PROFIL ===');
              print('Token: $_finalToken');
              print('UserData: ${widget.userData}');
              Navigator.pushNamed(context, '/pro-client/profile', arguments: {
                'token': _finalToken,
                'userData': widget.userData,
              });
              break;
          }
        },
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

  Widget _buildWelcomeCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFCC00),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFCC00).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour, ${_profileData?['user']?['first_name'] ?? 'Pro-Client'}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bienvenue sur votre espace hybride',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildModeCard('Mode Client', Icons.person_outline, 'Gérer vos projets'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModeCard('Mode Pro', Icons.work_outline, 'Proposer vos services'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard(String title, IconData icon, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.8),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Jobs Client',
            _totalJobsAsClient.toString(),
            Icons.person_outline,
            const Color(0xFF2196F3),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Jobs Pro',
            _totalJobsAsProfessional.toString(),
            Icons.work_outline,
            const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Devis',
            _totalPendingQuotations.toString(),
            Icons.description,
            const Color(0xFFE91E63),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final recentJobsAsClient = _dashboardData?['recent_jobs_as_client'] as List<dynamic>? ?? [];
    final recentJobsAsProfessional = _dashboardData?['recent_jobs_as_professional'] as List<dynamic>? ?? [];
    final activeJobs = _dashboardData?['active_jobs'] as List<dynamic>? ?? [];
    final pendingQuotations = _dashboardData?['pending_quotations'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Activité récente',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'Voir tout',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFFCC00),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recentJobsAsClient.isEmpty && recentJobsAsProfessional.isEmpty && activeJobs.isEmpty && pendingQuotations.isEmpty)
          _buildEmptyState(
            'Aucune activité récente',
            'Vos projets et devis apparaîtront ici',
            Icons.history,
          )
        else
          ...[
            if (recentJobsAsClient.isNotEmpty)
              ...recentJobsAsClient.take(2).map((job) => _buildActivityItem(job, 'Client')),
            if (recentJobsAsProfessional.isNotEmpty)
              ...recentJobsAsProfessional.take(2).map((job) => _buildActivityItem(job, 'Professionnel')),
            if (activeJobs.isNotEmpty)
              ...activeJobs.take(2).map((job) => _buildActivityItem(job, 'Actif')),
            if (pendingQuotations.isNotEmpty)
              ...pendingQuotations.take(2).map((quotation) => _buildActivityItem(quotation, 'Devis')),
          ],
      ],
    );
  }

  Widget _buildActivityItem(dynamic item, String type) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getActivityColor(type).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_getActivityIcon(type), color: _getActivityColor(type)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] ?? 'Titre non disponible',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getActivitySubtitle(item, type),
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getActivityColor(type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              type,
              style: GoogleFonts.poppins(
                color: _getActivityColor(type),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getActivitySubtitle(dynamic item, String type) {
    if (type == 'Client' && item.containsKey('professional')) {
      final professional = item['professional'];
      if (professional.containsKey('user')) {
        final user = professional['user'];
        return 'Professionnel: ${user['first_name']} ${user['last_name']}';
      }
    }
    if (type == 'Professionnel' && item.containsKey('client')) {
      final client = item['client'];
      return 'Client: ${client['first_name']} ${client['last_name']}';
    }
    if (item.containsKey('user')) {
      final user = item['user'];
      return 'Utilisateur: ${user['first_name']} ${user['last_name']}';
    }
    return 'Détails non disponibles';
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'Client':
        return Icons.person_outline;
      case 'Professionnel':
        return Icons.work_outline;
      case 'Actif':
        return Icons.play_arrow;
      case 'Devis':
        return Icons.description;
      default:
        return Icons.info;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'Client':
        return const Color(0xFF2196F3);
      case 'Professionnel':
        return const Color(0xFF4CAF50);
      case 'Actif':
        return const Color(0xFFFFCC00);
      case 'Devis':
        return const Color(0xFFE91E63);
      default:
        return Colors.grey;
    }
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Voir devis',
                'Consulter les propositions',
                Icons.inbox,
                () => Navigator.pushNamed(context, '/pro-client/quotations'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Jobs actifs',
                'Suivre vos projets',
                Icons.work,
                () => Navigator.pushNamed(context, '/pro-client/client-jobs', arguments: {
                  'token': _finalToken,
                  'userData': widget.userData,
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Mon profil',
                'Gérer vos informations',
                Icons.person,
                () => Navigator.pushNamed(context, '/pro-client/profile', arguments: {
                  'token': _finalToken,
                  'userData': widget.userData,
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCC00).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFFFFCC00), size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildClientModeView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFCC00).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFCC00).withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFCC00),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode Client',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gérez vos projets et demandes de devis',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.85,
          children: [
            _buildModeGridCard(
              'Mes devis',
              'Consulter les propositions reçues',
              Icons.inbox,
              const Color(0xFF2196F3),
              () => Navigator.pushNamed(context, '/pro-client/quotations'),
            ),
            _buildModeGridCard(
              'Jobs actifs',
              'Suivre l\'avancement de vos projets',
              Icons.work,
              const Color(0xFF4CAF50),
              () => Navigator.pushNamed(context, '/pro-client/client-jobs', arguments: {
                'token': _finalToken,
                'userData': widget.userData,
              }),
            ),
            _buildModeGridCard(
              'Rechercher',
              'Trouver des experts qualifiés',
              Icons.search,
              const Color(0xFF9C27B0),
              () => Navigator.pushNamed(context, '/pro-client/professional-search', arguments: {
                'token': _finalToken,
                'userData': widget.userData,
              }),
            ),
            _buildModeGridCard(
              'Statistiques',
              'Voir vos performances client',
              Icons.analytics,
              const Color(0xFFFF9800),
              () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfessionalModeView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E3A5F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.work_outline, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode Professionnel',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Proposez vos services et gérez vos projets',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.85,
          children: [
            _buildModeGridCard(
              'Devis reçus',
              'Consulter les demandes de devis',
              Icons.inbox,
              const Color(0xFFE91E63),
              () => Navigator.pushNamed(context, '/pro-client/respond-quotations'),
            ),
            _buildModeGridCard(
              'Mes projets',
              'Gérer vos projets en cours',
              Icons.work,
              const Color(0xFF4CAF50),
              () => Navigator.pushNamed(context, '/pro-client/professional-jobs'),
            ),
            _buildModeGridCard(
              'Mon profil',
              'Gérer vos informations professionnelles',
              Icons.person,
              const Color(0xFF9C27B0),
              () => Navigator.pushNamed(context, '/pro-client/profile', arguments: {
                'token': _finalToken,
                'userData': widget.userData,
              }),
            ),
            _buildModeGridCard(
              'Analytics',
              'Suivre vos performances pro',
              Icons.analytics,
              const Color(0xFFFF9800),
              () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeGridCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
