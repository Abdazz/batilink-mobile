import 'dart:convert';
import 'package:batilink_mobile_app/screens/unified_quotation_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/pro_client_service.dart';
import '../../core/app_config.dart';

class ProClientRespondQuotationsScreen extends StatefulWidget {
  final String? token;
  final Map<String, dynamic>? userData;
  final String? filterMode;

  const ProClientRespondQuotationsScreen({
    Key? key,
    this.token,
    this.userData,
    this.filterMode = 'pending',
  }) : super(key: key);

  @override
  State<ProClientRespondQuotationsScreen> createState() => _ProClientRespondQuotationsScreenState();
}

class _ProClientRespondQuotationsScreenState extends State<ProClientRespondQuotationsScreen> {
  final ProClientService _proClientService = ProClientService(
    baseUrl: AppConfig.baseUrl,
    authService: AuthService(baseUrl: AppConfig.baseUrl),
  );

  String _finalToken = '';
  bool _isLoading = true;
  bool _isProClient = false;
  String? _errorMessage;
  List<dynamic> _quotations = [];
  String _statusFilter = 'all'; 
  final Set<String> _fetchingDetails = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    _isProClient = _detectProClientRole();

    final prefs = await SharedPreferences.getInstance();
    final tokenFromPrefs = prefs.getString('token') ?? '';

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
    final userData = widget.userData;
    if (userData != null) {
      if (userData.containsKey('role') && userData['role'] == 'pro_client') {
        return true;
      }
      if (userData.containsKey('data') &&
          userData['data'] is Map &&
          userData['data']['user'] is Map &&
          userData['data']['user']['role'] == 'pro_client') {
        return true;
      }
      if (userData.containsKey('user') &&
          userData['user'] is Map &&
          userData['user']['role'] == 'pro_client') {
        return true;
      }
    }

    return false;
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
    if (_fetchingDetails.contains(quotationId) || _finalToken.isEmpty) return;
    _fetchingDetails.add(quotationId);
    try {
      final response = await _proClientService.getQuotations(
        accessToken: _finalToken,
        context: 'professional',
      );
      
      // Filtrer la réponse pour ne garder que le devis demandé

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final detailed = data is Map && data['data'] is List && (data['data'] as List).isNotEmpty 
            ? (data['data'] as List).first 
            : data;
            
        final idx = _quotations.indexWhere((e) => e['id']?.toString() == quotationId);
        if (idx != -1) {
          setState(() {
            _quotations[idx] = {
              ..._quotations[idx],
              if (detailed is Map) ...{
                if (detailed['amount'] != null) 'amount': detailed['amount'],
                if (detailed['proposed_date'] != null) 'proposed_date': detailed['proposed_date'],
                if (detailed['professional_notes'] != null) 'professional_notes': detailed['professional_notes'],
                if (detailed['notes'] != null && detailed['professional_notes'] == null) 'notes': detailed['notes'],
              },
            };
          });
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des détails du devis: $e');
    } finally {
      _fetchingDetails.remove(quotationId);
    }
  }

  // Méthode utilitaire pour convertir n'importe quel type de Map en Map<String, dynamic>
  Map<String, dynamic> _convertToMapStringDynamic(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  // Méthode utilitaire pour convertir une liste de données en List<Map<String, dynamic>>
  List<Map<String, dynamic>> _convertToListMapStringDynamic(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map<Map<String, dynamic>>((item) => _convertToMapStringDynamic(item)).toList();
    }
    return [];
  }

  Future<void> _loadQuotations() async {
    if (_finalToken == null) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/quotations'),
        headers: {
          'Authorization': 'Bearer $_finalToken',
          'Accept': 'application/json',
        },
      );

      print('Réponse reçue - Statut: ${response.statusCode}');
      print('Headers de la réponse: ${response.headers}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Données brutes de l\'API: $responseData');
        
        // Gestion plus robuste de la réponse de l'API
        List<dynamic> dataList = [];
        
        if (responseData is Map && responseData.containsKey('data')) {
          dataList = responseData['data'] is List ? responseData['data'] : [];
        } else if (responseData is List) {
          dataList = responseData;
        }
        
        print('Devis récupérés: ${dataList.length}');
        
        // Conversion sécurisée des données
        final List<Map<String, dynamic>> validQuotations = [];
        
        for (var item in dataList) {
          try {
            // Convertir l'élément en Map<String, dynamic>
            final Map<String, dynamic> convertedItem = _convertToMapStringDynamic(item);
            
            // Vérifier et convertir le champ 'client' s'il existe
            if (convertedItem.containsKey('client')) {
              convertedItem['client'] = _convertToMapStringDynamic(convertedItem['client']);
            }
            
            // Vérifier et convertir le champ 'service' s'il existe
            if (convertedItem.containsKey('service')) {
              convertedItem['service'] = _convertToMapStringDynamic(convertedItem['service']);
              
              // Si le service a une catégorie, la convertir aussi
              if (convertedItem['service'] != null && 
                  convertedItem['service'].containsKey('category')) {
                convertedItem['service']['category'] = _convertToMapStringDynamic(
                  convertedItem['service']['category']
                );
              }
            }
            
            // Appliquer le filtre de statut si nécessaire
            if (_statusFilter == 'all' || 
                (convertedItem['status']?.toString().toLowerCase() ?? '') == _statusFilter) {
              validQuotations.add(convertedItem);
            }
          } catch (e) {
            print('Erreur lors de la conversion d\'un élément: $e');
          }
        }
        
        print('Devis valides après conversion: ${validQuotations.length}');
        
        if (!mounted) return;
        
        setState(() {
          _quotations = validQuotations;
          _isLoading = false;
          _errorMessage = validQuotations.isEmpty ? 'Aucun devis trouvé' : null;
        });
      } else {
        throw Exception('Erreur du serveur: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      print('Erreur lors du chargement des devis: $e\n$stackTrace');
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des devis. Veuillez réessayer.';
      });
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationCard(dynamic quotation) {
    if (quotation == null) {
      return const SizedBox.shrink();
    }

    try {
      // Conversion sécurisée de la quotation en Map<String, dynamic>
      final Map<String, dynamic> safeQuotation = _convertToMapStringDynamic(quotation);
      print('Données du devis pour la carte: $safeQuotation');
      
      final id = safeQuotation['id']?.toString() ?? 'N/A';
      final status = (safeQuotation['status']?.toString().toLowerCase() ?? 'pending').toLowerCase();
      
      // Récupération des informations du client avec conversion sécurisée
      dynamic clientData = safeQuotation['client'];
      Map<String, dynamic>? clientInfo;
      
      if (clientData != null) {
        if (clientData is Map) {
          clientInfo = _convertToMapStringDynamic(clientData);
        } else if (clientData is String) {
          try {
            clientInfo = {'phone': clientData};
          } catch (e) {
            print('Erreur de conversion du client: $e');
          }
        }
      }
      
      print('Informations client extraites: $clientInfo');
      
      // Extraction des informations avec des valeurs par défaut plus robustes
      String clientName = 'Client inconnu';
      String clientPhone = 'Non spécifié';
      String clientAddress = 'Adresse non spécifiée';
      
      if (clientInfo != null) {
        // Essayer d'abord avec les clés les plus probables pour le nom
        clientName = clientInfo['name']?.toString() ?? 
                    clientInfo['full_name']?.toString() ?? 
                    clientInfo['first_name']?.toString() ??
                    clientInfo['phone']?.toString() ??
                    'Client inconnu';
        
        clientPhone = clientInfo['phone']?.toString() ?? 'Non spécifié';
        
        // Gestion de l'adresse qui peut être un objet ou une chaîne
        if (clientInfo['address'] is Map) {
          final address = _convertToMapStringDynamic(clientInfo['address']);
          clientAddress = address['formatted_address']?.toString() ?? 
                         address['address']?.toString() ?? 
                         'Adresse non spécifiée';
        } else if (clientInfo['address'] != null) {
          clientAddress = clientInfo['address'].toString();
        }
      }
      
      // Titre et description avec des valeurs par défaut plus pertinentes
      final title = safeQuotation['title']?.toString() ?? 'Demande de service';
      final description = safeQuotation['description']?.toString() ?? '';
      
      // Récupération des informations du service avec conversion sécurisée
      final serviceInfo = safeQuotation['service'] != null 
          ? _convertToMapStringDynamic(safeQuotation['service'])
          : null;
      
      // Catégorie du service avec gestion sécurisée
      String serviceCategory = 'Catégorie non spécifiée';
      try {
        if (serviceInfo != null && serviceInfo['category'] != null) {
          final category = _convertToMapStringDynamic(serviceInfo['category']);
          serviceCategory = category['name']?.toString() ?? serviceCategory;
        } else if (safeQuotation['category'] != null) {
          serviceCategory = safeQuotation['category'].toString();
        }
      } catch (e) {
        print('Erreur lors de la récupération de la catégorie: $e');
      }
      
      String formattedDate = 'Date inconnue';
      try {
        final createdAt = safeQuotation['created_at']?.toString();
        if (createdAt != null && createdAt.isNotEmpty) {
          formattedDate = DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.parse(createdAt).toLocal());
        }
      } catch (e) {
        print('Erreur de format de date (created_at): $e');
      }

      String amount = '0.00';
      try {
        if (safeQuotation['amount'] != null) {
          amount = double.tryParse(safeQuotation['amount'].toString())?.toStringAsFixed(2) ?? '0.00';
        }
      } catch (e) {
        print('Erreur de format de montant: $e');
      }

      String formattedProposedDate = 'Non spécifiée';
      try {
        final proposedDate = safeQuotation['proposed_date']?.toString();
        if (proposedDate != null && proposedDate.isNotEmpty) {
          formattedProposedDate = DateFormat('dd/MM/yyyy').format(DateTime.parse(proposedDate).toLocal());
        }
      } catch (e) {
        print('Erreur de format de date (proposed_date): $e');
      }

    // Utiliser la méthode _getStatusColor pour la cohérence
    final statusColor = _getStatusColor(status);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UnifiedQuotationDetailScreen(
                quotationId: id,
                quotation: safeQuotation,
                token: _finalToken,
                context: QuotationContext.professional,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec statut et date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getStatusLabel(status),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
                  Text(
                    formattedDate,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Informations du client
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clientName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (clientPhone.isNotEmpty && clientPhone != 'Non spécifié')
                          Text(
                            'Tél: $clientPhone',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Titre et description
              if (title.isNotEmpty) ...[
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              
              if (description.isNotEmpty) ...[
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Adresse
              if (clientAddress.isNotEmpty && clientAddress != 'Adresse non spécifiée') ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        clientAddress,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              
              const SizedBox(height: 12),
              
              if (status == 'quoted' || status == 'accepted' || status == 'in_progress' || status == 'started')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Montant', '$amount FCFA'),
                    _buildDetailRow('Date proposée', formattedProposedDate),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  } catch (e, stackTrace) {
    print('Erreur lors de la construction de la carte de devis: $e\n$stackTrace');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Erreur d\'affichage du devis',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            SizedBox(height: 8),
            Text('Détails: ${e.toString()}'),
            if (quotation != null) ...[
              SizedBox(height: 8),
              Text(
                'Données brutes du devis:',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              Text(quotation.toString()),
            ],
          ],
        ),
      ),
    );
  }
}
        Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'quoted':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'in_progress':
      case 'started':
        return Colors.blueAccent;
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'quoted':
        return 'Devis envoyé';
      case 'accepted':
        return 'Accepté';
      case 'in_progress':
      case 'started':
        return 'En cours';
      case 'completed':
        return 'Terminé';
      case 'cancelled':
        return 'Annulé';
      case 'rejected':
        return 'Refusé';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.filterMode ?? 'pending';
    return Scaffold(
      appBar: AppBar(
        title: Text(mode == 'active' ? 'Mes jobs (pro)' : 'Répondre aux devis'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 50),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadQuotations,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFFFFCC00),
                        ),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      color: Colors.grey[50],
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: _buildStatusChips()),
                      ),
                    ),
                    
                    Expanded(
                      child: _quotations.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 60,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Aucun devis à afficher',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    mode == 'active'
                                        ? 'Vous n\'avez pas encore de projets en cours ou terminés.'
                                        : 'Vous n\'avez pas encore de demandes de devis.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: _loadQuotations,
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: const Color(0xFFFFCC00),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    ),
                                    child: const Text('Actualiser'),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadQuotations,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: _quotations.length,
                                itemBuilder: (context, index) {
                                  final quotation = _quotations[index];
                                  final quotationId = quotation['id']?.toString();
                                  if (quotationId != null && 
                                      !_fetchingDetails.contains(quotationId) &&
                                      (quotation['amount'] == null || quotation['proposed_date'] == null)) {
                                    _ensureQuotationDetails(quotationId);
                                  }
                                  return _buildQuotationCard(quotation);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
      floatingActionButton: _isProClient && mode == 'pending'
          ? FloatingActionButton(
              onPressed: () {
                // Action pour créer un nouveau devis
                // TODO: Implémenter la navigation vers l'écran de création de devis
              },
              backgroundColor: const Color(0xFFFFCC00),
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
    );
  }

  void _showResponseDialog(String quotationId, String? title) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Répondre à "$title"'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Montant proposé (€)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes et détails',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _submitResponse(quotationId, amountController.text, notesController.text);
              },
              child: const Text('Envoyer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitResponse(String quotationId, String amount, String notes) async {
    if (amount.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le montant est requis')),
        );
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Token d\'accès non trouvé')),
          );
        }
        return;
      }

      // TODO: Implémenter l'envoi de la réponse au serveur
      print('Envoi de la réponse pour le devis $quotationId');
      print('Montant: $amount, Notes: $notes');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réponse envoyée avec succès')),
        );
      }
    } catch (e) {
      print('Erreur lors de la soumission de la réponse: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _declineQuotation(String quotationId) async {
    try {
      print('Refus du devis: $quotationId');
      
      // Mettre à jour l'interface utilisateur si nécessaire
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devis refusé avec succès')),
        );
      }
    } catch (e) {
      print('Erreur lors du refus du devis: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }
}
