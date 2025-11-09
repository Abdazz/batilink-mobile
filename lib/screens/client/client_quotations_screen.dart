import 'dart:convert';
import 'package:batilink_mobile_app/screens/client/professional_search_screen.dart';
import 'package:batilink_mobile_app/screens/unified_quotation_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_config.dart';

class ClientQuotationsScreen extends StatefulWidget {
  final String? token;
  final Map<String, dynamic>? userData;

  const ClientQuotationsScreen({
    Key? key,
    this.token,
    this.userData,
  }) : super(key: key);

  @override
  _ClientQuotationsScreenState createState() => _ClientQuotationsScreenState();
}

class _ClientQuotationsScreenState extends State<ClientQuotationsScreen> {
  List<dynamic> _quotations = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _token = '';
  Map<String, dynamic> _userData = {};
  final Set<String> _fetchingDetails = <String>{};
  String _statusFilter = 'all'; // all, pending, quoted, accepted, in_progress, completed, cancelled, rejected

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recharger les devis si les arguments de route changent
    _initializeData();
  }

  List<Widget> _buildStatusChips() {
    const statuses = [
      {'key': 'all', 'label': 'Tous'},
      {'key': 'pending', 'label': 'En attente'},
      {'key': 'quoted', 'label': 'Devis reçus'},
      {'key': 'accepted', 'label': 'Acceptés'},
      {'key': 'in_progress', 'label': 'En cours'},
      {'key': 'completed', 'label': 'Terminés'},
      {'key': 'cancelled', 'label': 'Annulés'},
      {'key': 'rejected', 'label': 'Refusés'},
    ];
    return statuses.map((s) {
      final selected = _statusFilter == s['key'];
      return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: ChoiceChip(
          label: Text(s['label'] as String, style: GoogleFonts.poppins(fontSize: 12)),
          selected: selected,
          selectedColor: Colors.black.withOpacity(0.08),
          backgroundColor: Colors.white,
          shape: StadiumBorder(side: BorderSide(color: selected ? Colors.black : Colors.grey.shade300)),
          onSelected: (_) => setState(() => _statusFilter = s['key'] as String),
        ),
      );
    }).toList();
  }

  Future<void> _ensureQuotationDetails(String quotationId) async {
    if (_fetchingDetails.contains(quotationId) || _token.isEmpty) return;
    _fetchingDetails.add(quotationId);
    try {
      final resp = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/quotations/$quotationId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final detailed = data['data'] ?? {};
        final idx = _quotations.indexWhere((e) => e['id'].toString() == quotationId);
        if (idx != -1) {
          setState(() {
            _quotations[idx] = {
              ..._quotations[idx],
              // Fusionner champs de réponse pro
              if (detailed['amount'] != null) 'amount': detailed['amount'],
              if (detailed['proposed_date'] != null) 'proposed_date': detailed['proposed_date'],
              if (detailed['professional_notes'] != null) 'professional_notes': detailed['professional_notes'],
              if (detailed['notes'] != null && detailed['professional_notes'] == null) 'notes': detailed['notes'],
            };
          });
        }
      }
    } catch (_) {
      // ignorer les erreurs silencieusement
    } finally {
      _fetchingDetails.remove(quotationId);
    }
  }

  Future<void> _initializeData() async {
    print('=== DÉBOGAGE _initializeData ===');
    
    // Récupérer le token et les données utilisateur depuis SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final tokenFromPrefs = prefs.getString('token') ?? '';
    
    print('Token du widget: ${widget.token?.isNotEmpty == true ? 'Présent' : 'Manquant'}');
    print('Token depuis SharedPreferences: ${tokenFromPrefs.isNotEmpty ? 'Présent' : 'Manquant'}');
    print('Données utilisateur reçues dans le widget: ${widget.userData}');

    // Utiliser le token passé en argument, ou celui de SharedPreferences comme secours
    final finalToken = widget.token?.isNotEmpty == true ? widget.token! : tokenFromPrefs;

    if (finalToken.isEmpty) {
      final errorMsg = 'Token d\'authentification manquant';
      print('Erreur: $errorMsg');
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
      return;
    }

    print('Token final qui sera utilisé: ${finalToken.isNotEmpty ? 'Présent' : 'Manquant'}');
    
    // Mettre à jour le token
    setState(() {
      _token = finalToken;
    });

    // Tenter de récupérer les données utilisateur
    bool userDataLoaded = false;
    
    // 1. Vérifier si des données sont passées dans le widget
    if (widget.userData != null && widget.userData!.isNotEmpty) {
      print('Utilisation des données utilisateur du widget');
      _userData = Map<String, dynamic>.from(widget.userData!);
      userDataLoaded = true;
    } 
    // 2. Sinon, essayer de charger depuis SharedPreferences
    else {
      print('Aucune donnée utilisateur fournie, tentative de récupération depuis le stockage local...');
      try {
        final userDataStr = prefs.getString('user');
        if (userDataStr != null && userDataStr.isNotEmpty) {
          print('Données utilisateur trouvées dans le stockage local');
          final userData = jsonDecode(userDataStr);
          if (userData is Map) {
            _userData = Map<String, dynamic>.from(userData);
            userDataLoaded = true;
            print('Données utilisateur chargées: $_userData');
          }
        } else {
          print('Aucune donnée utilisateur trouvée dans le stockage local');
        }
      } catch (e) {
        print('Erreur lors de la lecture des données utilisateur: $e');
      }
    }
    
    // 3. Si toujours pas de données utilisateur, essayer d'extraire l'ID du token JWT
    if (!userDataLoaded) {
      print('Tentative d\'extraction des informations du token JWT...');
      try {
        final parts = _token.split('.');
        if (parts.length > 2) {
          final payload = parts[1];
          final normalized = base64Url.normalize(payload);
          final resp = utf8.decode(base64Url.decode(normalized));
          final payloadMap = json.decode(resp);
          
          if (payloadMap is Map && payloadMap['sub'] != null) {
            _userData['id'] = payloadMap['sub'].toString();
            print('ID utilisateur extrait du token JWT: ${_userData['id']}');
            userDataLoaded = true;
          }
        }
      } catch (e) {
        print('Erreur lors de l\'extraction des données du token JWT: $e');
      }
    }
    
    // Si on a toujours pas de données utilisateur, on essaie quand même de charger les devis
    // car le backend peut utiliser le token pour identifier l'utilisateur
    _loadQuotations();
  }

  // Méthode utilitaire pour obtenir une valeur imbriquée dans une Map
  dynamic _getNestedValue(Map<dynamic, dynamic> map, String key) {
    try {
      return key.split('.').fold<dynamic>(map, (current, key) => current != null && current is Map ? current[key] : null);
    } catch (e) {
      print('Erreur lors de l\'accès à la clé $key: $e');
      return null;
    }
  }

  // Méthode pour obtenir l'ID de l'utilisateur connecté
  Future<String?> _getCurrentUserId() async {
    print('=== DÉBOGAGE _getCurrentUserId ===');
    
    // 1. D'abord, vérifier si on a déjà un ID dans _userData
    if (_userData.isNotEmpty) {
      print('Recherche de l\'ID dans _userData: $_userData');
      
      // Vérifier plusieurs clés possibles pour l'ID
      final possibleIdKeys = ['id', 'user_id', 'userId', 'user.id', 'data.user.id'];
      
      for (var key in possibleIdKeys) {
        final value = _getNestedValue(_userData, key);
        if (value != null) {
          final id = value.toString();
          print('ID trouvé avec la clé $key dans _userData: $id');
          return id;
        }
      }
      
      print('Aucun ID trouvé dans _userData avec les clés testées');
    }
    
    // 2. Si pas trouvé, essayer avec widget.userData
    if (widget.userData != null && widget.userData!.isNotEmpty) {
      print('Recherche de l\'ID dans widget.userData: ${widget.userData}');
      
      // Vérifier plusieurs clés possibles pour l'ID
      final possibleIdKeys = ['id', 'user_id', 'userId', 'user.id', 'data.user.id'];
      
      for (var key in possibleIdKeys) {
        final value = _getNestedValue(widget.userData!, key);
        if (value != null) {
          final id = value.toString();
          print('ID trouvé avec la clé $key dans widget.userData: $id');
          return id;
        }
      }
    }
    
    // 3. Si on a toujours pas trouvé, essayer d'extraire du token JWT
    if (_token.isNotEmpty) {
      try {
        print('Tentative d\'extraction de l\'ID depuis le token JWT...');
        print('Token complet: ${_token.substring(0, _token.length > 50 ? 50 : _token.length)}...');
        
        final parts = _token.split('.');
        print('Nombre de parties du token: ${parts.length}');
        
        if (parts.length > 2) {
          final payload = parts[1];
          print('Payload avant décodage: $payload');
          
          // Ajouter le padding manquant si nécessaire
          String normalized = payload.padRight(
            payload.length + (4 - payload.length % 4) % 4,
            '=',
          );
          
          print('Payload après padding: $normalized');
          
          try {
            final decoded = utf8.decode(base64Url.decode(normalized));
            print('Payload décodé: $decoded');
            
            final payloadMap = json.decode(decoded);
            print('Payload parsé: $payloadMap');
            
            // Vérifier plusieurs champs possibles pour l'ID utilisateur
            final possibleIdFields = ['sub', 'user_id', 'id', 'userId', 'user.id'];
            
            for (var field in possibleIdFields) {
              final value = _getNestedValue(payloadMap, field);
              if (value != null) {
                final id = value.toString();
                print('ID utilisateur trouvé dans le champ $field: $id');
                return id;
              }
            }
            
            print('Aucun champ d\'ID utilisateur trouvé dans le payload');
            print('Champs disponibles: ${payloadMap is Map ? payloadMap.keys.join(', ') : 'N/A'}');
            
          } catch (e) {
            print('Erreur lors du décodage du payload: $e');
          }
        } else {
          print('Format de token invalide: nombre de parties incorrect');
        }
      } catch (e) {
        print('Erreur lors de l\'extraction de l\'ID du token JWT: $e');
      }
    }
    
    // 4. Si on a toujours pas trouvé, essayer de récupérer depuis SharedPreferences
    try {
      print('Tentative de récupération de l\'ID depuis SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('user');
      
      if (userDataStr != null && userDataStr.isNotEmpty) {
        try {
          final userData = jsonDecode(userDataStr);
          if (userData is Map) {
            // Vérifier plusieurs clés possibles pour l'ID
            final possibleIdKeys = ['id', 'user_id', 'userId', 'user.id'];
            
            for (var key in possibleIdKeys) {
              final value = _getNestedValue(userData, key);
              if (value != null) {
                final id = value.toString();
                print('ID trouvé avec la clé $key dans SharedPreferences: $id');
                return id;
              }
            }
            
            print('Aucun ID trouvé dans les données de SharedPreferences');
            print('Données disponibles dans SharedPreferences: $userData');
          }
        } catch (e) {
          print('Erreur lors du décodage des données utilisateur: $e');
        }
      } else {
        print('Aucune donnée utilisateur trouvée dans SharedPreferences');
      }
    } catch (e) {
      print('Erreur lors de l\'accès à SharedPreferences: $e');
    }
    
    print('Aucun ID utilisateur trouvé dans les données disponibles');
    return null;
  }

  Future<void> _loadQuotations() async {
    try {
      final token = _token;
      
      // Ajout de logs pour le débogage
      print('=== DÉBOGAGE _loadQuotations ===');
      print('Token: ${token.isNotEmpty ? 'Présent' : 'Manquant'}');
      print('Données utilisateur reçues: ${widget.userData}');
      
      // Récupérer l'ID utilisateur
      final userId = await _getCurrentUserId();
      print('ID utilisateur récupéré: $userId');

      if (token.isEmpty) {
        final errorMsg = 'Token d\'authentification manquant';
        print('Erreur: $errorMsg');
        setState(() {
          _errorMessage = errorMsg;
          _isLoading = false;
        });
        return;
      }

      if (userId == null) {
        final errorMsg = 'Impossible d\'identifier l\'utilisateur';
        print('Erreur: $errorMsg');
        print('Contenu de userData: ${widget.userData}');
        
        // Essayer de récupérer l'ID depuis le token (si nécessaire)
        // Cette partie dépend de votre implémentation de décodage du JWT
        
        setState(() {
          _errorMessage = errorMsg;
          _isLoading = false;
        });
        return;
      }

      // Construire l'URL avec les paramètres de requête
      final params = <String, dynamic>{
        'context': 'client',
        // Le backend gère automatiquement le filtrage par utilisateur
      };
      
      // Ajouter le filtre de statut si différent de 'all'
      if (_statusFilter != 'all') {
        params['status'] = _statusFilter;
      }

      final uri = Uri.parse('${AppConfig.baseUrl}/api/quotations').replace(
        queryParameters: params,
      );

      print('Chargement des devis avec les paramètres: $params');
      
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      print('Réponse du serveur: ${response.statusCode}');
      print('Corps de la réponse: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Le backend gère déjà le filtrage par utilisateur
        // Nous faisons confiance à la réponse du serveur
        final filteredQuotations = (data['data'] is List) ? List<dynamic>.from(data['data']) : [];
        print('Nombre de devis reçus: ${filteredQuotations.length}');
        
        setState(() {
          _quotations = filteredQuotations;
          _isLoading = false;
          _errorMessage = null;
        });
        
        print('Devis filtrés: ${filteredQuotations.length} sur ${data['data']?.length ?? 0}');
      } else {
        setState(() {
          _errorMessage = 'Erreur lors du chargement des devis';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de connexion';
        _isLoading = false;
      });
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'quoted':
        return 'Devis reçu';
      case 'accepted':
        return 'Accepté';
      case 'rejected':
        return 'Refusé';
      case 'completed':
        return 'Terminé';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFCC00); // Jaune au lieu d'orange
      case 'quoted':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Appliquer filtre de statut
    final List<dynamic> displayed = _statusFilter == 'all'
        ? _quotations
        : _quotations.where((q) => (q['status'] ?? '').toString() == _statusFilter).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mes demandes de devis',
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _buildStatusChips(),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: const Color(0xFFFFCC00),
              ),
            )
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
              : displayed.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadQuotations,
                      color: const Color(0xFFFFCC00),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: displayed.length,
                        itemBuilder: (context, index) {
                          final quotation = displayed[index];
                          return _buildQuotationCard(quotation);
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Naviguer vers la recherche pour créer une nouvelle demande
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const ProfessionalSearchScreen(),
            ),
            (route) => false,
          );
        },
        backgroundColor: const Color(0xFFFFCC00),
        icon: const Icon(Icons.add),
        label: Text(
          'Nouvelle demande',
          style: GoogleFonts.poppins(),
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
            Icons.request_quote,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune demande de devis',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vous n\'avez pas encore fait de demande de devis',
            style: GoogleFonts.poppins(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfessionalSearchScreen(),
                ),
                (route) => false,
              );
            },
            icon: const Icon(Icons.search),
            label: Text(
              'Trouver un professionnel',
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

  Widget _buildQuotationCard(dynamic quotation) {
    // Enrichir paresseusement si statut >= quoted mais notes manquantes
    final String qId = quotation['id'].toString();
    final String status = (quotation['status'] ?? '').toString();
    final hasProNotes = ((quotation['professional_notes'] ?? quotation['notes']) != null)
        && ((quotation['professional_notes'] ?? quotation['notes']).toString().isNotEmpty);
    if ((status == 'quoted' || status == 'accepted' || status == 'in_progress' || status == 'completed') && !hasProNotes) {
      _ensureQuotationDetails(qId);
    }
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          // Naviguer vers les détails unifiés du devis puis rafraîchir la liste au retour
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UnifiedQuotationDetailScreen(
                quotationId: quotation['id'].toString(),
                quotation: quotation,
                token: _token,
                context: QuotationContext.client,
              ),
            ),
          );
          // Recharger pour refléter une éventuelle mise à jour (ex: quoted)
          _loadQuotations();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec statut et date
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(quotation['status']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(quotation['status']),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getStatusText(quotation['status']),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _getStatusColor(quotation['status']),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(quotation['created_at']),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Informations du professionnel
              if (quotation['professional'] != null) ...[
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        color: Colors.grey[200],
                      ),
                      child: _getProfessionalPhoto(quotation['professional']),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quotation['professional']['company_name'] ?? 'N/A',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            quotation['professional']['job_title'] ?? 'N/A',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Description
              Text(
                quotation['description'] ?? 'N/A',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 12),

              // Notes du professionnel si disponibles (visible à partir de quoted)
              if ((quotation['status'] == 'quoted' || quotation['status'] == 'accepted' || quotation['status'] == 'in_progress' || quotation['status'] == 'completed')
                  && ((quotation['professional_notes'] ?? quotation['notes']) != null)
                  && ((quotation['professional_notes'] ?? quotation['notes']).toString().isNotEmpty)) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.note_alt, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (quotation['professional_notes'] ?? quotation['notes']).toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
              ],

              // Date proposée et montant
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Date: ${_formatDate(quotation['proposed_date'])}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (quotation['amount'] != null) ...[
                    Text(
                      '${quotation['amount']} €',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFFCC00),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'En attente',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),

              // Pièces jointes
              if (quotation['attachments'] != null && (quotation['attachments'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (quotation['attachments'] as List).map<Widget>((attachment) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.attach_file, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            attachment['original_name'] ?? 'Fichier',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
      // Ignorer les placeholders externes potentiellement inaccessibles
      if (avatarUrl!.contains('via.placeholder.com') || avatarUrl!.contains('placeholder')) {
        avatarUrl = null;
      } else if (!(avatarUrl!.startsWith('http://') || avatarUrl!.startsWith('https://'))) {
        if (avatarUrl!.startsWith('/storage/') || avatarUrl!.startsWith('storage/')) {
          final cleanPath = avatarUrl!.startsWith('/') ? avatarUrl!.substring(1) : avatarUrl!;
          avatarUrl = '${AppConfig.baseUrl}/$cleanPath';
        }
      }
    }

    return avatarUrl != null && avatarUrl.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: CachedNetworkImage(
              imageUrl: avatarUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: Colors.grey[200],
                ),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: Colors.grey[200],
                ),
                child: Center(
                  child: Text(
                    professional['company_name']?[0]?.toUpperCase() ?? 'N',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFCC00),
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          )
        : Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: Colors.grey[200],
            ),
            child: Center(
              child: Text(
                professional['company_name']?[0]?.toUpperCase() ?? 'N',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFFCC00),
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
          );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return 'N/A';
    }
  }
}
