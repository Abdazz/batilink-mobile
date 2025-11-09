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
    
    // Ajouter un écouteur sur le champ de recherche
    _searchController.addListener(() {
      // Délai pour éviter de faire trop de requêtes pendant la saisie
      const duration = Duration(milliseconds: 500);
      if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
      _searchDebounce = Timer(duration, () {
        if (mounted) {
          _loadProfessionals(reset: true);
        }
      });
    });
  }
  
  Timer? _searchDebounce;

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

  // Variables d'état pour les filtres
  String _selectedProfession = '';
  String _location = '';
  String _selectedSkill = '';
  double _minRating = 0.0;
  bool _availableNow = false;
  int _searchRadius = 10; // Rayon de recherche par défaut en kms
  final List<String> _selectedSkills = [];
  
  // Contrôleurs pour les champs de formulaire
  final TextEditingController _professionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  // Méthode pour afficher la boîte de dialogue des filtres
  Future<void> _showFilterDialog() async {
    // Mettre à jour les contrôleurs avec les valeurs actuelles
    _professionController.text = _selectedProfession;
    _locationController.text = _location;
    
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Filtres avancés', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Métier', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _professionController,
                      decoration: InputDecoration(
                        hintText: 'Ex: Plombier, Électricien',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Localisation', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        hintText: 'Ville ou adresse',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.my_location, size: 20),
                          onPressed: () {
                            // TODO: Implémenter la détection de la position actuelle
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Fonctionnalité de géolocalisation à venir')),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Note minimale: ${_minRating.toInt()}', 
                         style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                    Slider(
                      value: _minRating,
                      min: 0,
                      max: 5,
                      divisions: 5,
                      label: _minRating == 0 ? 'Toutes notes' : _minRating.toStringAsFixed(1),
                      onChanged: (value) {
                        setState(() {
                          _minRating = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _availableNow,
                          onChanged: (value) {
                            setState(() {
                              _availableNow = value ?? false;
                            });
                          },
                          activeColor: const Color(0xFFFFCC00),
                        ),
                        Text('Disponible maintenant', 
                             style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('ANNULER', style: GoogleFonts.poppins(color: Colors.grey[700])),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedProfession = _professionController.text.trim();
                      _location = _locationController.text.trim();
                    });
                    Navigator.of(context).pop();
                    _applyFilters();
                  },
                  child: Text('APPLIQUER', style: GoogleFonts.poppins(color: const Color(0xFFFFCC00), fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _professionController.dispose();
    _locationController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && !_isLoading && _hasMore) {
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

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Utiliser le token passé en paramètre ou récupérer depuis SharedPreferences
      String? token = widget.token;
      if (token == null || token.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('token');
      }

      if (token == null || token.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token d\'authentification manquant. Veuillez vous reconnecter.')),
        );
        return;
      }

      // Préparer les paramètres de requête selon la documentation
      final params = <String, String>{
        'page': _currentPage.toString(),
        'per_page': _perPage.toString(),
        // Recherche par nom d'entreprise
        if (_searchController.text.isNotEmpty) 'company_name': _searchController.text.trim(),
        // Recherche par métier (si pas de recherche par nom d'entreprise)
        if (_selectedProfession.isNotEmpty && _searchController.text.isEmpty) 'job_title': _selectedProfession.trim(),
        // Filtre par compétence (si spécifié)
        if (_selectedSkill.isNotEmpty) 'skill': _selectedSkill.trim(),
        // Filtre par note minimale
        if (_minRating > 0) 'min_rating': _minRating.toStringAsFixed(1),
        // Filtre par disponibilité
        if (_availableNow) 'is_available': 'true',
      };

      // Gestion de la localisation (ville/adresse ou coordonnées GPS)
      if (_location.isNotEmpty) {
        // Si la localisation est au format "latitude,longitude" -> recherche par proximité
        if (_location.contains(',')) {
          try {
            final coords = _location.split(',');
            if (coords.length == 2) {
              final lat = double.tryParse(coords[0].trim());
              final lng = double.tryParse(coords[1].trim());
              
              if (lat != null && lng != null) {
                // On utilise les paramètres de géolocalisation
                params.addAll({
                  'latitude': lat.toString(),
                  'longitude': lng.toString(),
                  'radius': _searchRadius.toString(), // Rayon de recherche en km
                });
              }
            }
          } catch (e) {
            print('Erreur lors du traitement des coordonnées GPS: $e');
          }
        } else {
          // Sinon, recherche par ville/adresse
          params['location'] = _location.trim();
        }
      }

      // Nettoyer les paramètres vides
      params.removeWhere((key, value) => value.isEmpty);

      print('Envoi de la requête avec les paramètres: $params');

      // Déterminer l'endpoint à utiliser en fonction des paramètres
      final bool useNearbySearch = params.containsKey('latitude') && 
                                 params.containsKey('longitude');
      final String endpoint = useNearbySearch ? 'professionals/nearby' : 'professionals';

      print('Envoi de la requête vers $endpoint avec les paramètres: $params');

      final response = await ApiService.get(endpoint, queryParams: params);

      print('Réponse reçue: ${response != null ? 'données reçues' : 'null'}');

      if (response != null) {
        // Gestion de la structure de réponse
        final Map<String, dynamic> responseData = response is Map<String, dynamic> ? response : {};

        // La structure de réponse peut varier selon l'endpoint
        List<dynamic> professionalsJson = [];
        Map<String, dynamic> meta = {};

        if (useNearbySearch) {
          // Structure pour l'endpoint de proximité
          professionalsJson = responseData['data'] ?? [];
          meta = {
            'current_page': _currentPage,
            'last_page': _currentPage, // Pas de pagination pour les recherches par proximité
          };
        } else {
          // Structure standard pour l'endpoint /professionals
          final Map<String, dynamic> professionalsData = responseData['data'] is Map<String, dynamic> ? responseData['data'] as Map<String, dynamic> : {};

          professionalsJson = professionalsData['data'] ?? [];
          meta = professionalsData['meta'] ?? {};
        }

        print('${professionalsJson.length} professionnels reçus');
        
        // Log de débogage pour voir la structure des données
        if (professionalsJson.isNotEmpty) {
          print('=== STRUCTURE DU PREMIER PROFESSIONNEL ===');
          print(professionalsJson.first);
          if (professionalsJson.first is Map) {
            print('Type de profile_photo: ${(professionalsJson.first as Map)['profile_photo']?.runtimeType}');
          }
        }

        setState(() {
          if (reset) {
            _professionals = professionalsJson.map<Professional>((json) => Professional.fromJson(json)).toList();
          } else {
            _professionals.addAll(professionalsJson.map<Professional>((json) => Professional.fromJson(json)).toList());
          }

          // Gestion de la pagination
          _hasMore = (meta['current_page'] ?? 0) < (meta['last_page'] ?? 0);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun professionnel trouvé avec ces critères'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Erreur détaillée: $e');
      print('Stack trace: $stackTrace');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la recherche: ${e.toString()}'),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red,
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

  // Appliquer les filtres et relancer la recherche
  void _applyFilters() {
    // Réinitialiser la pagination et recharger les professionnels
    _loadProfessionals(reset: true);
  }

  // Méthode pour réinitialiser tous les filtres
  void _resetAllFilters() {
    setState(() {
      _selectedProfession = '';
      _location = '';
      _selectedSkill = '';
      _minRating = 0.0;
      _availableNow = false;
      _searchRadius = 10;
      _selectedSkills.clear();
      _searchController.clear();
      _professionController.clear();
      _locationController.clear();
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

  // Widget pour afficher les filtres actifs
  Widget _buildActiveFilters() {
    final List<Widget> filters = [];

    if (_selectedProfession.isNotEmpty) {
      filters.add(_buildFilterChip('Métier: $_selectedProfession', onDelete: () {
        setState(() {
          _selectedProfession = '';
          _professionController.clear();
          _applyFilters();
        });
      }));
    }

    if (_location.isNotEmpty) {
      filters.add(_buildFilterChip('Lieu: $_location', onDelete: () {
        setState(() {
          _location = '';
          _locationController.clear();
          _applyFilters();
        });
      }));
    }

    if (_minRating > 0) {
      filters.add(_buildFilterChip('Note: ${_minRating.toStringAsFixed(1)}+', onDelete: () {
        setState(() {
          _minRating = 0;
          _applyFilters();
        });
      }));
    }

    if (_availableNow) {
      filters.add(_buildFilterChip('Disponible', onDelete: () {
        setState(() {
          _availableNow = false;
          _applyFilters();
        });
      }));
    }

    if (filters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filtres actifs', style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              )),
              TextButton(
                onPressed: _resetAllFilters,
                child: Text('Tout effacer', style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                )),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(children: filters),
        ),
      ],
    );
  }

  // Widget pour les puces de filtre avec bouton de suppression
  Widget _buildFilterChip(String label, {required VoidCallback onDelete}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: Chip(
        label: Text(label, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: Colors.white,
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onDelete,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey[300]!),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filtres avancés',
          ),
        ],
      ),
      body: Column(
        children: [
          // Affichage des filtres actifs
          _buildActiveFilters(),
          // Barre de recherche
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
                      _buildFilterChip('Tous', onDelete: () {
                        setState(() {
                          _selectedProfession = '';
                          _location = '';
                          _minRating = 0;
                          _availableNow = false;
                          _searchController.clear();
                          _applyFilters();
                        });
                      }),
                      _buildFilterChip('Disponible', onDelete: () {
                        setState(() {
                          _availableNow = !_availableNow;
                          _applyFilters();
                        });
                      }),
                      _buildFilterChip('Proche de vous', onDelete: () {
                        // Implémenter la logique de géolocalisation ici
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fonctionnalité de géolocalisation à venir')),
                        );
                      }),
                      _buildFilterChip('4 étoiles +', onDelete: () {
                        setState(() {
                          _minRating = 4.0;
                          _applyFilters();
                        });
                      }),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
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
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ClientCompletedQuotationsScreen(
                  token: widget.token ?? '',
                  userData: widget.userData ?? <String, dynamic>{},
                ),
              ),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ClientProfileScreen(
                  token: widget.token ?? '',
                  userData: widget.userData ?? <String, dynamic>{},
                ),
              ),
            );
          }
        },
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
      ),
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
                              // Afficher le nom de l'entreprise s'il existe, sinon le nom du professionnel
                              Text(
                                professional.companyName?.isNotEmpty == true 
                                    ? professional.companyName!
                                    : '${professional.firstName} ${professional.lastName}'.trim(),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.grey[800],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              // Afficher le métier et la ville si disponible
                              Text(
                                [
                                  professional.jobTitle.isNotEmpty ? professional.jobTitle : professional.profession,
                                  if (professional.city?.isNotEmpty == true) professional.city!,
                                ].join(' • '),
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
