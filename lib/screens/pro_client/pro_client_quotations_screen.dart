import 'dart:async';
import 'dart:convert';
import 'package:batilink_mobile_app/core/app_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../services/auth_service.dart';
import '../../services/pro_client_service.dart';

class ProClientQuotationsScreen extends StatefulWidget {
  final String? token;
  final Map<String, dynamic>? userData;
  final Map<String, dynamic>? filters;

  const ProClientQuotationsScreen({
    Key? key,
    this.token,
    this.userData,
    this.filters,
  }) : super(key: key);

  @override
  State<ProClientQuotationsScreen> createState() => _ProClientQuotationsScreenState();
}

class _ProClientQuotationsScreenState extends State<ProClientQuotationsScreen> {
  final ProClientService _proClientService = ProClientService(
    baseUrl: '${AppConfig.baseUrl}',
    authService: AuthService(baseUrl: '${AppConfig.baseUrl}'),
  );

  List<dynamic> _quotations = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProClient = false;
  String _finalToken = '';
  final Set<String> _fetchingDetails = <String>{};
  // Pas de filtre, on affiche tous les devis

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

  Future<void> _initializeData() async {
    // Détecter si l'utilisateur est un pro_client
    _isProClient = _detectProClientRole();

    // Récupérer le token depuis SharedPreferences comme secours
    final prefs = await SharedPreferences.getInstance();
    final tokenFromPrefs = prefs.getString('token') ?? '';

    // Utiliser le token passé en argument, ou celui de SharedPreferences comme secours
    _finalToken = widget.token?.isNotEmpty == true ? widget.token! : tokenFromPrefs;

    if (_finalToken.isEmpty) {
      setState(() {
        _errorMessage = 'Token d\'accès non trouvé';
        _isLoading = false;
      });
      return;
    }

    _loadQuotations();
  }

  bool _detectProClientRole() {
    // Vérifier les données utilisateur passées en argument
    final userData = widget.userData;
    if (userData == null) return false;

    // Fonction pour extraire le rôle d'un objet utilisateur
    String? extractRole(dynamic user) {
      if (user == null) return null;
      if (user is Map) {
        if (user['role'] is String) return user['role'];
        if (user['user'] is Map) return user['user']['role']?.toString();
      }
      return null;
    }

    // Vérifier différentes structures de données possibles
    final role = userData['role']?.toString() ??
                extractRole(userData['data'] ?? userData['user'] ?? userData);

    print('Rôle détecté: $role');
    
    // Vérifier si l'utilisateur a le rôle pro_client
    return role == 'pro_client' || role == 'professional';
  }

  // Méthode pour obtenir l'ID de l'utilisateur connecté
  String? _getCurrentUserId() {
    if (widget.userData == null) return null;
    
    // Vérifier si l'ID est directement dans userData
    if (widget.userData!['id'] != null) {
      return widget.userData!['id'].toString();
    }
    
    // Vérifier la structure imbriquée data.user.id
    if (widget.userData!['data'] != null && 
        widget.userData!['data'] is Map &&
        widget.userData!['data']['user'] != null && 
        widget.userData!['data']['user'] is Map &&
        widget.userData!['data']['user']['id'] != null) {
      return widget.userData!['data']['user']['id'].toString();
    }
    
    // Vérifier la structure imbriquée user.id
    if (widget.userData!['user'] != null && 
        widget.userData!['user'] is Map &&
        widget.userData!['user']['id'] != null) {
      return widget.userData!['user']['id'].toString();
    }
    
    return null;
  }

  // Construction des puces de filtre de statut
  Future<void> _ensureQuotationDetails(String quotationId) async {
    if (_fetchingDetails.contains(quotationId) || _finalToken.isEmpty) return;
    _fetchingDetails.add(quotationId);
    
    try {
      print('🔍 Chargement des détails du devis: $quotationId');
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/quotations/$quotationId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $_finalToken',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final detailed = data['data'] ?? {};
        
        // Trouver l'index du devis à mettre à jour
        final idx = _quotations.indexWhere((e) => e['id']?.toString() == quotationId);
        
        if (idx != -1 && mounted) {
          setState(() {
            _quotations[idx] = {
              ..._quotations[idx],
              // Mettre à jour uniquement les champs nécessaires
              if (detailed['amount'] != null) 'amount': detailed['amount'],
              if (detailed['proposed_date'] != null) 'proposed_date': detailed['proposed_date'],
              if (detailed['professional_notes'] != null) 'professional_notes': detailed['professional_notes'],
              if (detailed['notes'] != null) 'notes': detailed['notes'],
              if (detailed['status'] != null) 'status': detailed['status'],
              if (detailed['professional'] != null) 'professional': detailed['professional'],
              if (detailed['client'] != null) 'client': detailed['client'],
            };
          });
          print('✅ Détails du devis $quotationId mis à jour avec succès');
        }
      } else {
        print('❌ Erreur lors du chargement des détails du devis: ${response.statusCode}');
        print('Réponse: ${response.body}');
      }
    } catch (e, stackTrace) {
      print('❌ Erreur lors du chargement des détails du devis: $e');
      print('Stack trace: $stackTrace');
    } finally {
      _fetchingDetails.remove(quotationId);
    }
  }

  @override
  void didUpdateWidget(ProClientQuotationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.token != oldWidget.token || widget.userData != oldWidget.userData) {
      _initializeData();
    }
  }

  Future<void> _loadQuotations() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = _finalToken;
      final userId = _getCurrentUserId();

      if (token.isEmpty) {
        setState(() {
          _errorMessage = 'Token d\'authentification manquant';
          _isLoading = false;
        });
        return;
      }

      if (userId == null) {
        setState(() {
          _errorMessage = 'Impossible d\'identifier l\'utilisateur';
          _isLoading = false;
        });
        return;
      }

      // Pas de filtre, on récupère tous les devis
      final params = <String, dynamic>{
        'context': _isProClient ? 'professional' : 'client',
      };

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

      if (mounted) {
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          
          if (responseData['data'] != null && responseData['data'] is List) {
            setState(() {
              _quotations = List<Map<String, dynamic>>.from(
                responseData['data'].map((x) => Map<String, dynamic>.from(x as Map)),
              );
            });

            // Charger les détails pour chaque devis
            for (var quotation in _quotations) {
              final id = quotation['id']?.toString();
              if (id != null) {
                await _ensureQuotationDetails(id);
              }
            }
          } else {
            setState(() {
              _quotations = [];
              _errorMessage = 'Format de réponse inattendu';
            });
          }
        } else {
          setState(() {
            _errorMessage = 'Erreur lors du chargement des devis: ${response.statusCode}';
          });
          print('Erreur de l\'API: ${response.body}');
        }
      }
    } on http.ClientException catch (e) {
      final errorMsg = 'Erreur de connexion: ${e.message}';
      print('❌ $errorMsg');
      if (mounted) {
        setState(() => _errorMessage = errorMsg);
      }
    } on TimeoutException catch (_) {
      const errorMsg = 'Délai d\'attente dépassé';
      print('⏱️ $errorMsg');
      if (mounted) {
        setState(() => _errorMessage = errorMsg);
      }
    } catch (e, stackTrace) {
      print('❌ Erreur inattendue: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _errorMessage = 'Erreur inattendue: ${e.toString().split('\n').first}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isProClient ? 'Mes Devis (Mode Pro)' : 'Mes Demandes (Mode Client)'),
        backgroundColor: const Color(0xFFFFCC00),
        elevation: 0,
        actions: [
          // Indicateur de chargement
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          
          // Bouton de rafraîchissement
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _loadQuotations,
            tooltip: 'Rafraîchir',
          ),
          
          // Badge Pro-Client
          if (_isProClient)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      color: Color(0xFFFF6B00),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      
      // Contenu principal
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!, 
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                              onPressed: _loadQuotations,
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : _quotations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.inbox_outlined, 
                                  size: 64, 
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Aucun devis trouvé',
                                  style: TextStyle(
                                    fontSize: 16, 
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _quotations.length,
                            itemBuilder: (context, index) {
                              final quote = _quotations[index];
                              return _buildQuotationCard(quote);
                            },
                          ),
          );
  }

  Widget _buildQuotationCard(dynamic quotation) {
    // Vérifier que la quotation est une Map
    if (quotation == null) return const SizedBox.shrink();
    
    // Convertir en Map si ce n'est pas déjà le cas
    final quote = quotation is Map ? Map<String, dynamic>.from(quotation) : <String, dynamic>{};
    
    // Extraire les données du professionnel et du client de manière sécurisée
    final professional = quote['professional'] is Map ? 
      Map<String, dynamic>.from(quote['professional'] as Map) : null;
    final client = quote['client'] is Map ? 
      Map<String, dynamic>.from(quote['client'] as Map) : null;
    
    // Déterminer le nom à afficher selon le rôle de l'utilisateur
    String displayName = 'Inconnu';
    if (_isProClient) {
      if (client != null) {
        final firstName = client['first_name']?.toString() ?? '';
        final lastName = client['last_name']?.toString() ?? '';
        displayName = '$firstName $lastName'.trim();
        if (displayName.isEmpty) displayName = 'Client';
      } else {
        displayName = 'Client';
      }
    } else if (professional != null) {
      displayName = professional['company_name']?.toString() ?? 'Professionnel';
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    quote['title']?.toString() ?? 'Sans titre',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1976D2),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(quote['status']?.toString()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatStatus(quote['status']?.toString() ?? 'pending'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              quote['description']?.toString() ?? 'Aucune description',
              style: TextStyle(color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            if (quote['amount'] != null) ...[
              Row(
                children: [
                  const Icon(Icons.euro, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    '${quote['amount']} €',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _isProClient ? 'Client: $displayName' : 'Pro: $displayName',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final id = quotation['id']?.toString();
                      if (id != null) _acceptQuotation(id);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Accepter'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final id = quotation['id']?.toString();
                      if (id != null) _rejectQuotation(id);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatStatus(String status) {
    if (status.isEmpty) return 'Inconnu';
    
    switch (status.toLowerCase()) {
      case 'pending':
        return 'En attente';
      case 'accepted':
        return 'Accepté';
      case 'rejected':
        return 'Refusé';
      case 'in_progress':
        return 'En cours';
      case 'completed':
        return 'Terminé';
      case 'cancelled':
        return 'Annulé';
      default:
        return status;
    }
  }

  Color _getStatusColor(String? status) {
    if (status == null || status.isEmpty) return Colors.grey;
    
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Future<void> _acceptQuotation(String quotationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token d\'accès non trouvé')),
        );
        return;
      }

      final response = await _proClientService.acceptQuotation(
        accessToken: token,
        quotationId: quotationId,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devis accepté avec succès !')),
        );
        _loadQuotations(); // Recharger la liste
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'acceptation du devis')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  Future<void> _rejectQuotation(String quotationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token d\'accès non trouvé')),
        );
        return;
      }

      final response = await _proClientService.cancelQuotation(
        accessToken: token,
        quotationId: quotationId,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devis refusé avec succès !')),
        );
        _loadQuotations(); // Recharger la liste
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du refus du devis')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }
}
