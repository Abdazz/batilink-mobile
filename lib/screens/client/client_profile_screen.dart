import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/auth_service.dart';
import 'client_dashboard_screen.dart';
import 'professional_search_screen.dart';
import 'client_completed_quotations_screen.dart';

class ClientProfileScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> userData;

  const ClientProfileScreen({
    Key? key,
    required this.token,
    required this.userData,
  }) : super(key: key);

  @override
  _ClientProfileScreenState createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  int _selectedIndex = 3; // Index pour l'onglet Profil
  String? _errorMessage;
  String _token = '';

  // Statistiques du client
  int _totalJobs = 0;
  int _totalFavorites = 0;
  int _totalReviews = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Récupérer le token depuis SharedPreferences comme secours
    final prefs = await SharedPreferences.getInstance();
    final tokenFromPrefs = prefs.getString('access_token') ?? '';

    // Utiliser le token passé en argument, ou celui de SharedPreferences comme secours
    final finalToken = widget.token.isNotEmpty ? widget.token : tokenFromPrefs;

    if (finalToken.isEmpty) {
      _showError('Token d\'authentification manquant. Veuillez vous reconnecter.');
      return;
    }

    // Mettre à jour le token du widget
    setState(() {
      _token = finalToken;
    });

    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final token = _token; // Utiliser le token récupéré depuis SharedPreferences
      final authService = AuthService(baseUrl: 'http://10.0.2.2:8000');

      if (token.isEmpty) {
        _showError('Token d\'authentification manquant');
        return;
      }

      print('=== DEBUG PROFIL CLIENT ===');
      print('Token utilisé: ${token.substring(0, 20)}...');
      print('Données utilisateur reçues lors du login: ${widget.userData}');

      final response = await authService.getClientProfile(accessToken: token);

      print('Réponse reçue - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Données décodées: $data');
        print('Type des données: ${data.runtimeType}');

        // Vérification de la structure de la réponse
        if (data is Map<String, dynamic>) {
          print('Clés disponibles dans la réponse: ${data.keys.toList()}');

          if (data.containsKey('data')) {
            final responseData = data['data'];
            print('Données de réponse trouvées: $responseData');
            print('Type des données de réponse: ${responseData.runtimeType}');

            if (responseData is Map<String, dynamic>) {
              print('Clés dans responseData: ${responseData.keys.toList()}');

              // Extraire les données utilisateur depuis le champ 'user'
              if (responseData.containsKey('user')) {
                final userData = responseData['user'];
                print('Données utilisateur extraites: $userData');
                print('Type des données utilisateur: ${userData.runtimeType}');

                if (userData is Map<String, dynamic>) {
                  print('Clés utilisateur: ${userData.keys.toList()}');

                  setState(() {
                    _userData = userData;
                    _isLoading = false;
                  });

                  print('Profil utilisateur chargé avec succès: ${_userData?['first_name']} ${_userData?['last_name']} - ${_userData?['email']}');

                  // Mettre à jour les statistiques si elles sont disponibles dans responseData
                  if (responseData.containsKey('stats')) {
                    final stats = responseData['stats'];
                    if (stats is Map<String, dynamic>) {
                      setState(() {
                        _totalJobs = stats['total_jobs'] ?? 0;
                        _totalFavorites = stats['total_favorites'] ?? 0;
                        _totalReviews = stats['total_reviews'] ?? 0;
                      });
                      print('Statistiques mises à jour: jobs=$_totalJobs, favorites=$_totalFavorites, reviews=$_totalReviews');
                    }
                  } else {
                    // Si les statistiques ne sont pas dans la réponse du profil, essayer de les récupérer séparément
                    _loadClientStats();
                  }

                  return;
                } else {
                  print('ERREUR: responseData["user"] n\'est pas un Map');
                }
              } else {
                print('ERREUR: Clé "user" manquante dans responseData');
              }
            } else {
              print('ERREUR: data["data"] n\'est pas un Map');
            }
          } else {
            print('ERREUR: Clé "data" manquante dans la réponse');
          }
        } else {
          print('ERREUR: Réponse n\'est pas un Map');
        }

        // Si on arrive ici, c'est qu'il y a un problème avec la structure
        print('Problème avec la structure de la réponse API');
        _showError('Format de réponse inattendu du serveur');
        return;
      } else {
        print('Échec API - Status: ${response.statusCode}');
        print('Corps de l\'erreur: ${response.body}');
        // Afficher une erreur au lieu d'utiliser des données de test
        setState(() {
          _errorMessage = 'Erreur lors de la récupération du profil (${response.statusCode})';
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      print('Exception lors du chargement du profil: $e');
      // Afficher une erreur au lieu d'utiliser des données de test
      setState(() {
        _errorMessage = 'Erreur de connexion lors du chargement du profil';
        _isLoading = false;
      });
      return;
    }
  }

  Future<void> _loadClientStats() async {
    try {
      final token = _token;
      if (token.isEmpty) return;

      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/client/stats'),
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
            setState(() {
              _totalJobs = stats['total_jobs'] ?? 0;
              _totalFavorites = stats['total_favorites'] ?? 0;
              _totalReviews = stats['total_reviews'] ?? 0;
            });
            print('Statistiques client récupérées: jobs=$_totalJobs, favorites=$_totalFavorites, reviews=$_totalReviews');
          }
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des statistiques: $e');
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

  void _onNavigationTap(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0: // Accueil
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClientDashboardScreen(
              token: widget.token,
              userData: widget.userData,
              profile: {},
            ),
          ),
        );
        break;
      case 1: // Recherche
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProfessionalSearchScreen(
              token: widget.token,
              userData: widget.userData,
            ),
          ),
        );
        break;
      case 2: // Mes devis
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClientCompletedQuotationsScreen(
              token: widget.token,
              userData: widget.userData,
            ),
          ),
        );
        break;
      case 3: // Profil (page actuelle)
        break;
    }
  }

  Future<void> _logout() async {
    try {
      // Supprimer toutes les données locales (comme dans le profil professionnel)
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Vider toutes les préférences

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/onboarding-role',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la déconnexion'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mon Profil',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFFFCC00),
        elevation: 0,
        // Enlever le bouton retour
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFFCC00),
              ),
            )
          : _userData == null
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
                        _errorMessage ?? 'Erreur lors du chargement du profil',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUserProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFCC00),
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
                      // Section Informations personnelles
                      _buildSectionTitle('Informations personnelles'),
                      const SizedBox(height: 12),
                      _buildInfoCard(),

                      const SizedBox(height: 24),

                      // Section Actions rapides
                      _buildSectionTitle('Actions rapides'),
                      const SizedBox(height: 12),
                      _buildActionButtons(),

                      const SizedBox(height: 24),

                      // Section Statistiques (optionnel)
                      _buildSectionTitle('Activité'),
                      const SizedBox(height: 12),
                      _buildStatsCard(),

                      const SizedBox(height: 32),

                      // Bouton de déconnexion (en bas)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: Text(
                            'Déconnexion',
                            style: GoogleFonts.poppins(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavigationTap,
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFFFCC00),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Avatar et nom
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                    border: Border.all(
                      color: const Color(0xFFFFCC00),
                      width: 2,
                    ),
                  ),
                  child: _userData?['avatar'] != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: _userData!['avatar'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const CircularProgressIndicator(),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.person,
                              color: Color(0xFFFFCC00),
                              size: 30,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.person,
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
                        '${_userData?['first_name'] ?? ''} ${_userData?['last_name'] ?? ''}'.trim(),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _userData?['email'] ?? '',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      if (_userData?['phone'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _userData!['phone'],
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Informations détaillées
            _buildInfoRow('Rôle', _getRoleDisplayName(_userData?['role'])),
            if (_userData?['created_at'] != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow('Membre depuis', _formatDate(_userData!['created_at'])),
            ],
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
          width: 100,
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
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildActionButton(
          icon: Icons.request_quote,
          title: 'Mes demandes de devis',
          subtitle: 'Voir toutes vos demandes et leurs réponses',
          onTap: () => Navigator.pushNamed(
            context,
            '/client/quotations',
            arguments: {
              'token': widget.token,
              'userData': widget.userData,
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          icon: Icons.favorite,
          title: 'Mes professionnels favoris',
          subtitle: 'Accéder rapidement à vos professionnels préférés',
          onTap: () => Navigator.pushNamed(
            context,
            '/client/favorites',
            arguments: {
              'token': widget.token,
              'userData': widget.userData,
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          icon: Icons.settings,
          title: 'Paramètres du profil',
          subtitle: 'Modifier vos informations personnelles',
          onTap: () => Navigator.pushNamed(
            context,
            '/client/profile/edit',
            arguments: {
              'token': widget.token,
              'userData': widget.userData,
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCC00).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFFFCC00),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey,
                size: 16,
              ),
            ],
          ),
        ),
      ),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(_totalJobs.toString(), 'Devis envoyés'),
            _buildStatItem(_totalFavorites.toString(), 'Professionnels favoris'),
            _buildStatItem(_totalReviews.toString(), 'Projets terminés'),
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
            color: const Color(0xFFFFCC00),
          ),
        ),
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

  String _getRoleDisplayName(String? role) {
    switch (role) {
      case 'client':
        return 'Client';
      case 'professional':
        return 'Professionnel';
      default:
        return role ?? 'Utilisateur';
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }
}
