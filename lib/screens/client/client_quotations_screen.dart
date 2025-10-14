import 'dart:convert';
import 'package:batilink_mobile_app/screens/client/professional_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ClientQuotationsScreen extends StatefulWidget {
  const ClientQuotationsScreen({Key? key}) : super(key: key);

  @override
  _ClientQuotationsScreenState createState() => _ClientQuotationsScreenState();
}

class _ClientQuotationsScreenState extends State<ClientQuotationsScreen> {
  List<dynamic> _quotations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQuotations();
  }

  Future<void> _loadQuotations() async {
    try {
      print('🔍 DEBUG: Début du chargement des devis');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      print('🔍 DEBUG: Token récupéré depuis SharedPreferences: ${token != null ? 'Token présent (${token.length} caractères)' : 'Token NULL'}');

      if (token == null || token.isEmpty) {
        print('❌ DEBUG: Token manquant dans SharedPreferences');
        setState(() {
          _errorMessage = 'Token d\'authentification manquant';
          _isLoading = false;
        });
        return;
      }

      print('✅ DEBUG: Token valide trouvé, appel de l\'API...');
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/quotations'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('🔍 DEBUG: Réponse API reçue - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ DEBUG: Réponse API OK, données reçues: ${data.toString()}');
        setState(() {
          _quotations = data['data'] ?? [];
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        print('❌ DEBUG: Réponse API échouée - Status: ${response.statusCode}');
        final errorBody = await response.body;
        print('❌ DEBUG: Corps de l\'erreur: $errorBody');
        setState(() {
          _errorMessage = 'Erreur lors du chargement des devis';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ DEBUG: Exception attrapée: $e');
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
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    ],
                  ),
                )
              : _quotations.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadQuotations,
                      color: const Color(0xFF4CAF50),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _quotations.length,
                        itemBuilder: (context, index) {
                          final quotation = _quotations[index];
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
        backgroundColor: const Color(0xFF4CAF50),
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
              backgroundColor: const Color(0xFF4CAF50),
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
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // TODO: Naviguer vers les détails de la demande
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
                    CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      child: Text(
                        quotation['professional']['company_name'][0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF4CAF50),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
