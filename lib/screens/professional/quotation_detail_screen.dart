import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';

class QuotationDetailScreen extends StatefulWidget {
  final String quotationId;
  final Map<String, dynamic> quotation;
  final String token;

  const QuotationDetailScreen({
    Key? key,
    required this.quotationId,
    required this.quotation,
    required this.token,
  }) : super(key: key);

  @override
  _QuotationDetailScreenState createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends State<QuotationDetailScreen> {
  final AuthService _authService = AuthService(baseUrl: 'http://10.0.2.2:8000');
  bool _isLoading = false;
  String _responseMessage = '';
  double _amount = 0.0;
  DateTime? _proposedDate;
  final TextEditingController _responseController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  @override
  void dispose() {
    _responseController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _respondToQuotation(String status) async {
    // Validation des données selon l'API
    if (status == 'accepted' && _amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir un montant valide pour accepter le devis'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_responseMessage.isEmpty && status == 'accepted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir un message de réponse'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? widget.token;

      // Préparation des données selon l'API
      Map<String, dynamic> requestData = {};

      if (status == 'accepted') {
        requestData = {
          'amount': _amount,
          'professional_notes': _responseMessage,
          'proposed_date': _proposedDate?.toIso8601String().split('T')[0] ?? DateTime.now().add(Duration(days: 7)).toIso8601String().split('T')[0], // Date par défaut dans 7 jours
          'professional_id': widget.quotation['professional']?['id'] ?? widget.quotation['professional_id'], // ID du professionnel
          'description': widget.quotation['description'], // Description du travail
        };
      } else if (status == 'rejected') {
        requestData = {
          'professional_notes': _responseMessage.isNotEmpty ? _responseMessage : 'Demande refusée par le professionnel',
          'professional_id': widget.quotation['professional']?['id'] ?? widget.quotation['professional_id'],
          'description': widget.quotation['description'],
        };
      }

      print('Données d\'envoi: $requestData');

      final response = await http.put(
        Uri.parse('${_authService.effectiveBaseUrl}/api/quotations/${widget.quotationId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestData),
      );

      print('Réponse serveur (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Réponse ${status == 'accepted' ? 'd\'acceptation' : 'de refus'} envoyée avec succès'),
              backgroundColor: Colors.green,
            ),
          );

          // Revenir à la liste des devis
          Navigator.of(context).pop();
        } else {
          throw Exception('Réponse inattendue du serveur');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Token d\'authentification invalide');
      } else if (response.statusCode == 403) {
        throw Exception('Vous n\'êtes pas autorisé à répondre à ce devis');
      } else if (response.statusCode == 422) {
        final errorData = json.decode(response.body);
        throw Exception('Données invalides: ${errorData['message'] ?? 'Vérifiez les champs'}');
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors de l\'envoi de la réponse: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4CAF50)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Détails du devis',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informations du client
            _buildClientInfo(),

            const SizedBox(height: 24),

            // Détails de la demande
            _buildQuotationDetails(),

            const SizedBox(height: 32),

            // Section de réponse (seulement si en attente)
            if (widget.quotation['status'] == 'pending') ...[
              Text(
                'Votre réponse',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 16),

              // Champ de montant (obligatoire pour acceptation)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: TextField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Montant du devis (FCFA) *',
                    hintText: 'Ex: 2500.00',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(20),
                    labelStyle: GoogleFonts.poppins(
                      color: const Color(0xFF4CAF50),
                      fontWeight: FontWeight.w500,
                    ),
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey[400],
                    ),
                    prefixText: 'FCFA ',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.poppins(fontSize: 16),
                  onChanged: (value) {
                    setState(() {
                      _amount = double.tryParse(value) ?? 0.0;
                    });
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Champ de message
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: TextField(
                  controller: _responseController,
                  decoration: InputDecoration(
                    labelText: 'Message de réponse',
                    hintText: 'Décrivez votre réponse, disponibilité, tarifs, etc...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(20),
                    labelStyle: GoogleFonts.poppins(
                      color: const Color(0xFF4CAF50),
                      fontWeight: FontWeight.w500,
                    ),
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey[400],
                    ),
                  ),
                  maxLines: 5,
                  style: GoogleFonts.poppins(fontSize: 16),
                  onChanged: (value) {
                    setState(() {
                      _responseMessage = value;
                    });
                  },
                ),
              ),

              const SizedBox(height: 32),

              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading || _amount <= 0 ? null : () => _respondToQuotation('accepted'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline),
                                const SizedBox(width: 8),
                                Text(
                                  'Accepter',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => _respondToQuotation('rejected'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cancel_outlined, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            'Refuser',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Si déjà répondu, afficher le statut
            if (widget.quotation['status'] != 'pending') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getStatusColor(widget.quotation['status']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor(widget.quotation['status']),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getStatusIcon(widget.quotation['status']),
                          color: _getStatusColor(widget.quotation['status']),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Statut: ${_getStatusText(widget.quotation['status'])}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(widget.quotation['status']),
                          ),
                        ),
                      ],
                    ),
                    if (widget.quotation['amount'] != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Montant: ${widget.quotation['amount']} FCFA',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                    if (widget.quotation['professional_notes'] != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Votre réponse:',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.quotation['professional_notes'],
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClientInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4CAF50).withOpacity(0.1),
            const Color(0xFF4CAF50).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations du client',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  border: Border.all(
                    color: const Color(0xFF4CAF50),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF4CAF50),
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (widget.quotation['client']?['first_name'] ?? '') + ' ' + (widget.quotation['client']?['last_name'] ?? ''),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.quotation['client']?['email'] ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.quotation['client']?['phone'] != null)
                      InkWell(
                        onTap: () => _launchPhone(widget.quotation['client']?['phone'] ?? ''),
                        child: Row(
                          children: [
                            const Icon(Icons.phone, size: 16, color: Color(0xFF4CAF50)),
                            const SizedBox(width: 4),
                            Text(
                              widget.quotation['client']['phone'],
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: const Color(0xFF4CAF50),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Détails de la demande',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 20),

          // Description
          _buildDetailItem(
            'Description',
            widget.quotation['description'] ?? 'Non spécifiée',
            Icons.description,
          ),

          const SizedBox(height: 16),

          // Date souhaitée
          _buildDetailItem(
            'Date souhaitée',
            widget.quotation['proposed_date'] ?? 'Non spécifiée',
            Icons.calendar_today,
          ),

          const SizedBox(height: 16),

          // Montant (si spécifié)
          if (widget.quotation['amount'] != null)
            _buildDetailItem(
              'Budget proposé',
              '${widget.quotation['amount']} FCFA',
              Icons.attach_money,
              valueColor: const Color(0xFF4CAF50),
            ),

          const SizedBox(height: 16),

          // Pièces jointes
          if (widget.quotation['attachments'] != null && (widget.quotation['attachments'] as List).isNotEmpty) ...[
            Text(
              'Pièces jointes',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ...widget.quotation['attachments'].map<Widget>((attachment) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      attachment['original_name'] ?? 'Fichier',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ),
                  Text(
                    '${(attachment['size'] / 1024).toStringAsFixed(1)} KB',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF4CAF50),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'expired':
        return Icons.timer_off;
      default:
        return Icons.info;
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
      case 'expired':
        return 'Expiré';
      default:
        return status;
    }
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir le téléphone'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
