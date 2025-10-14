import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

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

      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/professional/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          // La structure contient "data" qui contient un tableau de profils
          final profileData = data['data'];

          if (profileData['data'] != null && (profileData['data'] as List).isNotEmpty) {
            // IMPORTANT: Vérifier que nous récupérons le profil de l'utilisateur connecté
            // Pour l'instant, prendre le premier profil (mais cela devrait être corrigé côté API)
            final profile = profileData['data'][0];

            // Vérification de sécurité : s'assurer que c'est bien notre profil
            // En production, l'API devrait retourner uniquement le profil de l'utilisateur connecté
            print('ID du profil récupéré: ${profile['id']}');

            setState(() {
              _profile = Map<String, dynamic>.from(profile);
            });
          } else {
            setState(() {
              _error = 'Aucun profil professionnel trouvé pour votre compte';
            });
          }
        } else {
          setState(() {
            _error = 'Format de réponse inattendu de l\'API';
          });
        }
      } else {
        setState(() {
          _error = 'Erreur serveur: ${response.statusCode} - ${response.body}';
        });
      }
    } catch (e) {
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
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4CAF50)),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
            icon: const Icon(Icons.refresh, color: Color(0xFF4CAF50)),
            onPressed: _loadProfessionalProfile,
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
              onPressed: _loadProfessionalProfile,
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

          // Portfolio
          _buildPortfolioSection(),

          const SizedBox(height: 32),

          // Paramètres du compte
          _buildSection('Paramètres du compte', [
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
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              border: Border.all(
                color: const Color(0xFF4CAF50),
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.business,
              color: Color(0xFF4CAF50),
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
                    color: const Color(0xFF4CAF50),
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
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF4CAF50),
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
    final skills = _profile['skills'] as List<dynamic>? ?? [];

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
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getSkillLevelColor(skill['level'] ?? 'beginner').withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getSkillLevelColor(skill['level'] ?? 'beginner'),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getSkillIcon(skill['level'] ?? 'beginner'),
                      size: 16,
                      color: _getSkillLevelColor(skill['level'] ?? 'beginner'),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      skill['name'] ?? 'Compétence',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _getSkillLevelColor(skill['level'] ?? 'beginner'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${skill['experience_years'] ?? 0} ans',
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

  Widget _buildPortfolioSection() {
    final portfolios = _profile['portfolios'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Portfolio',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        if (portfolios.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucun projet dans le portfolio',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ajoutez vos réalisations pour les montrer à vos clients',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          // TODO: Afficher les projets du portfolio quand ils seront disponibles
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${portfolios.length} projet(s) dans le portfolio',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
              ),
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
        leading: Icon(icon, color: const Color(0xFF4CAF50)),
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
