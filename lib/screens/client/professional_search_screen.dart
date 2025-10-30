import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
// Import removed as it's no longer needed
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/professional.dart';
import 'professional_detail_screen.dart';
import '../../services/api_service.dart';
import 'client_dashboard_screen.dart';
import 'client_completed_quotations_screen.dart';
import 'client_profile_screen.dart';

class ProfessionalSearchScreen extends StatefulWidget {
  final String? token;
  final Map<String, dynamic>? userData;

  const ProfessionalSearchScreen({
    Key? key,
    this.token,
    this.userData,
  }) : super(key: key);

  @override
  _ProfessionalSearchScreenState createState() => _ProfessionalSearchScreenState();
}

class _ProfessionalSearchScreenState extends State<ProfessionalSearchScreen> {
  int _selectedIndex = 1; // Index 1 pour l'onglet de recherche

  // Variable pour stocker le rôle détecté
  bool _isProClient = false;
  bool _isRoleDetectionComplete = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadProfessionals();
    _detectUserRole();
  }

  // Détecter le rôle de l'utilisateur de manière asynchrone
  Future<void> _detectUserRole() async {
    print('=== DEBUG DÉTECTION RÔLE (DÉBUT) ===');
    print('widget.userData: ${widget.userData}');
    print('widget.token: ${widget.token}');
    print('_isProClient avant détection: $_isProClient');
    print('_isRoleDetectionComplete avant détection: $_isRoleDetectionComplete');

    try {
      // D'abord essayer les données passées en argument
      final userData = widget.userData;
      
      // Vérifier si userData est null
      if (userData == null) {
        print('userData est null');
      } else {
        print('userData contient les clés: ${userData.keys}');
      }
      print('userData reçu: $userData');

      bool isPro = _isProClient; // Conserver la valeur actuelle par défaut
      
      if (userData != null && userData.isNotEmpty) {
        print('userData n\'est pas vide, vérification...');

        // Vérifier si le rôle est directement dans userData
        if (userData.containsKey('role')) {
          print('Rôle trouvé dans userData: ${userData['role']}');
          if (userData['role'] == 'pro_client') {
            print('Rôle pro_client détecté directement dans userData');
            isPro = true;
          } else {
            print('Rôle différent de pro_client: ${userData['role']}');
            isPro = false;
          }
        } 
        // Vérifier la structure imbriquée data.user.role
        else if (userData.containsKey('data') && 
                 userData['data'] is Map &&
                 userData['data'].containsKey('user') &&
                 userData['data']['user'] is Map &&
                 userData['data']['user'].containsKey('role')) {
          final role = userData['data']['user']['role'];
          print('Rôle trouvé dans userData.data.user: $role');
          if (role == 'pro_client') {
            print('Rôle pro_client détecté dans userData.data.user.role');
            isPro = true;
          } else {
            print('Rôle différent de pro_client: $role');
            isPro = false;
          }
        }
        // Vérifier la structure imbriquée user.role
        else if (userData.containsKey('user') && 
                 userData['user'] is Map && 
                 userData['user'].containsKey('role')) {
          final role = userData['user']['role'];
          print('Rôle trouvé dans userData.user: $role');
          if (role == 'pro_client') {
            print('Rôle pro_client détecté dans userData.user.role');
            isPro = true;
          } else {
            print('Rôle différent de pro_client: $role');
            isPro = false;
          }
        } else {
          print('Aucun rôle trouvé dans les données utilisateur');
          isPro = false;
        }
      } else {
        print('userData est vide ou null, vérification dans SharedPreferences...');
        // Essayer de récupérer depuis SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          final userDataString = prefs.getString('user_data');
          
          if (userDataString != null && userDataString.isNotEmpty) {
            final userDataPrefs = json.decode(userDataString) as Map<String, dynamic>;
            print('Données utilisateur depuis SharedPreferences: $userDataPrefs');
            
            // Vérifier le rôle dans les données du SharedPreferences
            if (userDataPrefs.containsKey('role') && userDataPrefs['role'] == 'pro_client') {
              print('Rôle pro_client détecté dans SharedPreferences');
              isPro = true;
            } 
            // Vérifier la structure imbriquée user.role
            else if (userDataPrefs.containsKey('user') && 
                     userDataPrefs['user'] is Map && 
                     (userDataPrefs['user'] as Map).containsKey('role') &&
                     userDataPrefs['user']['role'] == 'pro_client') {
              print('Rôle pro_client détecté dans SharedPreferences.user.role');
              isPro = true;
            }
            // Vérifier la structure imbriquée data.user.role
            else if (userDataPrefs.containsKey('data') && 
                     userDataPrefs['data'] is Map &&
                     (userDataPrefs['data'] as Map).containsKey('user') &&
                     userDataPrefs['data']['user'] is Map &&
                     (userDataPrefs['data']['user'] as Map).containsKey('role') &&
                     userDataPrefs['data']['user']['role'] == 'pro_client') {
              print('Rôle pro_client détecté dans SharedPreferences.data.user.role');
              isPro = true;
            } else {
              print('Aucun rôle pro_client trouvé dans les données de SharedPreferences');
              isPro = false;
            }
          } else {
            print('Aucune donnée utilisateur trouvée dans SharedPreferences');
            isPro = false;
          }
        } catch (e) {
          print('Erreur lors de la lecture des données utilisateur depuis SharedPreferences: $e');
          isPro = false;
        }
      }

      // Mettre à jour l'état une seule fois
      if (mounted) {
        print('Mise à jour de l\'état:');
        print('  Ancienne valeur _isProClient: $_isProClient');
        print('  Nouvelle valeur _isProClient: $isPro');
        print('  _isRoleDetectionComplete: true');
        
        setState(() {
          _isProClient = isPro;
          _isRoleDetectionComplete = true;
        });
        
        // Vérifier les valeurs après le setState
        WidgetsBinding.instance.addPostFrameCallback((_) {
          print('=== APRÈS SETSTATE ===');
          print('_isProClient après setState: $_isProClient');
          print('_isRoleDetectionComplete après setState: $_isRoleDetectionComplete');
          
          // Forcer un rebuild après la détection du rôle
          if (mounted) {
            setState(() {});
          }
        });
      } else {
        print('Widget non monté, impossible de mettre à jour l\'état');
      }
    } catch (e) {
      print('Erreur lors de la détection du rôle: $e');
      if (mounted) {
        setState(() {
          _isProClient = false;
          _isRoleDetectionComplete = true;
        });
      }
    }
    
    print('=== FIN DÉTECTION RÔLE ===');
    print('_isProClient: $_isProClient');
    print('_isRoleDetectionComplete: $_isRoleDetectionComplete');
    print('Stack trace:');
    print(StackTrace.current.toString().split('\n').take(5).join('\n'));
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    print('=== DEBUG NAVIGATION ===');
    print('Index cliqué: $index');
    print('Index actuel: $_selectedIndex');
    print('_isProClient: $_isProClient');
    print('_isRoleDetectionComplete: $_isRoleDetectionComplete');
    
    // Si la détection du rôle n'est pas terminée, ne pas naviguer
    if (!_isRoleDetectionComplete) {
      print('Détection du rôle en cours, navigation différée');
      return;
    }

    // Mettre à jour l'index sélectionné
    setState(() {
      _selectedIndex = index;
    });

    // Pour les pro-clients, ne pas naviguer automatiquement depuis l'écran de recherche
    // La navigation se fera uniquement si l'utilisateur clique sur un autre onglet
    if (_isProClient) {
      print('Navigation pour pro-client');
      if (index != 1) { // Ne pas naviguer si on est déjà sur la recherche (index 1)
        _navigateForProClient(index);
      }
    } else {
      print('Navigation pour client');
      _navigateForClient(index);
    }
  }

  void _navigateForProClient(int index) {
    print('=== NAVIGATION PRO CLIENT ===');
    print('Index de navigation: $index');
    
    // Toujours forcer l'index 1 (Recherche) à rester sur cette page
    if (index == 1) {
      print('Déjà sur la page de recherche');
      return;
    }

    // Pour les autres onglets, naviguer vers le dashboard avec l'onglet approprié
    final tabIndex = index == 0 ? 0 : index - 1; // Ajuster l'index pour le dashboard
    print('Navigation vers le dashboard avec l\'onglet: $tabIndex');
    
    Navigator.pushReplacementNamed(
      context,
      '/pro-client/dashboard',
      arguments: {
        'token': widget.token ?? '',
        'userData': widget.userData ?? <String, dynamic>{},
        'initialTab': tabIndex,
      },
    );
  }

  void _navigateForClient(int index) {
    print('=== NAVIGATION CLIENT STANDARD ===');
    print('Index de navigation: $index');
    
    // Si on est déjà sur la page de recherche (index 1), ne rien faire
    if (index == 1) {
      print('Déjà sur la page de recherche');
      return;
    }

    switch (index) {
      case 0: // Tableau de bord
        print('Navigation vers le tableau de bord client');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClientDashboardScreen(
              token: widget.token ?? '',
              userData: widget.userData ?? <String, dynamic>{},
              profile: {},
            ),
          ),
        );
        break;
        
      case 2: // Mes devis
        print('Navigation vers les devis du client');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClientCompletedQuotationsScreen(
              token: widget.token ?? '',
              userData: widget.userData ?? <String, dynamic>{},
            ),
          ),
        );
        break;
        
      case 3: // Profil
        print('Navigation vers le profil client');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClientProfileScreen(
              token: widget.token ?? '',
              userData: widget.userData ?? <String, dynamic>{},
            ),
          ),
        );
        break;
    }
  }

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Professional> _professionals = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _perPage = 10;

  // Filtres
  String _selectedProfession = '';
  String _location = '';
  double _minRating = 0;
  bool _availableNow = false;
  String _sortBy = 'relevance';
  // Suppression de la variable inutilisée

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent &&
        !_isLoading &&
        _hasMore) {
      _loadMoreProfessionals();
    }
  }

  Future<void> _loadProfessionals({bool reset = false}) async {
    if (reset) {
      setState(() {
        _currentPage = 1;
        _professionals = [];
        _hasMore = true;
      });
    }

    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Utiliser le token passé en paramètre ou récupérer depuis SharedPreferences
      String? token = widget.token;
      if (token == null || token.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('token'); // ← Utiliser 'token' au lieu de 'access_token'
      }

      if (token == null || token.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token d\'authentification manquant. Veuillez vous reconnecter.')),
        );
        return;
      }
      
      final params = <String, String>{
        'page': _currentPage.toString(),
        'per_page': _perPage.toString(),
        if (_searchController.text.isNotEmpty) 'search': _searchController.text,
        if (_selectedProfession.isNotEmpty) 'profession': _selectedProfession,
        if (_location.isNotEmpty) 'location': _location,
        if (_minRating > 0) 'min_rating': _minRating.toString(),
        'available_now': _availableNow.toString(),
        'sort_by': _sortBy,
      };

      print('Envoi de la requête avec les paramètres: $params');

      final data = await ApiService.get('professionals', queryParams: params);

      print('Données reçues: $data');
      print('Type de data: ${data.runtimeType}');

      if (data != null) {
        // Gestion de la structure de réponse
        final Map<String, dynamic> responseData = data is Map<String, dynamic> ? data : {};
        final Map<String, dynamic> professionalsData = responseData['data'] is Map<String, dynamic>
            ? responseData['data'] as Map<String, dynamic>
            : {};

        final List<dynamic> professionalsJson = professionalsData['data'] ?? [];

        print('Données reçues: ${professionalsJson.length} professionnels');

        // Debug: Afficher les données du premier professionnel pour voir la structure
        if (professionalsJson.isNotEmpty) {
          print('=== DEBUG PREMIER PROFESSIONNEL ===');
          print('Premier professionnel brut: ${professionalsJson[0]}');

          final firstPro = professionalsJson[0] as Map<String, dynamic>;
          print('Champs disponibles: ${firstPro.keys.toList()}');
          print('profile_photo présent: ${firstPro.containsKey('profile_photo')}');
          if (firstPro.containsKey('profile_photo')) {
            print('profile_photo value: ${firstPro['profile_photo']}');
            print('profile_photo type: ${firstPro['profile_photo'].runtimeType}');
          }
          print('avatar_url présent: ${firstPro.containsKey('avatar_url')}');
          if (firstPro.containsKey('avatar_url')) {
            print('avatar_url value: ${firstPro['avatar_url']}');
          }
        }

        setState(() {
          if (reset) {
            _professionals = professionalsJson
                .map<Professional>((json) => Professional.fromJson(json))
                .toList();
          } else {
            _professionals.addAll(
              professionalsJson
                  .map<Professional>((json) => Professional.fromJson(json))
                  .toList(),
            );
          }

          // Gestion de la pagination avec la nouvelle structure
          final Map<String, dynamic> meta = professionalsData['meta'] ?? {};
          _hasMore = (meta['current_page'] ?? 0) < (meta['last_page'] ?? 0);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du chargement des professionnels'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Erreur détaillée: $e');
      print('Stack trace: $stackTrace');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _loadMoreProfessionals() async {
    if (!_isLoading && _hasMore) {
      setState(() {
        _currentPage++;
      });
      await _loadProfessionals();
    }
  }

  // Méthode conservée pour compatibilité future
  void _resetFilters() {
    // Implémentation vide car non utilisée dans la nouvelle interface
  }

  Future<void> _toggleFavorite(Professional professional) async {
    try {
      String? token = widget.token;
      if (token == null || token.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('token'); // ← Utiliser 'token' au lieu de 'access_token'
      }

      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token d\'authentification manquant. Veuillez vous reconnecter.')),
        );
        return;
      }

      final response = await ApiService.post(
        'favorites/professionals/toggle',
        data: {
          'professional_id': professional.id,
        },
      );

      if (response != null) {
        final message = response['message'] ?? 'Action effectuée';

        // Update the professional's favorite status in the list
        setState(() {
          final index = _professionals.indexWhere((p) => p.id == professional.id);
          if (index != -1) {
            _professionals[index] = _professionals[index].copyWith(isFavorite: !_professionals[index].isFavorite);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'opération'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de connexion: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Méthode conservée pour compatibilité future
  void _applyFilters() {
    _loadProfessionals(reset: true);
  }

  // Widget pour les puces de filtre
  Widget _buildFilterChip(String label, {bool isSelected = false}) {
    return GestureDetector(
      onTap: () {
        // Logique de filtrage simplifiée
        setState(() {
          // Mettre à jour l'état du filtre sélectionné
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFCC00) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFCC00) : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : Colors.grey[800],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Rechercher un Professionnel',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFFFFCC00),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Barre de recherche et filtres
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFCC00),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Barre de recherche
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un professionnel...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFFFCC00)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                _loadProfessionals(reset: true);
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    ),
                    style: GoogleFonts.poppins(fontSize: 14),
                    onSubmitted: (_) => _loadProfessionals(reset: true),
                  ),
                ),
                const SizedBox(height: 16),
                // Filtres rapides
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Tous', isSelected: true),
                      _buildFilterChip('Disponible'),
                      _buildFilterChip('Proche de vous'),
                      _buildFilterChip('Mieux notés'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Liste des professionnels
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
      bottomNavigationBar: _isRoleDetectionComplete && !_isProClient
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: const Color(0xFFFFFFFF),
              selectedItemColor: const Color(0xFFFFCC00),
              unselectedItemColor: Colors.grey,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  label: 'Accueil',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: 'Recherche',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_outlined),
                  label: 'Devis',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  label: 'Profil',
                ),
              ],
            )
          : null, // Cacher la barre de navigation pour les pros et pendant la détection du rôle
    );
  }

  Widget _buildBody() {
    if (_isLoading && _professionals.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_professionals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun professionnel trouvé',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez de modifier vos critères de recherche',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadProfessionals(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: _professionals.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _professionals.length) {
            return _buildLoader();
          }
          return _buildProfessionalCard(_professionals[index]);
        },
      ),
    );
  }

  Widget _buildProfessionalCard(Professional professional) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfessionalDetailScreen(
                professionalId: professional.id,
                token: widget.token ?? '',
                userData: widget.userData ?? <String, dynamic>{},
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo de profil
              Hero(
                tag: 'professional-${professional.id}',
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[200],
                    border: Border.all(
                      color: const Color(0xFFFFCC00).withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: professional.fullAvatarUrl != null
                        ? CachedNetworkImage(
                            imageUrl: professional.fullAvatarUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFCC00)),
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              professional.fullName
                                  .split(' ')
                                  .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
                                  .join(''),
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Détails du professionnel
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom et métier
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                professional.displayName,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.grey[800],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                professional.profession,
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Bouton favori
                        IconButton(
                          icon: Icon(
                            Icons.favorite,
                            color: professional.isFavorite
                                ? Colors.red
                                : Colors.grey[300],
                            size: 24,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _toggleFavorite(professional),
                        ),
                      ],
                    ),
                    
                    // Note et avis
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFCC00).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                color: Color(0xFFFFCC00),
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                professional.rating.toStringAsFixed(1),
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFFA000),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${professional.reviewCount} avis)',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Localisation
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            professional.address.isNotEmpty 
                                ? professional.address
                                : (professional.city?.isNotEmpty == true 
                                    ? '${professional.city}${professional.postalCode != null ? ', ${professional.postalCode}' : ''}'
                                    : 'Localisation non disponible'),
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    // Badge de disponibilité
                    if (professional.isAvailable) ...{
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Disponible maintenant',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF4CAF50),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    },
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return _isLoading
        ? Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFFFCC00)),
              ),
            ),
          )
        : const SizedBox.shrink();
  }
}
