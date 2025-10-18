import 'dart:convert';
import 'package:batilink_mobile_app/screens/client/client_dashboard_screen.dart';
import 'package:batilink_mobile_app/screens/client/client_profile_screen.dart';
import 'package:batilink_mobile_app/screens/client/professional_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ClientCompletedQuotationsScreen extends StatefulWidget {
  final String? token;
  final Map<String, dynamic>? userData;

  const ClientCompletedQuotationsScreen({
    Key? key,
    this.token,
    this.userData,
  }) : super(key: key);

  @override
  _ClientCompletedQuotationsScreenState createState() => _ClientCompletedQuotationsScreenState();
}

class _ClientCompletedQuotationsScreenState extends State<ClientCompletedQuotationsScreen> {
  List<dynamic> _filteredQuotations = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _token = '';
  int _selectedIndex = 2; // Index pour l'onglet "Mes devis"

  void _onNavigationTap(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0: // Accueil
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
      case 2: // Mes devis (page actuelle)
        break;
      case 3: // Profil
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
        Uri.parse('http://10.0.2.2:8000/api/quotations'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final allQuotations = data['data'] ?? [];

        // Filtrer les devis avec statuts "completed" et "cancelled"
        final filteredQuotations = allQuotations.where((quotation) {
          final status = quotation['status'].toString().toLowerCase();
          return status == 'completed' || status == 'cancelled' || status == 'annulé';
        }).toList();

        setState(() {
          _filteredQuotations = filteredQuotations;
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
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Terminé';
      case 'cancelled':
      case 'annulé':
        return 'Annulé';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'annulé':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun devis terminé',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les devis terminés ou annulés apparaîtront ici',
            style: GoogleFonts.poppins(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationCard(dynamic quotation) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                      color: const Color(0xFF4CAF50),
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
      if (!avatarUrl.startsWith('http://') && !avatarUrl.startsWith('https://')) {
        if (avatarUrl.startsWith('/storage/') || avatarUrl.startsWith('storage/')) {
          final cleanPath = avatarUrl.startsWith('/') ? avatarUrl.substring(1) : avatarUrl;
          avatarUrl = 'http://10.0.2.2:8000/$cleanPath';
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
                      color: const Color(0xFF4CAF50),
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
                  color: const Color(0xFF4CAF50),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mes devis terminés',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4CAF50),
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
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadQuotations,
                        child: Text('Réessayer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                )
              : _filteredQuotations.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadQuotations,
                      color: const Color(0xFF4CAF50),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredQuotations.length,
                        itemBuilder: (context, index) {
                          final quotation = _filteredQuotations[index];
                          return _buildQuotationCard(quotation);
                        },
                      ),
                    ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavigationTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4CAF50),
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
}
