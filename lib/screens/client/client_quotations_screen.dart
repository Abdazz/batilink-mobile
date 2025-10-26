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
  final Set<String> _fetchingDetails = <String>{};
  String _statusFilter = 'all'; // all, pending, quoted, accepted, in_progress, completed, cancelled, rejected

  @override
  void initState() {
    super.initState();
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
    // Récupérer le token depuis SharedPreferences comme secours
    final prefs = await SharedPreferences.getInstance();
    final tokenFromPrefs = prefs.getString('access_token') ?? '';

    // Utiliser le token passé en argument, ou celui de SharedPreferences comme secours
    final finalToken = widget.token?.isNotEmpty == true ? widget.token! : tokenFromPrefs;

    if (finalToken.isEmpty) {
      setState(() {
        _errorMessage = 'Token d\'authentification manquant';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _token = finalToken;
    });

    _loadQuotations();
  }

  Future<void> _loadQuotations() async {
    try {
      // Utiliser le token récupéré depuis SharedPreferences comme secours
      final token = _token;

      if (token.isEmpty) {
        setState(() {
          _errorMessage = 'Token d\'authentification manquant';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/quotations'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _quotations = data['data'] ?? [];
          _isLoading = false;
          _errorMessage = null;
        });
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
