import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../core/app_config.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'professional_detail_screen.dart';

class ClientFavoritesScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> userData;

  const ClientFavoritesScreen({
    Key? key,
    required this.token,
    required this.userData,
  }) : super(key: key);

  @override
  _ClientFavoritesScreenState createState() => _ClientFavoritesScreenState();
}

class _ClientFavoritesScreenState extends State<ClientFavoritesScreen> {
  List<dynamic> _favorites = [];
  bool _isLoading = true;
  String _token = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Récupérer le token depuis SharedPreferences comme secours
    final prefs = await SharedPreferences.getInstance();
    final tokenFromPrefs = prefs.getString('token') ?? '';

    print('=== DEBUG INITIALIZATION ===');
    print('Token depuis widget: ${widget.token.isNotEmpty ? 'présent' : 'vide'}');
    print('Token depuis prefs: ${tokenFromPrefs.isNotEmpty ? tokenFromPrefs.substring(0, 20) + '...' : 'VIDE'}');

    // Utiliser le token passé en argument s'il n'est pas vide, sinon utiliser celui de SharedPreferences
    final finalToken = widget.token.isNotEmpty ? widget.token : tokenFromPrefs;

    if (finalToken.isEmpty) {
      _showError('Token d\'authentification manquant. Veuillez vous reconnecter.');
      return;
    }

    print('Token final utilisé: ${finalToken.substring(0, 20)}...');

    setState(() {
      _token = finalToken;
    });

    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      print('=== DEBUG FAVORITES ===');
      print('Token utilisé: ${_token.isNotEmpty ? _token.substring(0, 20) + '...' : 'VIDE'}');

      if (_token.isEmpty) {
        _showError('Token d\'authentification manquant');
        return;
      }

      print('URL appelée: ${AppConfig.baseUrl}/api/favorites/professionals');

      final data = await ApiService.get('favorites/professionals');

      print('Données reçues: $data');
      print('Type de data: ${data.runtimeType}');

      if (data is Map<String, dynamic>) {
        print('Clés disponibles: ${data.keys.toList()}');
        final favoritesData = data['data'];
        print('Données favoris: $favoritesData');
        print('Type des données favoris: ${favoritesData.runtimeType}');

        setState(() {
          _favorites = data['data'] ?? [];
          _isLoading = false;
        });
        print('Nombre de favoris chargés: ${_favorites.length}');
      } else {
        _showError('Format de réponse inattendu');
      }
    } catch (e) {
      print('Exception lors du chargement des favoris: $e');
      _showError('Erreur de connexion: $e');
    }
  }

  Future<void> _removeFromFavorites(String professionalId) async {
    try {
      if (_token.isEmpty) {
        _showError('Token d\'authentification manquant');
        return;
      }

      final response = await ApiService.post(
        'favorites/professionals/toggle',
        data: {
          'professional_id': professionalId,
        },
      );

      if (response['success'] == true) {
        setState(() {
          _favorites.removeWhere((fav) => fav['id'] == professionalId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Retiré des favoris'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showError('Erreur lors de la suppression');
      }
    } catch (e) {
      _showError('Erreur de connexion');
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


  Widget _getProfessionalPhoto(Map<String, dynamic> professional) {
    // Essaie d'extraire l'URL de la photo depuis différentes sources possibles
    String? avatarUrl;

    // Essaie profile_photo.url d'abord (nouvelle structure)
    if (professional['profile_photo'] is Map<String, dynamic>) {
      avatarUrl = professional['profile_photo']['url'];
    }

    // Essaie avatar_url ensuite (ancienne structure)
    if (avatarUrl == null || avatarUrl.isEmpty) {
      avatarUrl = professional['avatar_url'];
    }

    // Essaie user.profile_photo_url
    if (avatarUrl == null || avatarUrl.isEmpty) {
      avatarUrl = professional['user']?['profile_photo_url'];
    }

    // Construit l'URL complète Laravel si nécessaire
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (!avatarUrl.startsWith('http://') && !avatarUrl.startsWith('https://')) {
        if (avatarUrl.startsWith('/storage/') || avatarUrl.startsWith('storage/')) {
          avatarUrl = AppConfig.buildMediaUrl(avatarUrl.startsWith('/') ? avatarUrl : '/$avatarUrl');
        }
      }
    }

    return avatarUrl != null && avatarUrl.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: avatarUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: Center(
                  child: Text(
                    professional['company_name']?[0]?.toUpperCase() ?? 'N',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFCC00),
                      fontWeight: FontWeight.w600,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
            ),
          )
        : Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: Center(
              child: Text(
                professional['company_name']?[0]?.toUpperCase() ?? 'N',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFFCC00),
                  fontWeight: FontWeight.w600,
                  fontSize: 24,
                ),
              ),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mes professionnels favoris',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFFFCC00),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: const Color(0xFF4CAF50),
              ),
            )
          : _favorites.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  color: const Color(0xFFFFCC00),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _favorites.length,
                    itemBuilder: (context, index) {
                      final favorite = _favorites[index];
                      return _buildFavoriteCard(favorite);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun professionnel favori',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vous n\'avez pas encore ajouté de professionnels à vos favoris',
            style: GoogleFonts.poppins(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/client/search',
                (route) => false,
              );
            },
            icon: const Icon(Icons.search),
            label: Text(
              'Découvrir des professionnels',
              style: GoogleFonts.poppins(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFCC00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(dynamic favorite) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Naviguer vers les détails du professionnel
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfessionalDetailScreen(
                professionalId: favorite['id'],
                token: widget.token,
                userData: widget.userData,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Photo de profil
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: _getProfessionalPhoto(favorite),
              ),

              const SizedBox(width: 16),

              // Informations du professionnel
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      favorite['company_name'] ?? 'N/A',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      favorite['job_title'] ?? 'N/A',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        RatingBarIndicator(
                          rating: (favorite['rating'] as num?)?.toDouble() ?? 0,
                          itemBuilder: (context, _) => const Icon(
                            Icons.star,
                            color: Colors.amber,
                          ),
                          itemCount: 5,
                          itemSize: 16,
                          direction: Axis.horizontal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${favorite['review_count'] ?? 0})',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          favorite['city'] ?? 'Localisation inconnue',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bouton supprimer des favoris
              IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                onPressed: () => _removeFromFavorites(favorite['id']),
                tooltip: 'Retirer des favoris',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
