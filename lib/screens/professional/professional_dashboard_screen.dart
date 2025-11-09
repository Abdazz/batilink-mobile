import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

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
  bool _isRefreshing = false;

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

      print('Chargement des données du dashboard...');
      
      // Utiliser ApiService pour récupérer les données du dashboard
      final response = await ApiService.get('dashboard/professional');
      print('Réponse brute de l\'API: $response');

      if (response != null) {
        print('Données brutes reçues: ${response.toString()}');
        
        // Vérifier si la réponse contient des données
        if (response['data'] != null) {
          print('Données du dashboard trouvées');
          
          try {
            // Convertir explicitement les données en Map<String, dynamic>
            final apiData = Map<String, dynamic>.from(response['data']);
            print('Données avant mapping: $apiData');
            
            // Vérifier et convertir les types de données si nécessaire
            if (apiData['rating'] != null) {
              if (apiData['rating'] is String) {
                apiData['rating'] = double.tryParse(apiData['rating']) ?? 0.0;
              } else if (apiData['rating'] is int) {
                apiData['rating'] = (apiData['rating'] as int).toDouble();
              }
            }
            
            final mappedData = _mapApiDataToDashboardFormat(apiData);
            print('Données après mapping: $mappedData');
            
            setState(() {
              _dashboardData = mappedData;
              _error = '';
            });
          } catch (e, stackTrace) {
            print('Erreur lors du mappage des données: $e');
            print('Stack trace: $stackTrace');
            throw Exception('Erreur lors du traitement des données: $e');
          }
        } else {
          print('Aucune donnée dans la réponse');
          throw Exception('Aucune donnée dans la réponse');
        }
      } else {
        print('Réponse nulle de l\'API');
        throw Exception('Réponse nulle de l\'API');
      }
    } catch (e) {
      print('Erreur API, utilisation des données de secours: $e');
      setState(() {
        _error = 'Erreur de connexion. Utilisation des données de démonstration.';
        _dashboardData = _getDemoDashboardData();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshDashboardData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      // Utiliser ApiService pour récupérer les données du dashboard
      final data = await ApiService.get('dashboard/professional');

      if (data != null && data['data'] != null) {
        final apiData = data['data'];
        setState(() {
          _dashboardData = _mapApiDataToDashboardFormat(apiData);
          _error = '';
        });
      } else {
        setState(() {
          _error = 'Données non disponibles lors du rafraîchissement.';
          _dashboardData = _getDemoDashboardData();
        });
      }
    } catch (e) {
      print('Erreur lors du rafraîchissement: $e');
      setState(() {
        _error = 'Erreur lors du rafraîchissement des données.';
      });
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFCC00),
        elevation: 0,
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back, color: Colors.white),
        //   onPressed: () => Navigator.of(context).pop(),
        // ),
        title: Text(
          'Tableau de bord',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isRefreshing)
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(right: 16),
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFCC00)),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _refreshDashboardData,
            ),
        ],
      ),
      backgroundColor: const Color(0xFFE5E5E5),
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
                backgroundColor: const Color(0xFFFFCC00),
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
      onRefresh: _refreshDashboardData,
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
            const Color(0xFFFFCC00).withOpacity(0.15),
            const Color(0xFFFFCC00).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFCC00).withOpacity(0.3),
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
              color: const Color(0xFFFFCC00).withOpacity(0.15),
              border: Border.all(
                color: const Color(0xFFFFCC00),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.business_center,
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
                  'Bonjour ${widget.profile['first_name'] ?? 'Professionnel'}',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Voici un aperçu de votre activité professionnelle',
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
          'Clients',
          '${_dashboardData['total_clients'] ?? 0}',
          Icons.people,
          const Color(0xFFFFCC00),
          'Clients actifs',
        ),
        _buildMetricCard(
          'Jobs réalisés',
          '${_dashboardData['total_jobs_realises'] ?? 0}',
          Icons.check_circle,
          Colors.green,
          'Au total',
        ),
        _buildMetricCard(
          'Évolution',
          '+15%',
          Icons.trending_up,
          Colors.blue,
          'Ce mois-ci',
        ),
        _buildMetricCard(
          'Note moyenne',
          '${(_dashboardData['rating'] ?? 0.0).toStringAsFixed(1)}/5',
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
    // Récupérer les données d'évolution avec des valeurs par défaut
    final evolutionData = _dashboardData['evolution_leads'] is Map
        ? Map<String, dynamic>.from(_dashboardData['evolution_leads'] as Map)
        : <String, dynamic>{'labels': [], 'data': []};
    
    // S'assurer que les labels sont bien une liste de chaînes
    List<String> labels = [];
    if (evolutionData['labels'] is List) {
      try {
        labels = (evolutionData['labels'] as List).map((e) => e?.toString() ?? '').toList().cast<String>();
      } catch (e) {
        print('Erreur lors de la conversion des labels: $e');
        labels = [];
      }
    }
    
    // S'assurer que les données sont bien une liste de nombres
    List<int> data = [];
    if (evolutionData['data'] is List) {
      try {
        data = (evolutionData['data'] as List).map((e) {
          if (e is int) return e;
          if (e is double) return e.toInt();
          return int.tryParse(e?.toString() ?? '0') ?? 0;
        }).toList().cast<int>();
      } catch (e) {
        print('Erreur lors de la conversion des données: $e');
        data = [];
      }
    }
    
    // Ajuster la taille des listes pour qu'elles correspondent
    final length = labels.length < data.length ? labels.length : data.length;
    if (length > 0) {
      labels = labels.sublist(0, length);
      data = data.sublist(0, length);
    } else {
      // Si pas de données, utiliser des valeurs par défaut
      labels = [];
      data = [];
    }
    
    // Trouver la valeur maximale pour l'échelle du graphique (minimum 1 pour éviter la division par zéro)
    final maxValue = data.isNotEmpty && data.any((e) => e > 0) 
        ? data.reduce((a, b) => a > b ? a : b) 
        : 1;
    
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
          if (labels.isEmpty || data.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: Text(
                'Aucune donnée disponible',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(labels.length, (index) {
                  final label = labels[index];
                  final value = index < data.length ? data[index] : 0;
                  final height = maxValue > 0 ? (value / maxValue * 150) : 0;
                  
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFFFCC00),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 30,
                        height: height.toDouble(),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFCC00),
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFFFFCC00).withOpacity(0.8),
                              const Color(0xFFFFCC00).withOpacity(0.4),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          const SizedBox(height: 8),
          if (data.isNotEmpty)
            Text(
              '${data.last - (data.length > 1 ? data[data.length - 2] : 0)} par rapport au mois dernier',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
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
                  color: const Color(0xFFFFCC00),
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
              final activityType = activity['type']?.toString() ?? 'unknown';
              final activityMessage = activity['message']?.toString() ?? 'Activité inconnue';
              final activityTime = activity['time']?.toString() ?? 'Il y a longtemps';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getActivityColor(activityType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getActivityColor(activityType).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getActivityColor(activityType),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getActivityIcon(activityType),
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
                            activityMessage,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activityTime,
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
        return const Color(0xFFFFCC00);
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

  /// Mappe les données de l'API vers le format attendu par l'interface
  Map<String, dynamic> _mapApiDataToDashboardFormat(Map<String, dynamic> apiData) {
    // Convertir les activités récentes au format attendu par l'interface
    final activities = (apiData['activites_recentes'] as List?)?.map((activity) {
      return {
        'type': activity['type'] == 'new_review' ? 'review_received' : 'job_completed',
        'title': activity['title'] ?? 'Nouvelle activité',
        'message': activity['description'] ?? '',
        'time': activity['date'] ?? 'Récemment'
      };
    }).toList() ?? [];

    // Gérer la conversion du rating qui peut être une String ou un double
    final rating = apiData['rating'];
    double ratingValue = 0.0;
    
    if (rating != null) {
      if (rating is String) {
        ratingValue = double.tryParse(rating) ?? 0.0;
      } else if (rating is int) {
        ratingValue = rating.toDouble();
      } else if (rating is double) {
        ratingValue = rating;
      }
    }

    return {
      'total_clients': apiData['total_clients'] ?? 0,
      'total_jobs_realises': apiData['total_jobs_realises'] ?? 0,
      'rating': ratingValue,
      'evolution_leads': apiData['evolution_leads'] ?? {'labels': [], 'data': []},
      'recent_activities': activities,
      'raw_api_data': apiData, // Conserver les données brutes
    };
  }

  /// Retourne des données de démonstration réalistes
  Map<String, dynamic> _getDemoDashboardData() {
    return {
      'total_clients': 42,
      'total_jobs_realises': 150,
      'rating': 4.8,
      'evolution_leads': {
        'labels': ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin'],
        'data': [10, 15, 12, 18, 20, 25]
      },
      'activites_recentes': [
        {
          'type': 'job_completed',
          'title': 'Job #1234 complété',
          'description': 'Le job \'Réparation plomberie\' a été marqué comme terminé',
          'date': '2025-10-30T14:30:00Z'
        },
        {
          'type': 'new_review',
          'title': 'Nouvel avis reçu',
          'description': '5 étoiles - \'Excellent travail, très professionnel\'',
          'date': '2025-10-29T09:15:00Z'
        }
      ]
    };
  }
}
