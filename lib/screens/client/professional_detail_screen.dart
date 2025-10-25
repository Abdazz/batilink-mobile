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
    Key? key,
    required this.professionalId,
    this.token,
    this.userData,
  }) : super(key: key);

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
  Map<String, dynamic> _reviewDetails = {}; // Pour stocker les détails des devis associés aux avis
  final List<Map<String, dynamic>> _tabs = [
    {'label': 'À propos', 'icon': Icons.info_outline},
    {'label': 'Portfolio', 'icon': Icons.photo_library_outlined},
    {'label': 'Avis', 'icon': Icons.star_border},
  ];

  // Contrôleurs de défilement pour chaque onglet
  final ScrollController _aboutScrollController = ScrollController();
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
          case 0:
            if (_aboutScrollController.hasClients) {
              _aboutScrollController.animateTo(
                0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
            break;
          case 1:
            if (_portfolioScrollController.hasClients) {
              _portfolioScrollController.animateTo(
                0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
            break;
          case 2:
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

      final data = await ApiService.get('professionals/${widget.professionalId}');

      print('Données reçues: $data');

      if (data != null) {
        // Structure de réponse pour les détails du professionnel
        final Map<String, dynamic> responseData = data is Map<String, dynamic> ? data : {};
        final Map<String, dynamic> professionalData = responseData['data'] is Map<String, dynamic>
            ? responseData['data'] as Map<String, dynamic>
            : {};

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
            print('Erreur lors du chargement du devis ${quotationId}: $e');
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

  Widget _buildAboutTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_professional == null) {
      return const Center(child: Text('Aucune donnée disponible'));
    }

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

          // Adresse et localisation
          Text(
            'Localisation',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFFCC00),
            ),
          ),
          const SizedBox(height: 12),
          Container(
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
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFCC00).withOpacity(0.1),
                      ),
                      child: const Icon(Icons.location_on, color: Color(0xFFFFCC00), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Localisation',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _professional?.address != null && _professional!.address.isNotEmpty
                                ? _professional!.address
                                : 'Adresse non spécifiée',
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFCC00).withOpacity(0.1),
                      ),
                      child: const Icon(Icons.place, color: Color(0xFFFFCC00), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ville',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_professional?.city ?? 'Ville non spécifiée'}, ${_professional?.postalCode ?? ''}',
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_professional?.radiusKm != null && _professional!.radiusKm > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFFCC00).withOpacity(0.1),
                        ),
                        child: const Icon(Icons.gps_fixed, color: Color(0xFFFFCC00), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rayon d\'intervention',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_professional!.radiusKm} km',
                              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Informations professionnelles détaillées
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Note moyenne',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
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
                        itemSize: 20.0,
                        direction: Axis.horizontal,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_professional?.rating.toStringAsFixed(1) ?? '0.0'}/5',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
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
              ElevatedButton.icon(
                icon: const Icon(Icons.rate_review, size: 16),
                label: Text(
                  'Donner mon avis',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                onPressed: _showRatingDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCC00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
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
                  // En-tête avec photo et informations principales (hauteur contrainte)
                  Container(
                    height: 400,
                    child: SingleChildScrollView(
                      child: _buildHeaderSection(),
                    ),
                  ),

                  // Barre d'onglets - directement sous la photo
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      tabs: _tabs
                          .map((tab) => Tab(
                                text: tab['label'],
                                icon: Icon(tab['icon']),
                              ))
                          .toList(),
                      onTap: (index) {
                        // L'index est géré automatiquement par le TabController
                      },
                      labelColor: const Color(0xFFFFCC00),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFFFFCC00),
                      indicatorWeight: 3,
                    ),
                  ),

                  // Contenu des onglets (espace restant)
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAboutTab(),
                        _buildPortfolioTab(),
                        _buildReviewsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuoteRequestScreen(
              professionalId: widget.professionalId,
              professionalName: _professional?.displayName ?? 'Professionnel',
              professionalJob: _professional?.jobTitle ?? _professional?.profession ?? 'Service',
              token: widget.token,
              userData: widget.userData,
            ),
          ),
        ),
        backgroundColor: const Color(0xFFFFCC00),
        icon: const Icon(Icons.request_quote),
        label: const Text('Demander un devis'),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFCC00),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          // Photo et statut uniquement - les infos détaillées vont dans les onglets
          Stack(
            children: [
              Container(
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: _professional?.fullAvatarUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: _professional!.fullAvatarUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.person, size: 100, color: Colors.grey),
                              ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.person, size: 100, color: Colors.grey),
                        ),
                      ),
              ),

              // Statut de disponibilité
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _professional?.isAvailable == true
                        ? Colors.green.withValues(alpha: 0.9)
                        : Colors.red.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _professional?.isAvailable == true ? 'Disponible' : 'Indisponible',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Informations essentielles juste sous la photo (nom, métier, note)
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom et métier avec badge professionnel
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _professional?.displayName ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFCC00).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: const Color(0xFFFFCC00),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _professional?.jobTitle?.isNotEmpty == true
                                  ? (_professional?.jobTitle ?? _professional?.profession ?? 'Service non spécifié')
                                  : (_professional?.profession ?? 'Service non spécifié'),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: const Color(0xFFFFCC00),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFCC00).withOpacity(0.1),
                        border: Border.all(
                          color: const Color(0xFFFFCC00),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.verified,
                        color: const Color(0xFFFFCC00),
                        size: 24,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Note et informations principales
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              RatingBarIndicator(
                                rating: _professional?.rating ?? 0,
                                itemBuilder: (context, _) => const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                ),
                                itemCount: 5,
                                itemSize: 20.0,
                                direction: Axis.horizontal,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(_professional?.rating ?? 0).toStringAsFixed(1)}/5',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFFFCC00),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${_professional?.reviewCount ?? 0} avis clients',
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getImageUrl(Map<String, dynamic> item) {
    // Essaie différentes clés possibles pour l'image
    String? imageUrl = item['image_url'] ?? item['image'] ?? item['image_path'];

    if (imageUrl != null && imageUrl.isNotEmpty) {
      // Si l'URL ne commence pas par http, la compléter
      if (!imageUrl.startsWith('http')) {
        return AppConfig.buildMediaUrl(imageUrl);
      }
      return imageUrl;
    }
    return '';
  }

  Widget _buildPortfolioImage(Map<String, dynamic> item) {
    final imageUrl = _getImageUrl(item);

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        color: Colors.grey[200],
      ),
      child: imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) {
                  print('Erreur de chargement image: $url - $error');
                  return const Center(
                    child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                  );
                },
              ),
            )
          : const Center(
              child: Icon(Icons.photo, size: 40, color: Colors.grey),
            ),
    );
  }

  Future<String?> _getTokenFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
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
}
