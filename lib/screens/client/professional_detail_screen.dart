import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/professional.dart';
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
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      print('Chargement des données pour le professionnel: ${widget.professionalId}');

      const baseUrl = 'http://10.0.2.2:8000';
      final professionalUrl = '$baseUrl/api/professionals/${widget.professionalId}';

      print('Tentative de connexion à: $professionalUrl');

      // Récupérer le token d'authentification depuis les paramètres ou SharedPreferences
      final token = widget.token ?? await _getTokenFromPrefs();

      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = 'Token d\'authentification manquant. Veuillez vous reconnecter.';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(professionalUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('Code de statut: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('Réponse reçue: ${response.body}');

        final responseData = json.decode(utf8.decode(response.bodyBytes));

        // Structure de réponse pour les détails du professionnel
        final Map<String, dynamic> data = responseData is Map<String, dynamic> ? responseData : {};
        final Map<String, dynamic> professionalData = data['data'] is Map<String, dynamic>
            ? data['data'] as Map<String, dynamic>
            : {};

        if (mounted) {
          setState(() {
            _professional = Professional.fromJson(professionalData);
            _isLoading = false;
          });
        }

        // Charger les détails supplémentaires si disponibles
        _loadReviews();

      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        final errorMessage = error['message'] ?? 'Échec du chargement du profil professionnel (${response.statusCode})';

        if (response.statusCode == 401) {
          throw Exception('Authentification requise. Veuillez vous reconnecter.');
        } else if (response.statusCode == 404) {
          throw Exception('Professionnel non trouvé. Vérifiez l\'identifiant.');
        } else {
          throw Exception(errorMessage);
        }
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
      final reviewsUrl = 'http://10.0.2.2:8000/api/professionals/${widget.professionalId}/reviews';
      print('Chargement des avis depuis: $reviewsUrl');

      // Récupérer le token d'authentification depuis les paramètres ou SharedPreferences
      final token = widget.token ?? await _getTokenFromPrefs();

      final response = await http.get(
        Uri.parse(reviewsUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        final reviewsData = responseData is Map ? responseData['data'] ?? [] : [];

        if (mounted) {
          setState(() {
            _reviews = List<Map<String, dynamic>>.from(reviewsData);
          });
        }
      } else if (response.statusCode == 404 || response.statusCode == 500) {
        // Endpoint non trouvé ou erreur serveur - utiliser une liste vide
        print('Avis non disponibles pour ce professionnel (code: ${response.statusCode})');
        if (mounted) {
          setState(() {
            _reviews = [];
          });
        }
      } else {
        print('Erreur lors du chargement des avis: ${response.statusCode}');
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

                  final response = await http.post(
                    Uri.parse('http://10.0.2.2:8000/api/professionals/${widget.professionalId}/reviews'),
                    headers: {
                      'Accept': 'application/json',
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $token',
                    },
                    body: json.encode({
                      'rating': rating,
                      'comment': commentController.text,
                    }),
                  );

                  if (response.statusCode == 201) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Votre avis a été enregistré avec succès'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadReviews();
                    }
                  } else if (response.statusCode == 401) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Authentification requise. Veuillez vous reconnecter.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else {
                    final error = jsonDecode(utf8.decode(response.bodyBytes));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur: ${error['message'] ?? 'Erreur lors de l\'envoi de l\'avis'}'),
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
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
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
              color: const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF4CAF50), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _professional?.address != null && _professional!.address!.isNotEmpty
                            ? _professional!.address!
                            : 'Adresse non spécifiée',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.place, color: Color(0xFF4CAF50), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_professional?.city ?? 'Ville non spécifiée'}, ${_professional?.postalCode ?? ''}',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ],
                ),
                if (_professional?.radiusKm != null && _professional!.radiusKm! > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.gps_fixed, color: Color(0xFF4CAF50), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Rayon d\'intervention: ${_professional!.radiusKm} km',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Informations professionnelles détaillées
          Text(
            'Informations professionnelles',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                _buildDetailRow('Expérience', '${_professional?.experienceYears ?? 0} années'),
                const SizedBox(height: 12),
                _buildDetailRow('Tarif horaire', '${_professional?.hourlyRate?.toStringAsFixed(0) ?? '0'} €'),
                const SizedBox(height: 12),
                _buildDetailRow('Prix minimum', '${_professional?.minPrice?.toStringAsFixed(0) ?? '0'} €'),
                const SizedBox(height: 12),
                _buildDetailRow('Prix maximum', '${_professional?.maxPrice?.toStringAsFixed(0) ?? '0'} €'),
                const SizedBox(height: 12),
                _buildDetailRow('Projets terminés', '${_professional?.completedJobs ?? 0}'),
                const SizedBox(height: 12),
                _buildDetailRow('Statut', _professional?.isAvailable == true ? 'Disponible' : 'Indisponible',
                  valueColor: _professional?.isAvailable == true ? Colors.green : Colors.red),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Compétences si elles ne sont pas déjà affichées plus haut
          // Compétences si elles ne sont pas déjà affichées plus haut
          if (_professional?.skills?.isNotEmpty == true && (_professional?.detailedSkills?.isEmpty ?? true)) ...[
            Text(
              'Compétences',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _professional!.skills.map((skill) {
                return Chip(
                  label: Text(skill),
                  backgroundColor: Colors.blue[50],
                  labelStyle: GoogleFonts.poppins(fontSize: 12),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
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
              color: valueColor ?? Colors.black87,
              fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
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
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    color: Colors.grey[200],
                  ),
                  child: item['image_url'] != null
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: CachedNetworkImage(
                            imageUrl: item['image_url'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) =>
                                const Center(
                                  child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                ),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.photo, size: 40, color: Colors.grey),
                        ),
                ),
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
                        '${_professional?.rating?.toStringAsFixed(1) ?? '0.0'}/5',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4CAF50),
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
                  backgroundColor: const Color(0xFF4CAF50),
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
              ? SingleChildScrollView( // ✅ Défilement pour l'état vide
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
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
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
                                CircleAvatar(
                                  backgroundColor: const Color(0xFF4CAF50).withOpacity(0.1),
                                  child: Text(
                                    review['user_name']?[0].toUpperCase() ?? '?',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF4CAF50),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        review['user_name'] ?? 'Anonyme',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
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
                                Text(
                                  _formatDate(review['created_at'] ?? ''),
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (review['comment'] != null && review['comment'].toString().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  review['comment'].toString(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    height: 1.4,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Première ligne
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.work,
                  title: 'Expérience',
                  value: '${_professional?.experienceYears ?? 0} ans',
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.euro,
                  title: 'Tarif horaire',
                  value: '${_professional?.hourlyRate?.toStringAsFixed(0) ?? '0'} €',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Deuxième ligne
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.location_on,
                  title: 'Localisation',
                  value: _professional?.city ?? 'Non spécifiée',
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.check_circle,
                  title: 'Projets terminés',
                  value: '${_professional?.completedJobs ?? 0}',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Troisième ligne
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.attach_money,
                  title: 'Prix min',
                  value: '${_professional?.minPrice?.toStringAsFixed(0) ?? '0'} €',
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.trending_up,
                  title: 'Prix max',
                  value: '${_professional?.maxPrice?.toStringAsFixed(0) ?? '0'} €',
                ),
              ),
            ],
          ),

          if (_professional?.radiusKm != null && _professional!.radiusKm! > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.gps_fixed,
                    title: 'Rayon d\'intervention',
                    value: '${_professional!.radiusKm} km',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF4CAF50),
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
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ],
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
    final screenHeight = MediaQuery.of(context).size.height;
    final headerHeight = screenHeight * 0.6; // 60% de la hauteur d'écran pour l'en-tête

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4CAF50)),
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
                    height: headerHeight,
                    child: SingleChildScrollView(
                      child: _buildHeaderSection(),
                    ),
                  ),

                  // Barre d'onglets
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
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
                      labelColor: Theme.of(context).primaryColor,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Theme.of(context).primaryColor,
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
            ),
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        icon: const Icon(Icons.request_quote),
        label: const Text('Demander un devis'),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF4CAF50).withOpacity(0.1),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          // Photo et statut
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
                child: _professional?.photoUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: _professional!.photoUrl!,
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

          // Informations principales
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom et métier
                Text(
                  _professional?.displayName ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _professional?.jobTitle?.isNotEmpty == true
                      ? (_professional?.jobTitle ?? _professional?.profession ?? 'Service non spécifié')
                      : (_professional?.profession ?? 'Service non spécifié'),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 16),

                // Note et informations principales
                Row(
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
                          '${(_professional?.rating ?? 0).toStringAsFixed(1)} (${_professional?.reviewCount ?? 0} avis)',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Informations détaillées en grille
                _buildInfoGrid(),

                const SizedBox(height: 16),

                // Compétences détaillées
                if (_professional?.detailedSkills?.isNotEmpty == true) ...[
                  Text(
                    'Compétences',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4CAF50),
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
          ),
        ],
      ),
    );
  }

  Future<String?> _getTokenFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }
}
