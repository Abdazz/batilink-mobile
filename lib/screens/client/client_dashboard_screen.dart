import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/professional.dart';
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
    required this.userData,
    required Map profile,
  }) : super(key: key);

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  int _selectedIndex = 0;
  List<Professional> _professionals = [];
  int _quotationsCount = 0;
  int _professionalsWithQuotationsCount = 0;

  // Statistiques du profil client
  int _totalJobs = 0;

  final ProfessionalService _professionalService = ProfessionalService(baseUrl: AppConfig.baseUrl);
  final ClientDashboardService _dashboardService = ClientDashboardService(baseUrl: AppConfig.baseUrl);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _loadProfessionals();
    _loadAppointments();
    _loadRecentActivities();
    _loadClientStats();
  }

  Future<void> _loadClientStats() async {
    try {
      final token = widget.token;
      if (token.isEmpty) return;

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/client/stats'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('data')) {
          final stats = data['data'];
          if (stats is Map<String, dynamic>) {
            if (mounted) {
              setState(() {
                _totalJobs = stats['total_jobs'] ?? 0;
                // Mettre à jour les compteurs du dashboard avec les vraies données
                _quotationsCount = _totalJobs;
              });
            }
          }
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des statistiques client: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      await _dashboardService.getAllDashboardData();

      if (mounted) {
        setState(() {
          // Les données sont déjà récupérées depuis l'API dans les autres méthodes
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des données du dashboard: $e');
    }
  }

  Future<void> _loadProfessionals() async {
    try {
      final professionals = await _professionalService.getInteractedProfessionals();
      setState(() {
        _professionals = professionals;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des professionnels')),
        );
      }
    }
  }

  Future<void> _toggleFavorite(Professional professional) async {
    final success = await _professionalService.toggleFavorite(professional.id);
    if (success && mounted) {
      setState(() {
        _professionals = _professionals.map((p) =>
          p.id == professional.id ? professional.copyWith(isFavorite: !professional.isFavorite) : p
        ).toList();
      });
    }
  }

  List<Map<String, dynamic>> _upcomingAppointments = [];
  List<Map<String, dynamic>> _recentActivities = [];

  Future<void> _loadAppointments() async {
    try {
      final dashboardData = await _dashboardService.getAllDashboardData();

      if (mounted) {
        setState(() {
          // Créer les rendez-vous à partir des données API
          final dernierDevisAccepte = dashboardData['dernier_devis_accepte'];

          _upcomingAppointments = [];

          // Ajouter le dernier devis accepté (status quoted)
          if (dernierDevisAccepte != null) {
            _upcomingAppointments.add({
              'title': 'Devis accepté',
              'date': dernierDevisAccepte['date'] ?? 'Date inconnue',
              'service': dernierDevisAccepte['service'] ?? 'Service non spécifié',
              'status': 'Accepté',
              'color': Colors.green,
            });
          }

          // Calculer le nombre de devis
          _quotationsCount = 0;
          if (dernierDevisAccepte != null) _quotationsCount++;

          // Calculer le nombre de professionnels avec lesquels le client a interagi
          _professionalsWithQuotationsCount = _professionals.length;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des rendez-vous: $e');
    }
  }

  Future<void> _loadRecentActivities() async {
    try {
      final dashboardData = await _dashboardService.getAllDashboardData();

      if (mounted) {
        setState(() {
          _recentActivities = [];

          // Ajouter les activités à partir des données API
          final dernierProDevis = dashboardData['dernier_pro_devis'];

          if (dernierProDevis != null) {
            _recentActivities.add({
              'title': 'Devis du professionnel',
              'date': dernierProDevis['date'] ?? 'Date inconnue',
              'amount': dernierProDevis['montant'] ?? 'Montant inconnu',
              'icon': Icons.receipt,
              'color': Colors.purple,
            });
          }

          // Ajouter d'autres activités par défaut si aucune donnée API
          if (_recentActivities.isEmpty) {
            _recentActivities = [
              {
                'title': 'Bienvenue sur Batilink',
                'date': 'Aujourd\'hui',
                'amount': 'Découvrez nos professionnels',
                'icon': Icons.star,
                'color': Colors.amber,
              },
            ];
          }
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des activités récentes: $e');
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
          'Tableau de bord',
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
            _buildWelcomeCard(),
            const SizedBox(height: 24),
            _buildStatsRow(),
            const SizedBox(height: 24),
            _buildNextAppointment(),
            const SizedBox(height: 24),
            _buildRecentActivities(),
            const SizedBox(height: 24),
            _buildRecentProfessionals(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 1) { // Index pour l'onglet de recherche
            if (widget.token.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfessionalSearchScreen(
                  token: widget.token,
                  userData: widget.userData,
                )),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Token d\'authentification manquant. Veuillez vous reconnecter.')),
              );
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

  Widget _buildWelcomeCard() {
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
            'Devis',
            _quotationsCount.toString(),
            Icons.receipt_long,
            const Color(0xFF2196F3),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Professionnels',
            _professionalsWithQuotationsCount.toString(),
            Icons.people,
            const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Favoris',
            '0', // TODO: Récupérer depuis l'API quand disponible
            Icons.favorite,
            const Color(0xFFFFCC00),
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

  Widget _buildNextAppointment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Dernier devis accepté',
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
        if (_upcomingAppointments.isNotEmpty)
          Column(
            children: _upcomingAppointments.map((appointment) => _buildAppointmentCard(appointment)).toList(),
          )
        else
          _buildEmptyState(
            'Aucun devis accepté récemment',
            'Les devis acceptés apparaîtront ici',
            Icons.assignment_turned_in,
          ),
      ],
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
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
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: appointment['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: appointment['color'],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment['title'],
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appointment['date'],
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
                    color: appointment['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    appointment['status'],
                    style: GoogleFonts.poppins(
                      color: appointment['color'],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              appointment['service'],
              style: GoogleFonts.poppins(
                color: Colors.grey[800],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Naviguer vers les devis
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ClientCompletedQuotationsScreen(
                          token: widget.token,
                          userData: widget.userData,
                        )),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFFCC00)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Voir devis',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFFCC00),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Contacter',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Activités récentes',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {
                // Naviguer vers la recherche de professionnels
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfessionalSearchScreen(
                    token: widget.token,
                    userData: widget.userData,
                  )),
                );
              },
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
        if (_recentActivities.isNotEmpty)
          Column(
            children: _recentActivities.map((activity) => _buildActivityItem(activity)).toList(),
          )
        else
          _buildEmptyState(
            'Aucune activité récente',
            'Vos activités apparaîtront ici',
            Icons.history,
          ),
      ],
    );
  }

  Widget _buildRecentProfessionals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Professionnels actifs',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to all professionals screen
              },
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
        if (_professionals.isEmpty)
          _buildEmptyState(
            'Aucun professionnel actif',
            'Les professionnels avec lesquels vous avez des devis en cours apparaîtront ici',
            Icons.people_outline,
          )
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _professionals.length,
              itemBuilder: (context, index) {
                final professional = _professionals[index];
                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: professional.avatarUrl != null
                                  ? CachedNetworkImageProvider(professional.avatarUrl!)
                                  : null,
                              child: professional.avatarUrl == null
                                  ? Text(
                                      '${professional.firstName[0]}${professional.lastName[0]}',
                                      style: const TextStyle(
                                          fontSize: 24, color: Color(0xFFFFCC00)),
                                    )
                                  : null,
                            ),
                            IconButton(
                              icon: Icon(
                                professional.isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: professional.isFavorite
                                    ? Colors.red
                                    : Colors.grey[400],
                                size: 20,
                              ),
                              onPressed: () => _toggleFavorite(professional),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          professional.fullName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          professional.profession,
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.star,
                              color: Colors.amber[600],
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              professional.rating.toStringAsFixed(1),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 120,
                          child: ElevatedButton(
                            onPressed: () {
                              // Naviguer vers les détails du professionnel ou la recherche
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ProfessionalSearchScreen(
                                  token: widget.token,
                                  userData: widget.userData,
                                )),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFCC00),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Contacter',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
              ),
      ],
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
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
              color: activity['color'].withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(activity['icon'], color: activity['color']),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title'],
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity['date'],
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            activity['amount'],
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: activity['color'],
            ),
          ),
        ],
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
}
