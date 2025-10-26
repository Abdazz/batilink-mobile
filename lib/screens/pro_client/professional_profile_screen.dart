import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_config.dart';

class ProfessionalProfileScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> userData;

  const ProfessionalProfileScreen({
    Key? key,
    required this.token,
    required this.userData,
  }) : super(key: key);

  @override
  _ProfessionalProfileScreenState createState() => _ProfessionalProfileScreenState();
}

class _ProfessionalProfileScreenState extends State<ProfessionalProfileScreen> {
  Map<String, dynamic>? _professionalData;
  bool _isLoading = true;
  String? _errorMessage;
  String _token = '';

  // Statistiques professionnelles
  int _totalJobs = 0;
  int _totalClients = 0;
  int _totalEarnings = 0;
  double _rating = 0.0;
  int _reviewCount = 0;

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

    setState(() {
      _token = finalToken;
    });

    _loadProfessionalProfile();
  }

  Future<void> _loadProfessionalProfile() async {
    try {
      final token = _token;
      if (token.isEmpty) {
        _showError('Token d\'authentification manquant');
        return;
      }

      print('=== DEBUG PROFIL PROFESSIONNEL ===');
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
          print('=== DEBUG STRUCTURE API ===');
          print('Clés disponibles dans la réponse: ${data.keys}');

          // L'API /api/professional/profile/me retourne directement les données du professionnel
          Map<String, dynamic>? professionalData;

          // Si la structure contient 'data', utilise data
          if (data.containsKey('data')) {
            final apiData = data['data'];
            if (apiData is Map<String, dynamic>) {
              professionalData = apiData;
            }
          } else {
            // Si pas de 'data', utilise directement le contenu (structure alternative)
            professionalData = data;
          }

          print('Données professionnelles finales: $professionalData');

          if (professionalData is Map<String, dynamic> && professionalData.isNotEmpty) {
            final finalProfessionalData = professionalData;

            // Les données du professionnel sont directement dans professionalData
            setState(() {
              _professionalData = finalProfessionalData;
            });

            // Extraction des statistiques depuis les champs du professionnel
            // Gestion robuste des différents formats de données
            final stats = <String, dynamic>{};

            // Essaie d'abord les champs directs du professionnel
            if (finalProfessionalData.containsKey('completed_jobs')) {
              stats['total_jobs'] = finalProfessionalData['completed_jobs'];
            }
            if (finalProfessionalData.containsKey('rating')) {
              stats['average_rating'] = finalProfessionalData['rating'];
            }
            if (finalProfessionalData.containsKey('review_count')) {
              stats['review_count'] = finalProfessionalData['review_count'];
            }

            // Essaie ensuite les champs avec des noms alternatifs
            if (stats.isEmpty || !stats.containsKey('total_jobs')) {
              stats['total_jobs'] = finalProfessionalData['total_jobs_as_professional'] ??
                                  finalProfessionalData['jobs_completed'] ?? 0;
            }
            if (!stats.containsKey('average_rating')) {
              stats['average_rating'] = finalProfessionalData['average_rating'] ??
                                       finalProfessionalData['rating'] ?? 0.0;
            }
            if (!stats.containsKey('review_count')) {
              stats['review_count'] = finalProfessionalData['review_count'] ??
                                     finalProfessionalData['total_reviews'] ?? 0;
            }

            // Application des statistiques
            setState(() {
              _totalJobs = stats['total_jobs'] ?? 0;
              _totalClients = stats['total_clients'] ?? 0;
              _totalEarnings = stats['total_earnings'] ?? 0;
              _rating = (stats['average_rating'] ?? 0.0).toDouble();
              _reviewCount = stats['review_count'] ?? 0;
            });

            setState(() {
              _isLoading = false;
            });

            print('Profil professionnel chargé avec succès depuis API /api/professional/profile/me');
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
          _errorMessage = 'Erreur lors de la récupération du profil professionnel (${response.statusCode})';
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      print('Exception lors du chargement du profil professionnel: $e');
      setState(() {
        _errorMessage = 'Erreur de connexion lors du chargement du profil professionnel';
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

  Widget _getProfessionalAvatar() {
    // L'API peut retourner l'avatar dans 'avatar' ou dans 'profile_photo.url'
    String? avatarUrl;

    // Essaie d'abord profile_photo.url (structure API /api/professional/profile/me)
    final profilePhoto = _professionalData?['profile_photo'];
    if (profilePhoto != null) {
      if (profilePhoto is Map<String, dynamic>) {
        // Structure: {path: "...", url: "...", type: "..."}
        avatarUrl = profilePhoto['url'];
      } else if (profilePhoto is String) {
        // Structure alternative: URL directe
        avatarUrl = profilePhoto;
      }
    }

    // Essaie ensuite avatar (structure alternative)
    if (avatarUrl == null || avatarUrl.isEmpty) {
      avatarUrl = _professionalData?['avatar'];
    }

    print('=== DEBUG AVATAR ===');
    print('Profile photo: $profilePhoto');
    print('Avatar URL trouvée: $avatarUrl');

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[200],
        border: Border.all(
          color: const Color(0xFF1E3A5F),
          width: 3,
        ),
      ),
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const CircularProgressIndicator(
                  color: Color(0xFF1E3A5F),
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.business_center,
                  color: Color(0xFF1E3A5F),
                  size: 40,
                ),
              ),
            )
          : const Icon(
              Icons.business_center,
              color: Color(0xFF1E3A5F),
              size: 40,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mon Profil Professionnel',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1E3A5F),
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
                        _errorMessage ?? 'Erreur lors du chargement du profil professionnel',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProfessionalProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
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
                      // Section Informations professionnelles
                      _buildSectionTitle('Informations professionnelles'),
                      const SizedBox(height: 12),
                      _buildProfessionalInfoCard(),

                      const SizedBox(height: 24),

                      // Section Statistiques
                      _buildSectionTitle('Statistiques'),
                      const SizedBox(height: 12),
                      _buildStatsCard(),

                      const SizedBox(height: 24),

                      // Section Documents et certifications
                      if (_professionalData?['documents'] != null) ...[
                        _buildSectionTitle('Documents et certifications'),
                        const SizedBox(height: 12),
                        _buildDocumentsCard(),
                        const SizedBox(height: 24),
                      ],

                      // Section Compétences
                      if (_professionalData?['skills'] != null) ...[
                        _buildSectionTitle('Compétences'),
                        const SizedBox(height: 12),
                        _buildSkillsCard(),
                        const SizedBox(height: 24),
                      ],

                      // Section Horaires d'ouverture
                      _buildSectionTitle('Horaires d\'ouverture'),
                      const SizedBox(height: 12),
                      _buildBusinessHoursCard(),
                      const SizedBox(height: 24),

                      // Section Coordonnées professionnelles
                      _buildSectionTitle('Coordonnées professionnelles'),
                      const SizedBox(height: 12),
                      _buildContactCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1E3A5F),
      ),
    );
  }

  Widget _buildProfessionalInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Avatar et informations principales
            Row(
              children: [
                _getProfessionalAvatar(),
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
                          color: const Color(0xFF1E3A5F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _professionalData?['job_title'] ?? 'Poste non défini',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber[600], size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${_rating.toStringAsFixed(1)} (${_reviewCount} avis)',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Informations détaillées
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    'Statut:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E3A5F),
                      fontSize: 14,
                    ),
                  ),
                ),
                _getStatusBadge(_professionalData?['status']),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow('RCCM', _professionalData?['rccm_number'] ?? 'Non défini'),
            const SizedBox(height: 8),
            _buildInfoRow('Description', _professionalData?['description'] ?? 'Aucune description'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
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
              height: 1.4,
            ),
          ),
        ),
      ],
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
                _buildStatItem(_totalJobs.toString(), 'Projets\nterminés'),
                _buildStatItem(_totalClients.toString(), 'Clients\nsatisfaits'),
                _buildStatItem('${_totalEarnings}€', 'Revenus\ntotaux'),
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
            color: const Color(0xFF1E3A5F),
          ),
        ),
        const SizedBox(height: 4),
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

  Widget _buildDocumentsCard() {
    final documentsData = _professionalData?['documents'];

    if (documentsData == null) {
      return const SizedBox.shrink();
    }

    // Gestion flexible du type de documents
    List<dynamic> documents = [];
    if (documentsData is List<dynamic>) {
      documents = documentsData;
    } else if (documentsData is Map<String, dynamic>) {
      // Si c'est un Map, convertir en List
      documents = documentsData.values.toList();
    }

    if (documents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
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
                Icon(Icons.description, color: const Color(0xFF1E3A5F)),
                const SizedBox(width: 8),
                Text(
                  'Documents',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...documents.map((doc) => _buildDocumentItem(doc)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentItem(dynamic document) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              document['name'] ?? 'Document',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
          Text(
            document['type'] ?? 'Type inconnu',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsCard() {
    final skillsData = _professionalData?['skills'];

    if (skillsData == null) {
      return const SizedBox.shrink();
    }

    // Gestion flexible du type de skills
    List<dynamic> skills = [];
    if (skillsData is List<dynamic>) {
      skills = skillsData;
    } else if (skillsData is Map<String, dynamic>) {
      // Si c'est un Map, convertir en List
      skills = skillsData.values.toList();
    }

    if (skills.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
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
                Icon(Icons.psychology, color: const Color(0xFF1E3A5F)),
                const SizedBox(width: 8),
                Text(
                  'Compétences',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills.map((skill) => _buildSkillChip(skill)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillChip(dynamic skill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.3)),
      ),
      child: Text(
        skill['name'] ?? 'Compétence',
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF1E3A5F),
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    return Card(
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
                Icon(Icons.contact_mail, color: const Color(0xFF1E3A5F)),
                const SizedBox(width: 8),
                Text(
                  'Coordonnées',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Adresse', _professionalData?['address'] ?? 'Non définie'),
            const SizedBox(height: 8),
            _buildInfoRow('Ville', _professionalData?['city'] ?? 'Non définie'),
            const SizedBox(height: 8),
            _buildInfoRow('Code postal', _professionalData?['postal_code'] ?? 'Non défini'),
            if (_professionalData?['website'] != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow('Site web', _professionalData!['website']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessHoursCard() {
    final businessHours = _professionalData?['business_hours'];

    if (businessHours == null) {
      return const SizedBox.shrink();
    }

    print('=== DEBUG BUSINESS HOURS TYPE ===');
    print('Type: ${businessHours.runtimeType}');
    print('Value: $businessHours');

    // Gestion flexible du type de business_hours
    Map<String, dynamic> hoursMap = {};
    if (businessHours is Map<String, dynamic>) {
      // Si c'est déjà un Map, vérifier les clés
      final keys = businessHours.keys.toList();
      print('Map keys: $keys');

      // Si les clés sont en anglais, les convertir en français
      if (keys.any((key) => ['monday', 'tuesday', 'wednesday'].contains(key.toLowerCase()))) {
        print('Converting English keys to French...');
        final dayMapping = {
          'monday': 'lundi', 'tuesday': 'mardi', 'wednesday': 'mercredi',
          'thursday': 'jeudi', 'friday': 'vendredi', 'saturday': 'samedi', 'sunday': 'dimanche'
        };

        for (var entry in businessHours.entries) {
          final frenchKey = dayMapping[entry.key.toLowerCase()];
          if (frenchKey != null) {
            hoursMap[frenchKey] = entry.value;
          }
        }
      } else {
        // Utiliser directement le Map si les clés sont déjà en français
        hoursMap = businessHours;
      }
    } else if (businessHours is String) {
      print('Business hours is String, trying to parse JSON...');
      try {
        // Si c'est une string qui contient du JSON, la parser
        final parsed = json.decode(businessHours);
        if (parsed is Map<String, dynamic>) {
          print('Successfully parsed JSON string to Map');
          final keys = parsed.keys.toList();
          print('Parsed keys: $keys');

          // Si les clés sont en anglais, les convertir en français
          if (keys.any((key) => ['monday', 'tuesday', 'wednesday'].contains(key.toLowerCase()))) {
            print('Converting English keys to French...');
            final dayMapping = {
              'monday': 'lundi', 'tuesday': 'mardi', 'wednesday': 'mercredi',
              'thursday': 'jeudi', 'friday': 'vendredi', 'saturday': 'samedi', 'sunday': 'dimanche'
            };

            for (var entry in parsed.entries) {
              final frenchKey = dayMapping[entry.key.toLowerCase()];
              if (frenchKey != null) {
                hoursMap[frenchKey] = entry.value;
              }
            }
          } else {
            hoursMap = parsed;
          }
        } else {
          print('Parsed JSON is not a Map: ${parsed.runtimeType}');
          // Si c'est une string simple (pas du JSON), l'utiliser directement
          return _buildSimpleHoursCard(businessHours);
        }
      } catch (e) {
        print('Failed to parse JSON string: $e');
        // Si c'est une string simple (pas du JSON), l'utiliser directement
        return _buildSimpleHoursCard(businessHours);
      }
    } else if (businessHours is List<dynamic>) {
      // Si c'est une liste, essayer de la convertir en Map
      print('Business hours is List, trying to convert...');
      final days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
      for (var i = 0; i < days.length && i < businessHours.length; i++) {
        hoursMap[days[i]] = businessHours[i];
      }
    } else {
      // Pour tout autre type, afficher un message d'erreur
      return Card(
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
                  Icon(Icons.schedule, color: const Color(0xFF1E3A5F)),
                  const SizedBox(width: 8),
                  Text(
                    'Horaires d\'ouverture',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E3A5F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Format d\'horaires non supporté',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.red,
                ),
              ),
              Text(
                'Type reçu: ${businessHours.runtimeType}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              Text(
                'Valeur: ${businessHours.toString()}',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (hoursMap.isEmpty) {
      return const SizedBox.shrink();
    }

    final isOpenNow = _computeIsOpenNow(hoursMap);

    return Card(
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
                Icon(Icons.schedule, color: const Color(0xFF1E3A5F)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Horaires d\'ouverture',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E3A5F),
                    ),
                  ),
                ),
                _buildOpenNowBadge(isOpenNow),
              ],
            ),
            const SizedBox(height: 16),
            ..._buildGroupedBusinessHoursList(hoursMap),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedBusinessHoursList(Map<String, dynamic> businessHours) {
    try {
      // L'API retourne les jours en français
      final days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
      final dayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
      final dayLabelsShort = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      final todayIdx = _todayIndex();

      print('=== DEBUG BUILDING HOURS LIST ===');
      print('Available keys: ${businessHours.keys.toList()}');

      // Normalize to schedule strings per day
      final normalized = <int, String>{};
      for (var i = 0; i < days.length; i++) {
        final dayData = businessHours[days[i]];
        String schedule;

        print('Processing day $i (${days[i]}): $dayData (type: ${dayData?.runtimeType})');

        if (dayData == null || dayData.isEmpty) {
          schedule = 'Fermé';
        } else if (dayData is Map<String, dynamic>) {
          final openTime = dayData['open']?.toString() ?? '';
          final closeTime = dayData['close']?.toString() ?? '';

          if (openTime.isEmpty || closeTime.isEmpty) {
            schedule = 'Fermé';
          } else {
            schedule = '$openTime – $closeTime';
          }
        } else if (dayData is String) {
          schedule = dayData;
        } else if (dayData is List<dynamic>) {
          // Si c'est une liste de créneaux pour ce jour
          if (dayData.isEmpty) {
            schedule = 'Fermé';
          } else {
            // Prendre le premier créneau ou les concaténer
            final slots = dayData.map((slot) {
              if (slot is Map<String, dynamic>) {
                final open = slot['open']?.toString() ?? '';
                final close = slot['close']?.toString() ?? '';
                return open.isNotEmpty && close.isNotEmpty ? '$open – $close' : 'Fermé';
              } else if (slot is String) {
                return slot;
              }
              return 'Fermé';
            }).where((s) => s != 'Fermé').toList();

            schedule = slots.isNotEmpty ? slots.join(', ') : 'Fermé';
          }
        } else if (dayData is bool) {
          // Si c'est un boolean (true = ouvert, false = fermé)
          schedule = dayData ? 'Ouvert' : 'Fermé';
        } else {
          // Pour tout autre format, essayer de le convertir en string
          schedule = dayData.toString();
          print('Converted to string: $schedule');
        }
        normalized[i] = schedule;
        print('Final schedule for ${days[i]}: $schedule');
      }

      // Group consecutive days with same schedule
      final groups = <Map<String, dynamic>>[];
      int start = 0;
      String current = normalized[0] ?? 'Fermé';
      for (var i = 1; i < days.length; i++) {
        final next = normalized[i] ?? 'Fermé';
        if (next != current) {
          groups.add({'start': start, 'end': i - 1, 'schedule': current});
          start = i;
          current = next;
        }
      }
      groups.add({'start': start, 'end': days.length - 1, 'schedule': current});

      // Build UI
      return groups.map((group) {
        final startIdx = group['start'] as int;
        final endIdx = group['end'] as int;
        final schedule = group['schedule'] as String;
        final label = startIdx == endIdx
            ? dayNames[startIdx]
            : '${dayLabelsShort[startIdx]} – ${dayLabelsShort[endIdx]}';
        final includesToday = todayIdx >= startIdx && todayIdx <= endIdx;
        final isClosed = schedule.toLowerCase().contains('fermé');
        final color = isClosed ? Colors.grey : const Color(0xFF1E3A5F);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
              ),
              Text(
                schedule,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (includesToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.2)),
                  ),
                  child: Text(
                    "Aujourd'hui",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E3A5F),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList();
    } catch (e) {
      print('Error building hours list: $e');
      return [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Erreur lors du traitement des horaires',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      ];
    }
  }

  bool _computeIsOpenNow(Map<String, dynamic> businessHours) {
    try {
      final days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
      final now = DateTime.now();
      final idx = _todayIndex();
      final key = days[idx];
      final dayData = businessHours[key];
      if (dayData == null) return false;

      print('=== DEBUG IS OPEN NOW ===');
      print('Today: $key, Data: $dayData, Type: ${dayData.runtimeType}');

      String? open;
      String? close;
      if (dayData is Map<String, dynamic>) {
        open = dayData['open']?.toString();
        close = dayData['close']?.toString();
      } else if (dayData is String) {
        if (dayData.toLowerCase().contains('fermé') || dayData.toLowerCase().contains('closed')) return false;
        if (dayData.toLowerCase().contains('ouvert') || dayData.toLowerCase().contains('open')) return true;
        final parts = dayData.split(RegExp(r"\s*–\s*"));
        if (parts.length == 2) {
          open = parts[0].trim();
          close = parts[1].trim();
        }
      } else if (dayData is List<dynamic> && dayData.isNotEmpty) {
        // Prendre le premier créneau de la journée
        final firstSlot = dayData.first;
        if (firstSlot is Map<String, dynamic>) {
          open = firstSlot['open']?.toString();
          close = firstSlot['close']?.toString();
        } else if (firstSlot is String) {
          if (firstSlot.toLowerCase().contains('fermé') || firstSlot.toLowerCase().contains('closed')) return false;
          if (firstSlot.toLowerCase().contains('ouvert') || firstSlot.toLowerCase().contains('open')) return true;
          final parts = firstSlot.split(RegExp(r"\s*–\s*"));
          if (parts.length == 2) {
            open = parts[0].trim();
            close = parts[1].trim();
          }
        }
      } else if (dayData is bool) {
        return dayData; // true = ouvert, false = fermé
      } else if (dayData != null) {
        // Pour tout autre format, essayer de le convertir en string
        final stringValue = dayData.toString().toLowerCase();
        if (stringValue.contains('fermé') || stringValue.contains('closed') || stringValue == 'false') return false;
        if (stringValue.contains('ouvert') || stringValue.contains('open') || stringValue == 'true') return true;
      }

      if (open == null || close == null || open.isEmpty || close.isEmpty) return false;

      final nowMinutes = now.hour * 60 + now.minute;
      final openMin = _parseTimeToMinutes(open);
      final closeMin = _parseTimeToMinutes(close);
      if (openMin == null || closeMin == null) return false;

      return nowMinutes >= openMin && nowMinutes <= closeMin;
    } catch (e) {
      print('Error computing is open now: $e');
      return false;
    }
  }

  int _todayIndex() {
    return DateTime.now().weekday - 1; // 0 = Monday, 6 = Sunday
  }

  int? _parseTimeToMinutes(String hhmm) {
    try {
      final parts = hhmm.split(':');
      if (parts.length != 2) return null;
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return h * 60 + m;
    } catch (_) {
      return null;
    }
  }

  Widget _buildSimpleHoursCard(String hoursText) {
    final isOpenNow = _computeIsOpenNowFromString(hoursText);

    return Card(
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
                Icon(Icons.schedule, color: const Color(0xFF1E3A5F)),
                const SizedBox(width: 8),
                Text(
                  'Horaires d\'ouverture',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
                const Spacer(),
                _buildOpenNowBadge(isOpenNow),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hoursText,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF1E3A5F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _computeIsOpenNowFromString(String hoursText) {
    try {
      final now = DateTime.now();
      final today = _getTodayFrench();

      // Si le texte contient le jour d'aujourd'hui et des heures
      if (hoursText.toLowerCase().contains(today.toLowerCase())) {
        // Extraire les heures du jour actuel
        final regex = RegExp(r'\b(\d{1,2}:\d{2})\s*[-–]\s*(\d{1,2}:\d{2})\b');
        final match = regex.firstMatch(hoursText);
        if (match != null) {
          final open = match.group(1);
          final close = match.group(2);
          if (open != null && close != null) {
            final nowMinutes = now.hour * 60 + now.minute;
            final openMin = _parseTimeToMinutes(open);
            final closeMin = _parseTimeToMinutes(close);
            if (openMin != null && closeMin != null) {
              return nowMinutes >= openMin && nowMinutes <= closeMin;
            }
          }
        }
      }

      // Si le texte contient "fermé" ou "closed"
      if (hoursText.toLowerCase().contains('fermé') || hoursText.toLowerCase().contains('closed')) {
        return false;
      }

      // Si le texte contient "ouvert" ou "open"
      if (hoursText.toLowerCase().contains('ouvert') || hoursText.toLowerCase().contains('open')) {
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  String _getTodayFrench() {
    final dayNames = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
    return dayNames[DateTime.now().weekday - 1];
  }

  Widget _buildOpenNowBadge(bool isOpen) {
    final color = isOpen ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    final bg = color.withOpacity(0.1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isOpen ? Icons.check_circle : Icons.cancel, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            isOpen ? 'Ouvert' : 'Fermé',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
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

  String _getProfessionalStatusText(String? status) {
    switch (status) {
      case 'approved':
        return 'Approuvé';
      case 'pending':
        return 'En attente de validation';
      case 'rejected':
        return 'Rejeté';
      default:
        return 'Non défini';
    }
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
}
