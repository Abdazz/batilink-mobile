import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Pour SocketException
import 'package:batilink_mobile_app/core/app_config.dart';
import 'package:batilink_mobile_app/utils/error_handler.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/auth_service.dart';
import 'client_dashboard_screen.dart';
import 'professional_search_screen.dart';
import 'client_completed_quotations_screen.dart';
import 'client_edit_profile_screen.dart';

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
    final tokenFromPrefs = prefs.getString('token') ?? '';

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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Vérifier d'abord la connexion Internet
    final hasConnection = await ErrorHandler.checkInternetConnection();
    if (!hasConnection) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Pas de connexion Internet';
      });
      return;
    }

    final token = _token;
    if (token.isEmpty) {
      await ErrorHandler.handleNetworkError(
        Exception('Token manquant'),
        StackTrace.current,
        customMessage: 'Session expirée. Veuillez vous reconnecter.',
      );
      setState(() {
        _isLoading = false;
        _errorMessage = 'Session expirée';
      });
      return;
    }

    print('=== DEBUG PROFIL CLIENT ===');
    print('Token utilisé: ${token.substring(0, 20)}...');
    print('Données utilisateur reçues lors du login: ${widget.userData}');

    try {
      final authService = AuthService(baseUrl: AppConfig.baseUrl);
      final response = await authService.getClientProfile(accessToken: token);
      
      print('=== DEBUG: Réponse complète du serveur ===');
      print('Status: ${response.statusCode}');
      print('Headers: ${response.headers}');
      print('Body: ${response.body}');
      print('======================================');

      if (response.statusCode != 200) {
        print('Échec API - Status: ${response.statusCode}');
        print('Corps de l\'erreur: ${response.body}');
        
        String errorMessage = 'Erreur lors de la récupération du profil';
        
        if (response.statusCode == 401) {
          errorMessage = 'Session expirée. Veuillez vous reconnecter.';
        } else if (response.statusCode >= 500) {
          errorMessage = 'Erreur serveur. Veuillez réessayer plus tard.';
        }
        
        await ErrorHandler.handleNetworkError(
          Exception('Erreur HTTP ${response.statusCode}'),
          StackTrace.current,
          customMessage: errorMessage,
        );
        
        setState(() {
          _errorMessage = errorMessage;
          _isLoading = false;
        });
        return;
      }

      try {
        final data = json.decode(response.body);
        print('Données décodées: $data');
        print('Type des données: ${data.runtimeType}');

        // Vérification de la structure de la réponse
        if (data is! Map<String, dynamic>) {
          throw FormatException('La réponse du serveur n\'est pas un objet JSON valide');
        }

        print('Clés disponibles dans la réponse: ${data.keys.toList()}');

        if (!data.containsKey('data') || data['data'] is! Map) {
          throw FormatException('Données de réponse manquantes ou invalides');
        }

        final responseData = data['data'] as Map<String, dynamic>;
        print('Données de réponse trouvées: $responseData');

        if (!responseData.containsKey('user') || responseData['user'] is! Map) {
          throw FormatException('Données utilisateur manquantes dans la réponse');
        }

        // Extraire les données utilisateur
        final userData = Map<String, dynamic>.from(responseData['user'] as Map);
        print('Données utilisateur extraites: $userData');
        
        // Récupérer les données existantes
        final existingData = Map<String, dynamic>.from(widget.userData);
        final newData = Map<String, dynamic>.from(userData);
        
        // Log des données d'avatar pour le débogage
        print('=== DEBUG: Données d\'avatar ===');
        print('Avatar existant: ${existingData['avatar']}');
        print('Nouvel avatar: ${newData['avatar']}');
        
        // Conserver l'avatar existant s'il n'est pas dans les nouvelles données
        if (existingData['avatar'] != null && 
            (newData['avatar'] == null || newData['avatar'] == 'null' || newData['avatar'].toString().isEmpty)) {
          newData['avatar'] = existingData['avatar'];
          print('Conservation de l\'avatar existant: ${newData['avatar']}');
        } else if (newData['avatar'] != null && newData['avatar'].toString().isNotEmpty) {
          print('Utilisation du nouvel avatar: ${newData['avatar']}');
        } else {
          print('Aucun avatar disponible');
        }
        
        // Mettre à jour les statistiques si elles sont disponibles
        if (responseData.containsKey('stats') && responseData['stats'] is Map) {
          final stats = Map<String, dynamic>.from(responseData['stats'] as Map);
          if (mounted) {
            setState(() {
              _totalJobs = stats['total_jobs'] is int ? stats['total_jobs'] : 0;
              _totalFavorites = stats['total_favorites'] is int ? stats['total_favorites'] : 0;
              _totalReviews = stats['total_reviews'] is int ? stats['total_reviews'] : 0;
            });
            print('Statistiques mises à jour: jobs=$_totalJobs, favorites=$_totalFavorites, reviews=$_totalReviews');
          }
        } else {
          // Si les statistiques ne sont pas dans la réponse du profil, essayer de les récupérer séparément
          _loadClientStats();
        }

        // Mettre à jour l'état avec les nouvelles données
        if (mounted) {
          setState(() {
            _userData = newData;
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Erreur lors du traitement de la réponse: $e');
        _showError('Erreur lors du traitement des données du profil: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e, stackTrace) {
      print('Exception lors du chargement du profil: $e');
      
      // Gestion des erreurs réseau spécifiques
      String errorMessage = 'Erreur lors du chargement du profil';
      
      if (e is SocketException) {
        errorMessage = 'Impossible de se connecter au serveur. Vérifiez votre connexion Internet.';
      } else if (e is TimeoutException) {
        errorMessage = 'La connexion a expiré. Veuillez réessayer.';
      }
      
      await ErrorHandler.handleNetworkError(e, stackTrace);
      
      setState(() {
        _errorMessage = errorMessage;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadClientStats() async {
    try {
      final token = _token;
      if (token.isEmpty) return;

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/client/stats'),
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
      try {
        // Supprimer toutes les données locales
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Rediriger vers l'écran de sélection de rôle
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/onboarding-role',
            (route) => false,
          );
        }
      } catch (e) {
        print('Erreur lors de la déconnexion: $e');
        // En cas d'erreur, rediriger quand même vers l'écran de connexion
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
                  child: _userData?['avatar'] != null && _userData!['avatar'].toString().isNotEmpty
                      ? ClipOval(
                          child: _buildAvatarImage(_userData!),
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

  Widget _buildAvatarImage(Map<String, dynamic> userData) {
    String? avatarUrl = userData['avatar']?.toString() ?? userData['profile_photo_url']?.toString();
    
    // Si pas d'URL d'avatar, on affiche l'avatar par défaut
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return _buildDefaultAvatar(userData);
    }

    // Corriger l'URL si elle utilise localhost
    avatarUrl = AppConfig.fixAvatarUrl(avatarUrl);

    // Ajouter un paramètre de cache busting si ce n'est pas déjà fait
    if (!avatarUrl.contains('?t=')) {
      avatarUrl = '$avatarUrl${avatarUrl.contains('?') ? '&' : '?'}t=${DateTime.now().millisecondsSinceEpoch}';
    }

    // Récupérer les initiales pour le fallback
    final firstName = userData['first_name']?.toString() ?? '';
    final lastName = userData['last_name']?.toString() ?? '';
    final initials = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';
    
    print('Chargement de l\'avatar depuis: $avatarUrl');
    
    // Utiliser CachedNetworkImage pour une meilleure gestion du cache et du chargement
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildDefaultAvatar(userData),
        errorWidget: (context, url, error) {
          print('Erreur de chargement de l\'avatar: $error');
          print('URL de l\'avatar: $url');
          // Si l'URL contient localhost, essayer de la corriger et de recharger
          if (url.contains('localhost')) {
            final fixedUrl = AppConfig.fixAvatarUrl(url);
            if (fixedUrl != url) {
              print('Tentative de rechargement avec l\'URL corrigée: $fixedUrl');
              return CachedNetworkImage(
                imageUrl: fixedUrl,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                placeholder: (context, _) => _buildDefaultAvatar(userData),
                errorWidget: (context, _, __) => _buildDefaultAvatar(userData),
              );
            }
          }
          return _buildDefaultAvatar(userData);
        },
        httpHeaders: const {
          'Accept': 'image/*',
        },
        memCacheWidth: 200,
        memCacheHeight: 200,
        maxHeightDiskCache: 200,
        maxWidthDiskCache: 200,
      ),
    );
  }

  Widget _buildDefaultAvatar(Map<String, dynamic> userData) {
    final firstName = userData['first_name']?.toString() ?? '';
    final lastName = userData['last_name']?.toString() ?? '';
    final initials = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
        .toUpperCase();
    
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF7F9CF5).withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials.isNotEmpty ? initials : 'U',
          style: const TextStyle(
            color: Color(0xFF4F46E5),
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
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
          onTap: () async {
            final updatedUserData = await Navigator.push<Map<String, dynamic>>(
              context,
              MaterialPageRoute(
                builder: (context) => ClientEditProfileScreen(
                  token: widget.token,
                  userData: Map<String, dynamic>.from(widget.userData),
                ),
              ),
            );
            
            // Mettre à jour les données utilisateur si des modifications ont été apportées
            if (updatedUserData != null && mounted) {
              setState(() {
                _userData = updatedUserData;
              });
              // Forcer le rechargement du profil pour s'assurer que tout est à jour
              _loadUserProfile();
            }
          },
        ),
        const SizedBox(height: 8),
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
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _buildStatItem(_totalJobs.toString(), 'Devis'),
            ),
            Container(
              height: 40,
              width: 1,
              color: Colors.grey[300],
            ),
            Expanded(
              child: _buildStatItem(_totalFavorites.toString(), 'Favoris'),
            ),
            Container(
              height: 40,
              width: 1,
              color: Colors.grey[300],
            ),
            Expanded(
              child: _buildStatItem(_totalReviews.toString(), 'Terminés'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFFCC00),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
