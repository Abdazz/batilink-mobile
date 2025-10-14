import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/professional.dart';
import '../../services/professional_service.dart';
import '../../services/api_service.dart';
import 'professional_search_screen.dart';
import 'client_profile_screen.dart';
import '../../constants.dart';

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
  bool _isLoading = true;
  List<Professional> _professionals = [];
  List<dynamic> _favorites = [];
  int _favoritesCount = 0;
  final ProfessionalService _professionalService = ProfessionalService(baseUrl: 'http://10.0.2.2:8000');

  @override
  void initState() {
    super.initState();
    _loadProfessionals();
    _loadAppointments();
    _loadRecentActivities();
    _loadFavorites();
  }

  Future<void> _loadProfessionals() async {
    setState(() => _isLoading = true);
    try {
      final professionals = await _professionalService.getInteractedProfessionals();
      setState(() {
        _professionals = professionals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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

  Widget _buildProfessionalCard(Professional professional) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Naviguer vers les détails du professionnel
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: professional.avatarUrl != null
                        ? CachedNetworkImageProvider(professional.avatarUrl!)
                        : null,
                    child: professional.avatarUrl == null
                        ? Text(
                            '${professional.firstName[0]}${professional.lastName[0]}',
                            style: const TextStyle(fontSize: 20, color: primaryColor),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          professional.fullName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          professional.profession,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              color: Colors.amber[600],
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${professional.rating.toStringAsFixed(1)} (${professional.reviewCount})',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      professional.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: professional.isFavorite ? Colors.red : null,
                    ),
                    onPressed: () => _toggleFavorite(professional),
                  ),
                ],
              ),
              if (professional.lastInteraction != null) ...[
                const Divider(height: 24),
                Text(
                  'Dernière interaction: ${DateFormat('dd/MM/yyyy').format(professional.lastInteraction!)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
              if (professional.lastReview != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Votre avis: ${professional.lastReview}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_professionals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun professionnel récent',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Les professionnels avec qui vous interagissez apparaîtront ici',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProfessionals,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: _professionals.length,
        itemBuilder: (context, index) => _buildProfessionalCard(_professionals[index]),
      ),
    );
  }

  List<Map<String, dynamic>> _upcomingAppointments = [];
  List<Map<String, dynamic>> _recentActivities = [];

  Future<void> _loadAppointments() async {
    // TODO: Implémenter le chargement des rendez-vous depuis l'API
    final appointments = [
      {
        'title': 'Rendez-vous',
        'date': 'Demain, 10:00',
        'service': 'Électricité - Installation prises',
        'status': 'En attente',
        'color': Colors.orange,
      },
    ];
    
    if (mounted) {
      setState(() {
        _upcomingAppointments = appointments;
      });
    }
  }

  Future<void> _loadRecentActivities() async {
    // TODO: Implémenter le chargement des activités récentes depuis l'API
    final activities = [
      {
        'title': 'Facture payée',
        'date': 'Il y a 2 heures',
        'amount': '120 €',
        'icon': Icons.receipt,
        'color': Colors.green,
      },
      {
        'title': 'Nouveau message',
        'date': 'Il y a 5 heures',
        'amount': 'De : Plomberie Pro',
        'icon': Icons.message,
        'color': Colors.blue,
      },
    ];
    
    if (mounted) {
      setState(() {
        _recentActivities = activities;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
            label: 'Mes professionnels',
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
        color: const Color(0xFF4CAF50),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
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
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Fidélité : 125 points',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  'Voir plus',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
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
            'Prochains RDV',
            '2',
            Icons.calendar_today,
            const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Messages',
            '3',
            Icons.message,
            const Color(0xFF2196F3),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Favoris',
            _favoritesCount.toString(),
            Icons.favorite,
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

  Widget _buildNextAppointment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Prochains RDV',
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
                  color: const Color(0xFF4CAF50),
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
            'Aucun rendez-vous à venir',
            'Prenez rendez-vous avec un professionnel',
            Icons.calendar_today,
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
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF4CAF50)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Détails',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF4CAF50),
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
              onPressed: () {},
              child: Text(
                'Voir tout',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF4CAF50),
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
              'Professionnels récents',
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
                  color: const Color(0xFF4CAF50),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_professionals.isEmpty)
          _buildEmptyState(
            'Aucun professionnel récent',
            'Les professionnels avec qui vous interagissez apparaîtront ici',
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
                                          fontSize: 24, color: Color(0xFF4CAF50)),
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
                              // Navigate to professional details
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
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
  
  void _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        print('Token manquant pour charger les favoris');
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/favorites/professionals'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final favorites = data['data'] ?? [];

        if (mounted) {
          setState(() {
            _favoritesCount = favorites.length;
          });
        }
      } else {
        print('Erreur lors du chargement des favoris: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors du chargement des favoris: $e');
    }
  }
}
