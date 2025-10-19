import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
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
  bool _showFilters = false;

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

      final uri = Uri.parse('${ApiService.baseUrl}/api/professionals').replace(
        queryParameters: params,
      );

      print('Envoi de la requête à: $uri');
      print('Avec les paramètres: $params');
      print('Headers: ${{
        'Accept': 'application/json',
        'Authorization': 'Bearer $token'
      }}');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('Réponse reçue: ${response.statusCode}');
      print('Corps de la réponse: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        // Gestion de la structure de réponse imbriquée
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
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        final errorMessage = error['message'] ?? 'Échec du chargement des professionnels (${response.statusCode})';

        // Gestion spécifique des erreurs courantes
        if (response.statusCode == 404) {
          if (errorMessage.contains('ID professionnel invalide')) {
            throw Exception('L\'endpoint de recherche n\'est pas disponible. Veuillez contacter l\'administrateur.');
          } else {
            throw Exception('Page non trouvée. Vérifiez l\'URL de l\'API.');
          }
        } else if (response.statusCode == 401) {
          throw Exception('Token d\'authentification invalide. Veuillez vous reconnecter.');
        } else if (response.statusCode == 403) {
          throw Exception('Accès refusé. Vous n\'avez pas les permissions nécessaires.');
        } else {
          throw Exception(errorMessage);
        }
      }
    } on http.ClientException catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de connexion: ${e.message}'),
          duration: const Duration(seconds: 5),
        ),
      );
    } on TimeoutException {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Délai d\'attente dépassé. Vérifiez votre connexion internet.'),
          duration: Duration(seconds: 5),
        ),
      );
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

  void _resetFilters() {
    setState(() {
      _selectedProfession = '';
      _location = '';
      _minRating = 0;
      _availableNow = false;
      _sortBy = 'relevance';
    });
    _loadProfessionals(reset: true);
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

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/favorites/professionals/toggle'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'professional_id': professional.id,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final message = data['message'] ?? 'Action effectuée';

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
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        final errorMessage = error['message'] ?? 'Erreur lors de l\'opération';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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

  void _applyFilters() {
    setState(() {
      _showFilters = false;
    });
    _loadProfessionals(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    print('=== DEBUG BUILD ===');
    print('_isProClient: $_isProClient (${_isProClient.runtimeType})');
    print('_isRoleDetectionComplete: $_isRoleDetectionComplete (${_isRoleDetectionComplete.runtimeType})');
    print('widget.token: ${widget.token}');
    print('widget.userData: ${widget.userData}');
    
    // Afficher la pile d'appels pour comprendre d'où vient le build
    print('Stack trace:');
    print(StackTrace.current.toString().split('\n').take(5).join('\n'));
    
    // Vérifier si le widget est toujours monté
    if (!mounted) {
      print('Widget non monté, retourne un conteneur vide');
      return Container();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Rechercher un professionnel',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(350),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un professionnel...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFFFCC00).withOpacity(0.1),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _loadProfessionals(reset: true);
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _loadProfessionals(reset: true),
                ),
                if (_showFilters) Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 200,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Filtres',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: 'Métier',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    isDense: true,
                                  ),
                                  onChanged: (value) => _selectedProfession = value,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: 'Localisation',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    isDense: true,
                                  ),
                                  onChanged: (value) => _location = value,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Note minimale: ${_minRating.toInt()}+',
                                      style: GoogleFonts.poppins(fontSize: 12),
                                    ),
                                    RatingBar.builder(
                                      initialRating: _minRating,
                                      minRating: 0,
                                      direction: Axis.horizontal,
                                      allowHalfRating: false,
                                      itemCount: 5,
                                      itemSize: 16,
                                      itemBuilder: (context, _) => const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                      ),
                                      onRatingUpdate: (rating) {
                                        setState(() {
                                          _minRating = rating;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Trier par:'),
                                    DropdownButton<String>(
                                      value: _sortBy,
                                      isDense: true,
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'relevance',
                                          child: Text('Pertinence', style: TextStyle(fontSize: 12)),
                                        ),
                                        DropdownMenuItem(
                                          value: 'rating',
                                          child: Text('Note', style: TextStyle(fontSize: 12)),
                                        ),
                                        DropdownMenuItem(
                                          value: 'distance',
                                          child: Text('Distance', style: TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _sortBy = value;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Checkbox(
                                value: _availableNow,
                                onChanged: (value) {
                                  setState(() {
                                    _availableNow = value ?? false;
                                  });
                                },
                              ),
                              const Text('Disponible maintenant'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _resetFilters,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  child: const Text('Réinitialiser'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _applyFilters,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFCC00),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  child: const Text('Appliquer'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _isRoleDetectionComplete && !_isProClient
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: const Color(0xFFE5E5E5),
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
            )
          : null, // Hide navigation bar for pro clients and while role detection is in progress
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
          padding: const EdgeInsets.all(12),
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
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: professional.fullAvatarUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: professional.fullAvatarUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.person, size: 40),
                          ),
                        )
                      : Center(
                          child: Text(
                            professional.fullName
                                .split(' ')
                                .map((e) => e.isNotEmpty ? e[0] : '')
                                .join(''),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Détails du professionnel
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            professional.displayName,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      professional.profession,
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        RatingBarIndicator(
                          rating: professional.rating,
                          itemBuilder: (context, index) => const Icon(
                            Icons.star,
                            color: Colors.amber,
                          ),
                          itemCount: 5,
                          itemSize: 16,
                          direction: Axis.horizontal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${professional.reviewCount})',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Paris, France', // À remplacer par la localisation réelle
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            professional.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: professional.isFavorite
                                ? Colors.red
                                : Colors.grey,
                          ),
                          onPressed: () => _toggleFavorite(professional),
                        ),
                        if (professional.isAvailable)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFCC00).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFCC00).withOpacity(0.3)),
                            ),
                            child: Text(
                              'Disponible',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFFFCC00),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
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
        ? const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        : const SizedBox.shrink();
  }
}
