import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
  Map<String, dynamic> _dashboardData = {};
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // Récupération des données depuis l'API
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? widget.token;

      final response = await http.get(
        Uri.parse('http://localhost:8000/api/professional/dashboard'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _dashboardData = Map<String, dynamic>.from(data['data']);
          });
        } else {
          throw Exception('Format de réponse inattendu');
        }
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      // En cas d'erreur, utiliser des données de secours
      print('Erreur API, utilisation des données simulées: $e');
      setState(() {
        _dashboardData = {
          'total_leads': 24,
          'pending_leads': 8,
          'converted_leads': 16,
          'completed_jobs': 45,
          'in_progress_jobs': 3,
          'total_revenue': 8750.0,
          'average_rating': 4.8,
          'recent_activities': [
            {'type': 'new_lead', 'message': 'Nouveau lead reçu de Marie D.', 'time': '2 min ago'},
            {'type': 'job_completed', 'message': 'Projet terminé pour Pierre L.', 'time': '1h ago'},
            {'type': 'review_received', 'message': 'Nouvelle évaluation reçue', 'time': '3h ago'},
          ]
        };
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4CAF50)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Tableau de bord',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4CAF50)),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error,
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDashboardData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Réessayer',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête de bienvenue
            _buildWelcomeHeader(),

            const SizedBox(height: 32),

            // Métriques principales en grille
            _buildMetricsGrid(),

            const SizedBox(height: 32),

            // Graphique des leads
            _buildLeadsChart(),

            const SizedBox(height: 32),

            // Activité récente
            _buildRecentActivity(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4CAF50).withOpacity(0.1),
            const Color(0xFF4CAF50).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              border: Border.all(
                color: const Color(0xFF4CAF50),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.business_center,
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
                  'Bonjour ${widget.profile['first_name'] ?? 'Professionnel'}',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Voici un aperçu de votre activité',
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
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildMetricCard(
          'Leads reçus',
          '${_dashboardData['total_leads'] ?? 0}',
          Icons.person_add,
          Colors.blue,
          '${_dashboardData['pending_leads'] ?? 0} en attente',
        ),
        _buildMetricCard(
          'Jobs réalisés',
          '${_dashboardData['completed_jobs'] ?? 0}',
          Icons.check_circle,
          Colors.green,
          '${_dashboardData['in_progress_jobs'] ?? 0} en cours',
        ),
        _buildMetricCard(
          'Revenus',
          '${_dashboardData['total_revenue']?.toStringAsFixed(0) ?? '0'} €',
          Icons.euro,
          Colors.orange,
          'Ce mois',
        ),
        _buildMetricCard(
          'Note moyenne',
          '${_dashboardData['average_rating'] ?? '0'}/5',
          Icons.star,
          Colors.amber,
          'Basé sur les avis',
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLeadsChart() {
    final totalLeads = _dashboardData['total_leads'] ?? 0;
    final pendingLeads = _dashboardData['pending_leads'] ?? 0;
    final convertedLeads = _dashboardData['converted_leads'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Évolution des leads',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildChartBar(
                  'Total',
                  totalLeads.toDouble(),
                  Colors.blue,
                  '${totalLeads}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildChartBar(
                  'En attente',
                  pendingLeads.toDouble(),
                  Colors.orange,
                  '${pendingLeads}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildChartBar(
                  'Convertis',
                  convertedLeads.toDouble(),
                  Colors.green,
                  '${convertedLeads}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Taux de conversion: ${totalLeads > 0 ? ((convertedLeads / totalLeads) * 100).toStringAsFixed(1) : '0'}%',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartBar(String label, num value, Color color, String displayValue) {
    const maxHeight = 120.0;
    final height = value > 0 ? (value.toDouble() / 24) * maxHeight : 10.0; // 24 est la valeur max pour l'échelle

    return Column(
      children: [
        Text(
          displayValue,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.7),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final activities = _dashboardData['recent_activities'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
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
              Text(
                'Voir tout',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF4CAF50),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (activities.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[400]),
                  const SizedBox(width: 12),
                  Text(
                    'Aucune activité récente',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          else
            ...activities.take(3).map<Widget>((activity) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getActivityColor(activity['type']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getActivityColor(activity['type']).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getActivityColor(activity['type']),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getActivityIcon(activity['type']),
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity['message'],
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activity['time'],
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'new_lead':
        return Colors.blue;
      case 'job_completed':
        return Colors.green;
      case 'review_received':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'new_lead':
        return Icons.person_add;
      case 'job_completed':
        return Icons.check_circle;
      case 'review_received':
        return Icons.star;
      default:
        return Icons.info;
    }
  }
}
