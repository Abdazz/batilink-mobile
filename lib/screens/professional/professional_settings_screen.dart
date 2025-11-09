import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../services/document_service.dart';
import '../../core/app_config.dart';
import 'portfolio_management_screen.dart';
import 'business_hours_edit_screen.dart';
import 'professional_profile_edit_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfessionalSettingsScreen extends StatefulWidget {
  final String token;

  const ProfessionalSettingsScreen({Key? key, required this.token}) : super(key: key);

  @override
  _ProfessionalSettingsScreenState createState() => _ProfessionalSettingsScreenState();
}

class _ProfessionalSettingsScreenState extends State<ProfessionalSettingsScreen> {
  Map<String, dynamic> _profile = {};
  bool _isLoading = true;
  String _error = '';

  /// Transforme les données du profil pour inclure l'URL complète ou les données base64 de la photo de profil
  Map<String, dynamic> _transformProfileData(Map<String, dynamic> profileData) {
    print('=== DEBUG TRANSFORM PROFILE DATA ===');
    print('Données reçues dans _transformProfileData: $profileData');

    // Variables pour stocker l'URL ou les données base64 de la photo
    String? fullPhotoUrl;
    String? base64Image;

    // Vérifier si on a une image en base64
    if (profileData['profile_photo_base64'] != null) {
      print('=== DÉTECTION D\'UNE IMAGE BASE64 ===');
      final photoData = profileData['profile_photo_base64'];
      
      // Vérifier si c'est une chaîne base64 ou un objet avec une propriété 'data'
      if (photoData is String) {
        base64Image = photoData.startsWith('data:image/') 
            ? photoData 
            : 'data:image/jpeg;base64,$photoData';
      } else if (photoData is Map && photoData['data'] != null) {
        base64Image = photoData['data'].toString().startsWith('data:image/')
            ? photoData['data']
            : 'data:image/jpeg;base64,${photoData['data']}';
      }
      
      print('Image base64 détectée, longueur: ${base64Image?.length ?? 0} caractères');
    }
    
    // Si pas d'image en base64, essayer de récupérer l'URL de l'image
    if (base64Image == null) {
      // Nouvelle structure: profile_photo est un objet avec url
      if (profileData['profile_photo'] != null && profileData['profile_photo'] is Map) {
        final profilePhoto = profileData['profile_photo'] as Map<String, dynamic>;
        print('=== DEBUG PROFILE PHOTO ===');
        print('profile_photo reçu: $profilePhoto');
        print('URL reçue: ${profilePhoto['url']}');
        print('Path reçu: ${profilePhoto['path']}');
        print('Type reçu: ${profilePhoto['type']}');

        if (profilePhoto['url'] != null && profilePhoto['url'].toString().isNotEmpty) {
          final url = profilePhoto['url'].toString();
          print('URL à traiter: $url');

          // Vérifier si c'est une URL complète
          if (url.startsWith('http://') || url.startsWith('https://')) {
            print('URL complète détectée');
            // URL complète - vérifier que ce n'est pas un placeholder
            if (url != 'https://via.placeholder.com/150' && !url.contains('placeholder')) {
              print('URL valide trouvée: $url');
              fullPhotoUrl = url;
            } else {
              print('URL de placeholder ignorée');
            }
          } else {
            print('URL relative détectée, construction de l\'URL complète');
            // Nettoyer l'URL pour éviter les doublons de /storage/
            String cleanUrl = url.startsWith('/storage/') ? url.substring(8) : url;
            // Construire l'URL complète
            fullPhotoUrl = AppConfig.buildMediaUrl(cleanUrl);
            print('URL nettoyée: $cleanUrl');
            print('URL construite: $fullPhotoUrl');
          }
        } else {
          print('Aucune URL trouvée dans profile_photo');
        }
      }

      // Fallback: Ancienne structure avec profile_photo_path
      if (fullPhotoUrl == null && profileData['profile_photo_path'] != null && profileData['profile_photo_path'].toString().isNotEmpty) {
        fullPhotoUrl = AppConfig.buildMediaUrl(profileData['profile_photo_path']);
      }
    }

    // Créer une copie des données avec l'URL ou les données base64
    Map<String, dynamic> transformedData = Map<String, dynamic>.from(profileData);
    if (base64Image != null) {
      transformedData['profile_photo_base64'] = base64Image;
    } else {
      transformedData['profile_photo_url'] = fullPhotoUrl;
    }

    // Debug spécifique pour business_hours
    print('business_hours AVANT transformation: ${transformedData['business_hours']}');
    print('Type business_hours AVANT: ${transformedData['business_hours']?.runtimeType}');

    print('business_hours APRES transformation: ${transformedData['business_hours']}');
    print('Type business_hours APRES: ${transformedData['business_hours']?.runtimeType}');
    print('====================================');

    return transformedData;
  }

  @override
  void initState() {
    super.initState();
    _loadProfessionalProfile();
  }

  Future<void> _loadProfessionalProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? widget.token;

      print('=== DEBUG - Récupération du profil professionnel ===');
      print('Token: ${token.substring(0, 20)}...');
      print('URL: ${AppConfig.baseUrl}/api/professional/profile/me');

      final data = await ApiService.get('professional/profile/me');

      print('Données reçues: $data');
      print('Type de data: ${data.runtimeType}');

      if (data != null) {
        final profileData = data;

        print('Structure des données du profil: ${profileData.runtimeType}');

        // NOUVELLE STRUCTURE: L'API retourne directement l'objet profil dans 'data'
        if (profileData is Map && profileData['data'] != null) {
          final profile = profileData['data'];

          print('ID du profil récupéré: ${profile['id']}');
          print('Nom de l\'entreprise: ${profile['company_name']}');

          if (profile is Map<String, dynamic>) {
            setState(() {
              _profile = _transformProfileData(Map<String, dynamic>.from(profile));
            });

            // Debug: Vérifier les horaires reçus
            print('=== DEBUG PROFIL RÉCEPTION ===');
            print('Horaires reçus: ${_profile['business_hours']}');
            print('Type des horaires: ${_profile['business_hours'].runtimeType}');
            print('============================');
          } else {
            print('Format du profil inattendu: ${profile.runtimeType}');
            setState(() {
              _error = 'Format du profil inattendu';
            });
          }
        }
        // ANCIENNE STRUCTURE: L'API retourne un tableau dans data.data (pour compatibilité)
        else if (profileData is Map && profileData['data'] != null && profileData['data'] is List && (profileData['data'] as List).isNotEmpty) {
          final profiles = profileData['data'] as List;

          print('Nombre de profils reçus: ${profiles.length}');

          // Chercher le profil le plus récent ou le profil avec les données complètes
          Map<String, dynamic>? selectedProfile;

          // D'abord chercher par ID spécifique (si on connaît l'ID du profil créé)
          final prefs = await SharedPreferences.getInstance();
          final lastProfileId = prefs.getString('last_profile_id');

          if (lastProfileId != null && lastProfileId.isNotEmpty) {
            for (var profile in profiles) {
              if (profile is Map<String, dynamic> && profile['id'] == lastProfileId) {
                selectedProfile = profile;
                break;
              }
            }
          }

          // Sinon, chercher le profil avec les données les plus récentes (pas par défaut)
          if (selectedProfile == null) {
            for (var profile in profiles) {
              if (profile is Map<String, dynamic>) {
                final companyName = profile['company_name'] ?? '';
                if (companyName != 'Entreprise par défaut' && companyName.isNotEmpty) {
                  selectedProfile = profile;
                  break;
                }
              }
            }
          }

          // Si toujours pas trouvé, chercher par mots-clés dans la description ou le nom
          if (selectedProfile == null) {
            for (var profile in profiles) {
              if (profile is Map<String, dynamic>) {
                final companyName = (profile['company_name'] ?? '').toString().toLowerCase();
                final jobTitle = (profile['job_title'] ?? '').toString().toLowerCase();

                // Éviter les profils par défaut
                if (!companyName.contains('par défaut') && !jobTitle.contains('professionnel')) {
                  selectedProfile = profile;
                  break;
                }
              }
            }
          }

          // Dernière option: prendre le premier profil valide
          if (selectedProfile == null) {
            for (var profile in profiles) {
              if (profile is Map<String, dynamic> && profile['id'] != null) {
                selectedProfile = profile;
                break;
              }
            }
          }

          if (selectedProfile != null) {
            print('ID du profil sélectionné: ${selectedProfile['id']}');
            print('Nom de l\'entreprise sélectionnée: ${selectedProfile['company_name']}');

            // Debug spécifique pour business_hours
            print('=== DEBUG BUSINESS HOURS ===');
            print('business_hours dans profil brut: ${selectedProfile['business_hours']}');
            print('Type business_hours: ${selectedProfile['business_hours']?.runtimeType}');

            setState(() {
              _profile = _transformProfileData(Map<String, dynamic>.from(selectedProfile as Map<dynamic, dynamic>));
            });

            // Debug: Vérifier les horaires reçus après setState
            print('Horaires reçus après setState: ${_profile['business_hours']}');
            print('Type des horaires après setState: ${_profile['business_hours']?.runtimeType}');
            print('============================');
          } else {
            print('Aucun profil valide trouvé dans le tableau');
            setState(() {
              _error = 'Aucun profil professionnel valide trouvé';
            });
          }
        } else {
          print('Structure inattendue des données du profil');
          setState(() {
            _error = 'Aucun profil professionnel trouvé pour votre compte';
          });
        }
      } else {
        print('Réponse API invalide: success=false ou data=null');
        setState(() {
          _error = 'Format de réponse inattendu de l\'API';
        });
      }
    } catch (e) {
      print('Exception lors de la récupération du profil: $e');
      setState(() {
        _error = 'Erreur de connexion: $e';
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
        backgroundColor: const Color(0xFFFFCC00),
        elevation: 0,
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back, color: Color(0xFFFFCC00)),
        //   onPressed: () => Navigator.of(context).pop(),
        // ),
        title: Text(
          'Mon profil professionnel',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFFCC00)),
            onPressed: _loadProfessionalProfile,
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
            if (_error.contains('non trouvé') || _error.contains('Aucun profil'))
              ElevatedButton.icon(
                onPressed: () {
                  // Naviguer vers l'écran de complétion du profil
                  Navigator.pushNamed(context, '/professional-complete-profile');
                },
                icon: const Icon(Icons.add),
                label: const Text('Compléter mon profil'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCC00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            if (!_error.contains('non trouvé') && !_error.contains('Aucun profil'))
              ElevatedButton(
                onPressed: _loadProfessionalProfile,
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec informations principales
          _buildProfileHeader(),

          const SizedBox(height: 32),

          // Informations professionnelles
          _buildSection('Informations professionnelles', [
            _buildInfoRow(Icons.business, 'Entreprise', _profile['company_name'] ?? 'Non spécifiée'),
            _buildInfoRow(Icons.work, 'Métier', _profile['job_title'] ?? 'Non spécifié'),
            _buildInfoRow(Icons.description, 'Description', _profile['description'] ?? 'Non spécifiée'),
            _buildInfoRow(Icons.star, 'Expérience', '${_profile['experience_years'] ?? 0} années'),
            _buildInfoRow(Icons.verified, 'Statut', _profile['is_available'] == true ? 'Disponible' : 'Indisponible'),
          ]),

          const SizedBox(height: 24),

          // Tarification
          _buildSection('Tarification', [
            _buildInfoRow(Icons.euro, 'Taux horaire', '${_profile['hourly_rate'] ?? '0'} FCFA'),
            _buildInfoRow(Icons.arrow_upward, 'Prix minimum', '${_profile['min_price'] ?? '0'} FCFA'),
            _buildInfoRow(Icons.arrow_downward, 'Prix maximum', '${_profile['max_price'] ?? '0'} FCFA'),
          ]),

          const SizedBox(height: 24),

          // Localisation
          _buildSection('Localisation', [
            _buildInfoRow(Icons.location_on, 'Adresse', _profile['address'] ?? 'Non spécifiée'),
            _buildInfoRow(Icons.location_city, 'Ville', _profile['city'] ?? 'Non spécifiée'),
            _buildInfoRow(Icons.markunread_mailbox, 'Code postal', _profile['postal_code'] ?? 'Non spécifié'),
            _buildInfoRow(Icons.radar, 'Rayon d\'intervention', '${_profile['radius_km'] ?? '0'} km'),
          ]),

          const SizedBox(height: 24),

          // Compétences
          _buildSkillsSection(),

          const SizedBox(height: 24),

          // Horaires de disponibilité
          _buildBusinessHoursSection(),

          const SizedBox(height: 24),

          // Documents professionnels
          _buildDocumentsSection(),

          const SizedBox(height: 24),

          // Portfolio
          _buildPortfolioSection(),

          const SizedBox(height: 32),

          // Paramètres du compte
          _buildSection('Paramètres du compte', [
            _buildSettingItem(Icons.edit, 'Modifier le profil', () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfessionalProfileEditScreen(
                    token: widget.token,
                    currentProfile: _profile,
                  ),
                ),
              );
              if (result == true) {
                // Recharger le profil si les modifications ont été sauvegardées
                await _loadProfessionalProfile();
              }
            }),
            _buildSettingItem(Icons.notifications, 'Notifications', () {}),
            _buildSettingItem(Icons.lock, 'Sécurité', () {}),
            _buildSettingItem(Icons.help, 'Aide & Support', () {}),
            _buildLogoutItem(),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Méthode utilitaire pour afficher l'avatar par défaut
  Widget _buildDefaultAvatar() {
    return const Icon(
      Icons.business,
      color: Color(0xFFFFCC00),
      size: 40,
    );
  }

  Widget _buildProfileHeader() {
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
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFCC00).withOpacity(0.1),
              border: Border.all(
                color: const Color(0xFFFFCC00),
                width: 3,
              ),
            ),
            child: _profile['profile_photo_base64'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(37),
                    child: Image.memory(
                      base64Decode(_profile['profile_photo_base64'].toString().split(',').last),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('Erreur de chargement de l\'image base64: $error');
                        return _buildDefaultAvatar();
                      },
                    ),
                  )
                : _profile['profile_photo_url'] != null && _profile['profile_photo_url'].toString().isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(37),
                        child: Image.network(
                          _profile['profile_photo_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print('Erreur de chargement de l\'URL: ${_profile['profile_photo_url']}');
                            return _buildDefaultAvatar();
                          },
                        ),
                      )
                : const Icon(
                    Icons.business,
                    color: Color(0xFFFFCC00),
                    size: 40,
                  ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profile['company_name'] ?? 'Entreprise',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _profile['job_title'] ?? 'Métier non spécifié',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: const Color(0xFFFFCC00),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${_profile['rating'] ?? '0'}/5',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.work, size: 16, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      '${_profile['completed_jobs'] ?? '0'} projets',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFCC00).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFFCC00),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection() {
    // Gérer les compétences qui peuvent être dans différents formats
    final skillsData = _profile['skills'];
    List<dynamic> skills = [];

    if (skillsData is List) {
      skills = skillsData;
    } else if (skillsData != null) {
      print('Format inattendu pour skills: ${skillsData.runtimeType}');
      skills = [];
    } else {
      skills = [];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compétences',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        if (skills.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Aucune compétence ajoutée',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
              ),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: skills.map<Widget>((skill) {
              // Gérer les différents formats de compétence
              String skillName = 'Compétence';
              String skillLevel = 'beginner';

              if (skill is Map<String, dynamic>) {
                skillName = skill['name'] ?? 'Compétence';
                skillLevel = skill['level'] ?? 'beginner';
              } else if (skill is Map) {
                skillName = skill['name']?.toString() ?? 'Compétence';
                skillLevel = skill['level']?.toString() ?? 'beginner';
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getSkillLevelColor(skillLevel).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getSkillLevelColor(skillLevel),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getSkillIcon(skillLevel),
                      size: 16,
                      color: _getSkillLevelColor(skillLevel),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      skillName,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _getSkillLevelColor(skillLevel),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getSkillLevelDisplayName(skillLevel),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildBusinessHoursSection() {
    final businessHours = _profile['business_hours'];

    print('=== DEBUG BUSINESS HOURS SECTION ===');
    print('businessHours dans _profile: $businessHours');
    print('businessHours est null: ${businessHours == null}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Horaires de disponibilité',
                style: GoogleFonts.poppins(
                  fontSize: 18, // Taille de police réduite
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis, // Ajout d'une ellipse si le texte est trop long
              ),
            ),
            const SizedBox(width: 8), // Espacement entre le texte et le bouton
            TextButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BusinessHoursEditScreen(
                      token: widget.token,
                      currentHours: _profile['business_hours'],
                    ),
                  ),
                );
                if (result == true) {
                  // Recharger le profil si les horaires ont été mis à jour
                  print('Rafraîchissement du profil après modification des horaires');
                  await _loadProfessionalProfile();
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFFCC00),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Padding réduit
                minimumSize: const Size(0, 36), // Taille minimale réduite
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 16),
                  SizedBox(width: 4),
                  Text('Modifier', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (businessHours == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Column(
              children: [
                Icon(Icons.warning, size: 48, color: Colors.orange[400]),
                const SizedBox(height: 16),
                Text(
                  'Horaires non définis',
                  style: GoogleFonts.poppins(
                    color: Colors.orange[700],
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vos horaires de disponibilité n\'ont pas été correctement sauvegardés. Utilisez le bouton "Modifier" pour les définir.',
                  style: GoogleFonts.poppins(
                    color: Colors.orange[600],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BusinessHoursEditScreen(
                          token: widget.token,
                          currentHours: _profile['business_hours'],
                        ),
                      ),
                    );
                    if (result == true) {
                      await _loadProfessionalProfile();
                    }
                  },
                  icon: const Icon(Icons.schedule),
                  label: const Text('Définir mes horaires'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCC00),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          )
        else
          _buildBusinessHoursList(businessHours),
      ],
    );
  }

  Widget _buildBusinessHoursList(dynamic businessHours) {
    print('=== DEBUG AFFICHAGE HORAIRES ===');
    print('businessHours reçu dans _buildBusinessHoursList: $businessHours');
    print('Type dans _buildBusinessHoursList: ${businessHours?.runtimeType}');
    print('businessHours est null: ${businessHours == null}');
    print('businessHours est vide: ${businessHours?.toString().isEmpty ?? true}');

    Map<String, dynamic> hours;

    try {
      if (businessHours is String && businessHours.isNotEmpty) {
        print('Tentative de parsing depuis String...');
        hours = json.decode(businessHours);
        print('Parsé depuis String: $hours');
      } else if (businessHours is Map) {
        print('Tentative de parsing depuis Map...');
        hours = Map<String, dynamic>.from(businessHours);
        print('Parsé depuis Map: $hours');
      } else {
        print('Format non reconnu, utilisation de Map vide');
        hours = {};
      }
    } catch (e) {
      print('Erreur parsing business_hours: $e');
      hours = {};
    }

    print('Hours finales: $hours');
    print('===============================');

    final dayMapping = {
      'lundi': 'Lundi',
      'mardi': 'Mardi',
      'mercredi': 'Mercredi',
      'jeudi': 'Jeudi',
      'vendredi': 'Vendredi',
      'samedi': 'Samedi',
      'dimanche': 'Dimanche',
    };
    final days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: days.map((day) {
          final dayHours = hours[day] as Map<String, dynamic>? ?? {};
          final open = dayHours['open']?.toString() ?? '';
          final close = dayHours['close']?.toString() ?? '';
          final isOpen = open.isNotEmpty && close.isNotEmpty;

          print('Jour $day: ouvert=$open, fermé=$close, isOpen=$isOpen');

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isOpen ? Colors.green[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isOpen ? Colors.green[200]! : Colors.grey[300]!,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dayMapping[day] ?? day,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: isOpen ? Colors.green[700] : Colors.grey[600],
                  ),
                ),
                Text(
                  isOpen ? '$open - $close' : 'Fermé',
                  style: GoogleFonts.poppins(
                    color: isOpen ? Colors.green[700] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDocumentsSection() {
    // Vérifier s'il y a des documents uploadés
    final hasIdDocument = _profile['id_document_path'] != null && 
                         _profile['id_document_path'].toString().isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documents professionnels',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildDocumentItem(
                Icons.perm_identity,
                'Document d\'identité',
                hasIdDocument ? 'Document uploadé' : 'Aucun document',
                hasIdDocument,
              ),
              const SizedBox(height: 12),
              _buildDocumentItem(
                Icons.business,
                'KBIS / RCCM',
                'Document manquant',
                false,
              ),
              const SizedBox(height: 12),
              _buildDocumentItem(
                Icons.verified,
                'Licence professionnelle',
                'Document manquant',
                false,
              ),
              const SizedBox(height: 12),
              _buildDocumentItem(
                Icons.security,
                'Certificat d\'assurance',
                'Document manquant',
                false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentItem(IconData icon, String title, String status, bool isUploaded) {
    // Try to find a document path/url depending on the kind of document
    String? docPath;
    String? docUrl;

    // Known key for identity document
    if (title.toLowerCase().contains('identité')) {
      docPath = _profile['id_document_path']?.toString();
      docUrl = _profile['id_document_url']?.toString();
    }

    // If path exists but not a full url, build it
    String? builtUrl;
    if (docUrl != null && docUrl.isNotEmpty) {
      builtUrl = docUrl;
    } else if (docPath != null && docPath.isNotEmpty) {
      builtUrl = docPath.startsWith('http') ? docPath : AppConfig.buildMediaUrl(docPath);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUploaded ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUploaded ? Colors.green[200]! : Colors.orange[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isUploaded ? Colors.green[600] : Colors.orange[600],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: isUploaded ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
                Text(
                  status,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isUploaded ? Colors.green[600] : Colors.orange[600],
                  ),
                ),
              ],
            ),
          ),
          if (isUploaded)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'open') {
                  if (builtUrl != null && builtUrl.isNotEmpty) {
                    final uri = Uri.tryParse(builtUrl);
                    if (uri != null) {
                      // Try to open externally
                      try {
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Impossible d\'ouvrir le document')), 
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur lors de l\'ouverture: $e')),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Aucun document disponible à ouvrir')),
                    );
                  }
                } else if (value == 'delete') {
                  // Confirm
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Supprimer le document', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      content: Text('Voulez-vous vraiment supprimer ce document ?', style: GoogleFonts.poppins()),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Annuler', style: GoogleFonts.poppins())),
                        TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Supprimer', style: GoogleFonts.poppins(color: Colors.red))),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    try {
                      final pathToDelete = docPath ?? '';
                      if (pathToDelete.isEmpty) throw Exception('Aucun chemin de document trouvé');
                      final service = DocumentService(widget.token);
                      final res = await service.deleteDocument(pathToDelete);
                      if (res) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document supprimé')));
                        setState(() {
                          // Remove from local profile map
                          if (title.toLowerCase().contains('identité')) {
                            _profile.remove('id_document_path');
                            _profile.remove('id_document_url');
                          }
                        });
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur suppression: $e')));
                    }
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'open', child: Text('Ouvrir')),
                const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: Colors.red))),
              ],
              icon: Icon(Icons.more_vert, color: isUploaded ? Colors.green[600] : Colors.orange[600]),
            )
          else
            Icon(
              isUploaded ? Icons.check_circle : Icons.warning,
              color: isUploaded ? Colors.green[600] : Colors.orange[600],
              size: 20,
            ),
        ],
      ),
    );
  }

  Widget _buildPortfolioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Portfolio',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PortfolioManagementScreen(token: widget.token),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Gérer'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFFCC00),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Gérer vos projets',
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ajoutez et gérez vos réalisations pour les montrer à vos clients',
                style: GoogleFonts.poppins(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PortfolioManagementScreen(token: widget.token),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Gérer mes projets'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCC00),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFFFCC00)),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildLogoutItem() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: Text(
          'Déconnexion',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.red,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
        onTap: () => _handleLogout(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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

  String _getSkillLevelDisplayName(String level) {
    switch (level.toLowerCase()) {
      case 'expert':
        return 'Expert';
      case 'advanced':
        return 'Avancé';
      case 'intermediate':
        return 'Intermédiaire';
      case 'beginner':
        return 'Débutant';
      default:
        return 'Non défini';
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Déconnexion',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Annuler',
              style: GoogleFonts.poppins(),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Déconnexion',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Vider toutes les préférences

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/onboarding-role',
          (route) => false,
        );
      }
    }
  }
}
