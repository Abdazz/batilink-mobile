import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/professional.dart';
import '../../services/api_service.dart';
import '../../core/app_config.dart';
import '../unified_quotation_detail_screen.dart' as unified_screen;
import 'quote_request_screen.dart';

class ProfessionalDetailScreen extends StatefulWidget {
  final String professionalId;
  final String? token;
  final Map<String, dynamic>? userData;

  const ProfessionalDetailScreen({
    super.key,
    required this.professionalId,
    this.token,
    this.userData,
  });

  @override
  _ProfessionalDetailScreenState createState() => _ProfessionalDetailScreenState();
}

class _ProfessionalDetailScreenState extends State<ProfessionalDetailScreen> with SingleTickerProviderStateMixin {
  Professional? _professional;
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _portfolios = [];
  final Map<String, dynamic> _reviewDetails = {}; // Pour stocker les détails des devis associés aux avis
  final List<Map<String, dynamic>> _tabs = [
    {'label': 'À propos', 'icon': Icons.info_outline},
    {'label': 'Horaires', 'icon': Icons.access_time},
    {'label': 'Portfolio', 'icon': Icons.photo_library_outlined},
    {'label': 'Avis', 'icon': Icons.star_border},
  ];
  
  // Contrôleurs de défilement pour chaque onglet
  final ScrollController _aboutScrollController = ScrollController();
  final ScrollController _scheduleScrollController = ScrollController();
  final ScrollController _portfolioScrollController = ScrollController();
  final ScrollController _reviewsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadProfessionalData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aboutScrollController.dispose();
    _portfolioScrollController.dispose();
    _reviewsScrollController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      // Faire défiler vers le haut quand on change d'onglet
      WidgetsBinding.instance.addPostFrameCallback((_) {
        switch (_tabController.index) {
          case 0: // À propos
            if (_aboutScrollController.hasClients) {
              _aboutScrollController.animateTo(
                0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
            break;
          case 1: // Horaires
            if (_scheduleScrollController.hasClients) {
              _scheduleScrollController.animateTo(
                0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
            break;
          case 2: // Portfolio
            if (_portfolioScrollController.hasClients) {
              _portfolioScrollController.animateTo(
                0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
            break;
          case 3: // Avis
            if (_reviewsScrollController.hasClients) {
              _reviewsScrollController.animateTo(
                0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
            break;
        }
      });
    }
  }

  Future<void> _loadProfessionalData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      print('Chargement des données pour le professionnel: ${widget.professionalId}');

      print('Tentative de connexion à: ${AppConfig.baseUrl}/api/professionals/${widget.professionalId}');

      // Récupérer le token d'authentification depuis les paramètres ou SharedPreferences
      final token = widget.token ?? await _getTokenFromPrefs();

      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = 'Token d\'authentification manquant. Veuillez vous reconnecter.';
          _isLoading = false;
        });
        return;
      }

      print('Tentative de chargement des données du professionnel avec l\'ID: ${widget.professionalId}');
      
      // Essayer avec différentes clés possibles pour les horaires d'ouverture
      final data = await ApiService.get('professionals/${widget.professionalId}?include=business_hours,hours,schedule');

      print('=== RÉPONSE BRUTE DE L\'API ===');
      print(data);

      if (data != null) {
        // Structure de réponse pour les détails du professionnel
        final Map<String, dynamic> responseData = data is Map<String, dynamic> ? data : {};
        Map<String, dynamic> professionalData = {};
        
        // Essayer différentes structures de réponse possibles
        if (responseData['data'] is Map<String, dynamic>) {
          professionalData = responseData['data'] as Map<String, dynamic>;
        } else if (responseData['professional'] is Map<String, dynamic>) {
          professionalData = responseData['professional'] as Map<String, dynamic>;
        } else if (responseData.isNotEmpty) {
          professionalData = responseData;
        }
        
        print('=== DONNÉES DU PROFESSIONNEL EXTRACTED ===');
        print(professionalData);
        
        // Vérifier différentes clés possibles pour les horaires
        final businessHours = professionalData['business_hours'] ?? 
                            professionalData['businessHours'] ??
                            professionalData['hours'] ??
                            professionalData['opening_hours'] ??
                            professionalData['schedule'];
        
        print('=== HORAIRES D\'OUVERTURE TROUVÉS ===');
        print('Type: ${businessHours?.runtimeType}');
        print('Valeur: $businessHours');
        
        // Si on a des horaires, s'assurer qu'ils sont dans le bon format
        if (businessHours != null) {
          professionalData['business_hours'] = businessHours;
        }

        if (mounted) {
          setState(() {
            _professional = Professional.fromJson(professionalData);
            _isLoading = false;
          });
        }

        // Charger les détails supplémentaires si disponibles
        _loadReviews();
        _loadPortfolios();
      } else {
        setState(() {
          _errorMessage = 'Erreur lors du chargement du profil professionnel';
          _isLoading = false;
        });
      }

    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _loadReviews() async {
    try {
      print('Chargement des avis pour le professionnel: ${widget.professionalId}');

      final data = await ApiService.get('professionals/${widget.professionalId}/reviews');

      print('Données des avis reçues: $data');

      if (data != null) {
        // Structure de réponse pour les avis
        final Map<String, dynamic> responseData = data is Map<String, dynamic> ? data : {};
        final reviewsData = responseData['data'] ?? [];

        if (mounted) {
          setState(() {
            _reviews = List<Map<String, dynamic>>.from(reviewsData);
          });
        }

        // Charger les détails des devis associés aux avis si disponibles
        _loadReviewQuotationDetails();
      } else {
        // Pas d'avis disponibles
        print('Aucun avis disponible pour ce professionnel');
        if (mounted) {
          setState(() {
            _reviews = [];
          });
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des avis: $e');
      // En cas d'erreur de réseau, utiliser une liste vide
      if (mounted) {
        setState(() {
          _reviews = [];
        });
      }
    }
  }

  Future<void> _loadReviewQuotationDetails() async {
    try {
      // Récupérer le token d'authentification
      final token = widget.token ?? await _getTokenFromPrefs();

      if (token == null || token.isEmpty) {
        return;
      }

      // Pour chaque avis, essayer de récupérer les détails du devis associé
      for (var review in _reviews) {
        final quotationId = review['quotation_id'];
        if (quotationId != null) {
          try {
            final quotationData = await ApiService.get('quotations/$quotationId');

            if (quotationData != null) {
              setState(() {
                _reviewDetails[quotationId.toString()] = quotationData;
              });
            }
          } catch (e) {
            print('Erreur lors du chargement du devis $quotationId: $e');
          }
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des détails des devis: $e');
    }
  }

  Future<void> _loadPortfolios() async {
    try {
      // Endpoint pour récupérer les portfolios d'un professionnel
      // GET /api/professionals/{professionalId}/portfolios
      print('Chargement des portfolios pour le professionnel: ${widget.professionalId}');

      // Récupérer le token d'authentification depuis les paramètres ou SharedPreferences
      final token = widget.token ?? await _getTokenFromPrefs();

      final data = await ApiService.get('professionals/${widget.professionalId}/portfolios');

      print('Données des portfolios reçues: $data');

      if (data != null) {
        // Structure de réponse pour les portfolios
        final Map<String, dynamic> responseData = data is Map<String, dynamic> ? data : {};
        final portfoliosData = responseData['data'] ?? [];

        print('=== DEBUG PORTFOLIOS ===');
        print('Données reçues: $portfoliosData');
        print('Nombre d\'éléments: ${portfoliosData.length}');

        if (portfoliosData.isNotEmpty) {
          print('Premier élément: ${portfoliosData[0]}');
          print('Clés disponibles: ${portfoliosData[0].keys.toList()}');
          print('Valeur image_url: ${portfoliosData[0]['image_url']}');
          print('Valeur image: ${portfoliosData[0]['image']}');
          print('Valeur image_path: ${portfoliosData[0]['image_path']}');
        }

        if (mounted) {
          setState(() {
            _portfolios = List<Map<String, dynamic>>.from(portfoliosData);
          });
        }
        print('Portfolios chargés: ${_portfolios.length} éléments');
      } else {
        // Pas de portfolios disponibles
        print('Aucun portfolio disponible pour ce professionnel');
        if (mounted) {
          setState(() {
            _portfolios = [];
          });
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des portfolios: $e');
      // En cas d'erreur de réseau, utiliser une liste vide
      if (mounted) {
        setState(() {
          _portfolios = [];
        });
      }
    }
  }

  Future<void> _showRatingDialog() async {
    double rating = 0;
    final commentController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Noter ce professionnel'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                RatingBar.builder(
                  initialRating: rating,
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                  itemBuilder: (context, _) => const Icon(
                    Icons.star,
                    color: Colors.amber,
                  ),
                  onRatingUpdate: (value) {
                    rating = value;
                  },
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Commentaire (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Envoyer'),
              onPressed: () async {
                try {
                  // Récupérer le token d'authentification depuis les paramètres
                  final token = widget.token;

                  if (token == null || token.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Authentification requise. Veuillez vous reconnecter.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final response = await ApiService.post(
                    'professionals/${widget.professionalId}/reviews',
                    data: {
                      'rating': rating,
                      'comment': commentController.text,
                    },
                  );

                  if (response != null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Votre avis a été enregistré avec succès'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadReviews();
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Authentification requise. Veuillez vous reconnecter.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Erreur lors de l\'envoi de l\'avis'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildScheduleTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_professional == null) {
      return const Center(child: Text('Aucune donnée disponible'));
    }

    final Map<String, dynamic>? businessHours = _professional!.businessHours;
    
    return SingleChildScrollView(
      controller: _scheduleScrollController,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section des horaires d'ouverture
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFCC00).withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: const Color(0xFFFFCC00).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Horaires d'ouverture",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFFCC00),
                  ),
                ),
                const SizedBox(height: 16),
                if (businessHours == null || businessHours.isEmpty)
                  _buildNoHoursAvailable()
                else
                  ..._buildBusinessHours(businessHours),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_professional == null) {
      return const Center(child: Text('Aucune donnée disponible'));
    }
    
    final Map<String, dynamic>? businessHours = _professional!.businessHours;
    return SingleChildScrollView(
      controller: _aboutScrollController,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          if (_professional!.description?.isNotEmpty == true) ...[
            Text(
              'À propos',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFFCC00),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFCC00).withOpacity(0.08),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFFFFCC00).withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Text(
                _professional!.description!,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  height: 1.6,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Divider(height: 28, thickness: 1, color: Colors.grey[200]),

          // Bouton pour accéder aux horaires
          GestureDetector(
            onTap: () {
              // Basculer vers l'onglet des horaires
              _tabController.animateTo(1);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE680)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Color(0xFFFFB700)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Voir les horaires d'ouverture",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (businessHours != null && businessHours.isNotEmpty)
                          Text(
                            'Cliquez pour voir les horaires',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Divider(height: 28, thickness: 1, color: Colors.grey[200]),
            // Suite : Informations professionnelles détaillées
          Text(
            'Informations professionnelles',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFFCC00),
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoGrid(),

          const SizedBox(height: 24),

          // Compétences détaillées
          if (_professional?.detailedSkills.isNotEmpty == true) ...[
            Text(
              'Compétences',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFFCC00),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: (_professional?.detailedSkills ?? []).map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getSkillLevelColor(skill.level).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getSkillLevelColor(skill.level),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSkillIcon(skill.level),
                        size: 16,
                        color: _getSkillLevelColor(skill.level),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        skill.name,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _getSkillLevelColor(skill.level),
                        ),
                      ),
                      if (skill.experienceYears > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getSkillLevelColor(skill.level),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${skill.experienceYears} ans',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPortfolioTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_portfolios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun portfolio',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ce professionnel n\'a pas encore ajouté de photos de ses réalisations',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _portfolioScrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: _portfolios.length,
      itemBuilder: (context, index) {
        final item = _portfolios[index];
        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildPortfolioImage(item),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] ?? 'Sans titre',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item['description'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item['description'].toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // En-tête avec note moyenne et bouton d'avis
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 350;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Note moyenne',
                          style: GoogleFonts.poppins(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            RatingBarIndicator(
                              rating: _professional?.rating ?? 0,
                              itemBuilder: (context, _) => const Icon(
                                Icons.star,
                                color: Colors.amber,
                              ),
                              itemCount: 5,
                              itemSize: isSmallScreen ? 16.0 : 20.0,
                              direction: Axis.horizontal,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_professional?.rating.toStringAsFixed(1) ?? '0.0'}/5',
                              style: GoogleFonts.poppins(
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFFFCC00),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${_professional?.reviewCount ?? 0} avis',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.rate_review, size: 16),
                    label: Text(
                      isSmallScreen ? 'Avis' : 'Donner mon avis',
                      style: GoogleFonts.poppins(
                        fontSize: isSmallScreen ? 12 : 14,
                      ),
                    ),
                    onPressed: _showRatingDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFCC00),
                      foregroundColor: Colors.white,
                      padding: isSmallScreen 
                          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                          : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Liste des avis (prend tout l'espace restant)
        Expanded(
          child: _reviews.isEmpty
              ? SingleChildScrollView( // Défilement pour l'état vide
                  child: Container(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.rate_review_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun avis pour le moment',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Soyez le premier à donner votre avis !',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _reviewsScrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _reviews.length,
                  itemBuilder: (context, index) {
                    final review = _reviews[index];
                    final quotationId = review['quotation_id'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFCC00).withOpacity(0.08),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFFFCC00).withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFFFCC00).withOpacity(0.1),
                                    border: Border.all(
                                      color: const Color(0xFFFFCC00).withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    review['user_name']?[0].toUpperCase() ?? '?',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFFFCC00),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        review['user_name'] ?? 'Anonyme',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      RatingBarIndicator(
                                        rating: (review['rating'] as num?)?.toDouble() ?? 0,
                                        itemBuilder: (context, _) => const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                        ),
                                        itemCount: 5,
                                        itemSize: 16.0,
                                        direction: Axis.horizontal,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _formatDate(review['created_at'] ?? ''),
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (review['comment'] != null && review['comment'].toString().isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Text(
                                  review['comment'].toString(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                            // Bouton pour voir le devis associé si disponible
                            if (quotationId != null) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.description, size: 16),
                                  label: const Text('Voir le devis associé'),
                                  onPressed: () => _navigateToQuotationDetails(quotationId.toString()),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFCC00),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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

  Widget _buildInfoGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        _buildInfoCard(
          icon: Icons.work,
          title: 'Expérience',
          value: '${_professional?.experienceYears ?? 0} ans',
          color: const Color(0xFFFFCC00),
        ),
        _buildInfoCard(
          icon: Icons.euro,
          title: 'Tarif horaire',
          value: '${_professional?.hourlyRate.toStringAsFixed(0) ?? '0'} €',
          color: const Color(0xFFFFCC00),
        ),
        _buildInfoCard(
          icon: Icons.location_on,
          title: 'Localisation',
          value: _professional?.city ?? 'Non spécifiée',
          color: const Color(0xFFFFCC00),
        ),
        _buildInfoCard(
          icon: Icons.check_circle,
          title: 'Projets terminés',
          value: '${_professional?.completedJobs ?? 0}',
          color: const Color(0xFFFFCC00),
        ),
        if (_professional?.minPrice != null) ...[
          _buildInfoCard(
            icon: Icons.attach_money,
            title: 'Prix minimum',
            value: '${_professional?.minPrice.toStringAsFixed(0) ?? '0'} €',
            color: const Color(0xFFFFCC00),
          ),
        ],
        if (_professional?.maxPrice != null) ...[
          _buildInfoCard(
            icon: Icons.trending_up,
            title: 'Prix maximum',
            value: '${_professional?.maxPrice.toStringAsFixed(0) ?? '0'} €',
            color: const Color(0xFFFFCC00),
          ),
        ],
        if (_professional?.radiusKm != null && _professional!.radiusKm > 0) ...[
          _buildInfoCard(
            icon: Icons.gps_fixed,
            title: 'Rayon d\'intervention',
            value: '${_professional!.radiusKm} km',
            color: const Color(0xFFFFCC00),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
            ),
            child: Icon(
              icon,
              size: 24,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
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
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _getSkillLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'expert':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'beginner':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getSkillIcon(String level) {
    switch (level.toLowerCase()) {
      case 'expert':
        return Icons.verified;
      case 'intermediate':
        return Icons.trending_up;
      case 'beginner':
        return Icons.school;
      default:
        return Icons.star;
    }
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFFFCC00)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Détails professionnel',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading && _professional == null && _errorMessage == null
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.red[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: Column(
                    children: [
                      _buildHeaderSection(),
                      Container(
                        margin: const EdgeInsets.only(top: 0, bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        color: Colors.transparent,
                        child: Row(
                          children: List.generate(_tabs.length, (index) {
                            bool isSelected = _tabController.index == index;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  _tabController.animateTo(index);
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 0.5),
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFFFCC00) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFFFFCC00) : Colors.grey[300]!,
                                      width: 1,
                                    ),
                                    boxShadow: isSelected ? [
                                      BoxShadow(
                                        color: const Color(0xFFFFCC00).withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      )
                                    ] : [],
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _tabs[index]['icon'],
                                          size: 16,
                                          color: isSelected ? Colors.white : Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            _tabs[index]['label'],
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                              color: isSelected ? Colors.white : Colors.grey[700],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      // Contenu des onglets
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Chaque tab content est déjà scrollable
                            _buildAboutTab(),
                            _buildScheduleTab(),
                            _buildPortfolioTab(),
                            _buildReviewsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 33, vertical: 12),
        child: ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuoteRequestScreen(
                professionalId: widget.professionalId,
                professionalName: _professional!.displayName ?? 'Professionnel',
                professionalJob: _professional!.jobTitle ?? _professional!.profession ?? 'Service',
                token: widget.token,
                userData: widget.userData,
              ),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD7263D),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(19),
            ),
            elevation: 6,
          ),
          child: Text(
            'Réserver maintenant',
            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 28, bottom: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x22AAAAAA),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.grey[200],
                backgroundImage: _professional?.fullAvatarUrl != null
                    ? NetworkImage(_professional!.fullAvatarUrl!)
                    : null,
                child: _professional?.fullAvatarUrl == null
                    ? Icon(Icons.person, size: 52, color: Colors.grey[400])
                    : null,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _professional?.displayName ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _professional?.jobTitle?.isNotEmpty == true
                          ? (_professional?.jobTitle ?? _professional?.profession ?? '')
                          : (_professional?.profession ?? ''),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE6E6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _professional?.hourlyRate != null
                            ? '${_professional!.hourlyRate.toStringAsFixed(0)} FCFA/Jour'
                            : '-- FCFA/Jour',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFD7263D),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(Icons.work, '${_professional?.experienceYears ?? 0} ans', 'Expérience'),
              _buildStatItem(Icons.people_alt_rounded, '${_professional?.completedClientsCount ?? 0}', 'Clients'),
              _buildStatItem(Icons.star, '${_professional?.rating?.toStringAsFixed(1) ?? '--'}', 'Avis'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.09),
            blurRadius: 6,
            offset: const Offset(0,2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFFFCC00), size: 22),
          const SizedBox(height: 5),
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _getImageUrl(dynamic item) {
    try {
      if (item == null) {
        print('Item is null');
        return '';
      }

      print('=== DEBUG PORTFOLIO ITEM ===');
      
      // Fonction pour nettoyer l'URL et corriger le double 'storage/'
      String cleanUrl(String url) {
        if (url.isEmpty) return '';
        
        // Supprimer les espaces et les caractères spéciaux indésirables
        String cleanedUrl = url.trim();
        
        // Corriger le double 'storage/'
        cleanedUrl = cleanedUrl.replaceAll(RegExp(r'/storage/(/storage/)+'), '/storage/');
        
        // S'assurer que l'URL commence par http ou https
        if (!cleanedUrl.startsWith('http')) {
          // Si l'URL commence par /storage/, on la combine avec l'URL de base
          if (cleanedUrl.startsWith('/storage/')) {
            cleanedUrl = '${AppConfig.baseUrl}${cleanedUrl}';
          } else {
            cleanedUrl = AppConfig.buildMediaUrl(cleanedUrl);
          }
        }
        
        // Nettoyer les doubles slashes sauf après http:
        cleanedUrl = cleanedUrl.replaceAll(RegExp(r'(?<!http:|https:)/{2,}'), '/');
        
        print('Cleaned URL: $cleanedUrl');
        return cleanedUrl;
      }
      
      // Si l'item est une chaîne, on la traite directement comme une URL
      if (item is String) {
        return cleanUrl(item);
      }
      
      // Si l'item est une Map, on cherche une URL d'image dans différentes clés possibles
      if (item is Map) {
        print('Item is Map, keys: ${item.keys.toList()}');
        
        // Vérifier si l'item contient une clé 'url' ou 'path' qui pourrait être une URL
        if (item['url'] is String && item['url'].isNotEmpty) {
          return cleanUrl(item['url'].toString());
        }
        
        if (item['path'] is String && item['path'].isNotEmpty) {
          return cleanUrl(item['path'].toString());
        }
        
        // Essayer différentes clés possibles pour l'image
        final possibleKeys = ['image_url', 'image', 'image_path'];
        for (var key in possibleKeys) {
          if (item[key] is String && item[key].toString().isNotEmpty) {
            return cleanUrl(item[key].toString());
          }
        }
      }
      
      print('No valid image URL found in item');
      return '';
    } catch (e) {
      print('Error in _getImageUrl: $e');
      return '';
    }
  }

  Widget _buildPlaceholder(String message, {bool isError = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        color: Colors.grey[200],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.photo,
              size: 40,
              color: isError ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: isError ? Colors.red : Colors.grey,
              ),
              textAlign: TextAlign.center,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioImage(Map<String, dynamic> item) {
    try {
      final imageUrl = _getImageUrl(item);
      print('Building portfolio image with URL: $imageUrl');

      if (imageUrl.isEmpty) {
        print('Image URL is empty');
        return _buildPlaceholder('Image non disponible');
      }

      // Vérifier si l'URL est valide
      final uri = Uri.tryParse(imageUrl);
      if (uri == null || !uri.isAbsolute) {
        print('Invalid URL: $imageUrl');
        return _buildPlaceholder('URL invalide', isError: true);
      }

      return Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          color: Colors.grey[200],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            httpHeaders: widget.token != null ? {
              'Authorization': 'Bearer ${widget.token}',
              'Accept': 'application/json',
            } : null,
            maxHeightDiskCache: 1000,
            memCacheHeight: 500,
            placeholder: (context, url) => _buildPlaceholder('Chargement...'),
            errorWidget: (context, url, error) {
              print('Erreur de chargement image: $url - $error');
              // Afficher un message d'erreur approprié
              return _buildPlaceholder('Erreur de chargement', isError: true);
            },
          ),
        ),
      );
    } catch (e) {
      print('Error in _buildPortfolioImage: $e');
      return _buildPlaceholder('Erreur d\'affichage', isError: true);
    }
  }

  Future<String?> _getTokenFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  void _navigateToQuotationDetails(String quotationId) {
    // Naviguer vers les détails du devis associé à cet avis
    // Nous devons d'abord récupérer les informations du devis depuis l'API
    _loadQuotationDetails(quotationId);
  }

  Future<void> _loadQuotationDetails(String quotationId) async {
    try {
      final token = widget.token ?? await _getTokenFromPrefs();

      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentification requise pour voir les détails du devis.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final quotationData = await ApiService.get('quotations/$quotationId');

      if (quotationData != null) {
        // Naviguer vers l'écran des détails du devis avec les données récupérées
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => unified_screen.UnifiedQuotationDetailScreen(
              quotationId: quotationId,
              quotation: quotationData,
              token: token,
              context: unified_screen.QuotationContext.client,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de charger les détails du devis.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Erreur lors du chargement des détails du devis: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors du chargement du devis.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Méthode pour afficher un message lorsque les horaires ne sont pas disponibles
  Widget _buildNoHoursAvailable() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Les horaires d\'ouverture ne sont pas disponibles pour le moment.',
              style: GoogleFonts.poppins(
                color: Colors.orange[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Méthode pour construire la liste des horaires d'ouverture
  List<Widget> _buildBusinessHours(Map<String, dynamic> hours) {
    print('=== BUILD BUSINESS HOURS ===');
    print('Heures reçues: $hours');
    
    final daysLabels = [
      'Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'
    ];
    final keys = [
      'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'
    ];
    
    return List.generate(7, (i) {
      final dayKey = keys[i];
      final val = hours[dayKey];
      
      print('Traitement du jour: $dayKey');
      print('Valeur pour $dayKey: $val');
      
      String open = '';
      String close = '';
      
      if (val is Map) {
        open = (val['open'] ?? '').toString();
        close = (val['close'] ?? '').toString();
      } else if (val is String) {
        // Essayer de parser si c'est une chaîne au format "09:00-18:00"
        try {
          final parts = val.split('-');
          if (parts.length == 2) {
            open = parts[0].trim();
            close = parts[1].trim();
          }
        } catch (e) {
          print('Erreur lors du parsing des horaires: $e');
        }
      }
      
      final isClosed = open.isEmpty || close.isEmpty;
      print('$dayKey - Ouvert: $open, Fermé: $close, Est fermé: $isClosed');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.5),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Color(0xFFFFCC00), size: 20),
            const SizedBox(width: 10),
            SizedBox(
              width: 84,
              child: Text(
                daysLabels[i],
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.grey[800], fontSize: 15),
              ),
            ),
            if (isClosed)
              Expanded(
                child: Text(
                  'Fermé',
                  style: GoogleFonts.poppins(fontStyle: FontStyle.italic, color: Colors.grey[500]),
                ),
              )
            else
              Expanded(
                child: Text(
                  '$open - $close',
                  style: GoogleFonts.poppins(color: Colors.grey[900], fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      );
    });
  }
}
