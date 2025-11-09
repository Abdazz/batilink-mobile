import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/professional_service.dart';
import '../../services/client_dashboard_service.dart';
import '../../core/app_config.dart';
import 'professional_search_screen.dart';
import 'client_completed_quotations_screen.dart';
import 'client_profile_screen.dart';

class ClientDashboardScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> userData;

  const ClientDashboardScreen({
    Key? key,
    required this.token,
    required this.userData, required Map profile,
  }) : super(key: key);

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  int _selectedIndex = 0;

  // Données du dashboard
  int _totalFavoris = 0;
  int _totalProfessionnels = 0;  // Ajout de la variable manquante
  // État pour stocker les données du tableau de bord
  Map<String, dynamic>? _dernierDevisAccepte;
  Map<String, dynamic>? _dernierProDevis;

  final ProfessionalService _professionalService = ProfessionalService(baseUrl: AppConfig.baseUrl);
  final ClientDashboardService _dashboardService = ClientDashboardService(baseUrl: AppConfig.baseUrl);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _loadProfessionals();
  }

  Future<void> _loadDashboardData() async {
    try {
      final data = await _dashboardService.getAllDashboardData();
      if (mounted) {
        setState(() {
          _totalFavoris = data['total_favoris'] ?? 0;
          _totalProfessionnels = data['total_professionnels'] ?? 0;
          _dernierDevisAccepte = data['dernier_devis_accepte'];
          _dernierProDevis = data['dernier_pro_devis'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des données: $e')),
        );
      }
    }
  }

  Future<void> _loadProfessionals() async {
    try {
      // Récupérer les professionnels avec qui l'utilisateur a interagi
      await _professionalService.getInteractedProfessionals();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des professionnels')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête avec bienvenue et notification
                _buildHeader(),
                const SizedBox(height: 24),

                // Cartes de statistiques
                _buildStatsRow(),
                const SizedBox(height: 24),

                // Dernier devis accepté
                _buildRecentActivities(),
                const SizedBox(height: 24),

                // Dernier professionnel avec devis
                _buildRecentProfessionals(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) async {
          if (index == 1) { // Index pour l'onglet de recherche
            // Récupérer le token depuis les propriétés du widget ou depuis SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            final token = widget.token.isNotEmpty ? widget.token : (prefs.getString('token') ?? '');
            
            print('Token avant navigation vers ProfessionalSearchScreen: ${token.isNotEmpty ? 'Présent' : 'Manquant'}');
            
            if (token.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfessionalSearchScreen(
                  token: token,
                  userData: widget.userData,
                )),
              );
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Session expirée. Veuillez vous reconnecter.'),
                    backgroundColor: Colors.red,
                  ),
                );
                // Rediriger vers l'écran de connexion si nécessaire
                // Navigator.pushReplacementNamed(context, '/login');
              }
            }
            return; // Ne pas mettre à jour _selectedIndex pour rester sur l'onglet actuel
          }
          if (index == 2) { // Index pour l'onglet "Mes devis"
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ClientCompletedQuotationsScreen(
                token: widget.token,
                userData: widget.userData,
              )),
            );
            return; // Ne pas mettre à jour _selectedIndex pour rester sur l'onglet actuel
          }
          if (index == 3) { // Index pour l'onglet Profil
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ClientProfileScreen(
                token: widget.token,
                userData: widget.userData,
              )),
            );
            return; // Ne pas mettre à jour _selectedIndex pour rester sur l'onglet actuel
          }
          setState(() => _selectedIndex = index);
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
            icon: Icon(Icons.search),
            label: 'Recherche',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Mes devis',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFCC00),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.yellow.withOpacity(0.2),
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
                child: const Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour, ${widget.userData['first_name'] ?? 'Client'}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bienvenue sur votre espace client',
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
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Favoris',
            '$_totalFavoris',
            Icons.favorite,
            const Color(0xFFFF5252),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Professionnels',
            '$_totalProfessionnels',
            Icons.people,
            const Color(0xFF4CAF50),
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

  Widget _buildRecentActivities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activités récentes',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _dernierDevisAccepte != null
            ? _buildDevisCard(_dernierDevisAccepte!)
            : _buildEmptyState(
                'Aucune activité récente',
                'Vous n\'avez pas encore d\'activité récente',
                Icons.receipt_long,
              ),
      ],
    );
  }

  Widget _buildDevisCard(Map<String, dynamic> devis) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Devis #${devis['id'] ?? 'N/A'}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Accepté',
                    style: GoogleFonts.poppins(
                      color: Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Montant: ${devis['montant']?.toString() ?? 'N/A'} FCFA',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Date: ${devis['date']?.toString() ?? 'Date inconnue'}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentProfessionals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Dernier pro avec devis',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            TextButton(
              onPressed: () {
                // TODO: Naviguer vers la liste complète des professionnels
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size(80, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Voir tout',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _dernierProDevis != null
            ? _buildProfessionalCard(_dernierProDevis!)
            : _buildEmptyState(
                'Aucun professionnel récent',
                'Vous n\'avez pas encore de professionnel avec devis',
                Icons.people,
              ),
      ],
    );
  }

  Widget _buildProfessionalCard(Map<String, dynamic> professional) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[200]!),
            image: professional['photo'] != null
                ? DecorationImage(
                    image: CachedNetworkImageProvider(
                      '${AppConfig.baseUrl}${professional['photo']}',
                    ),
                    fit: BoxFit.cover,
                  )
                : const DecorationImage(
                    image: AssetImage('assets/images/default_avatar.png'),
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        title: Text(
          professional['nom'] ?? 'Professionnel',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              professional['metier'] ?? 'Métier non spécifié',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Dernier contact',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          // TODO: Naviguer vers la page de détail du professionnel
        },
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
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
