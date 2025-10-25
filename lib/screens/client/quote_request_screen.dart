import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class QuoteRequestScreen extends StatefulWidget {
  final String professionalId;
  final String professionalName;
  final String professionalJob;
  final String? token;
  final Map<String, dynamic>? userData;

  const QuoteRequestScreen({
    Key? key,
    required this.professionalId,
    required this.professionalName,
    required this.professionalJob,
    this.token,
    this.userData,
  }) : super(key: key);

  @override
  _QuoteRequestScreenState createState() => _QuoteRequestScreenState();
}

class _QuoteRequestScreenState extends State<QuoteRequestScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  List<File> _attachments = [];
  bool _isSubmitting = false;

  // Variables d'état pour les données du professionnel
  Map<String, dynamic>? _professionalData;
  bool _isLoadingProfessional = false;

  @override
  void initState() {
    super.initState();
    _loadProfessionalData();
  }

  Future<void> _loadProfessionalData() async {
    if (widget.professionalId.isEmpty) return;

    setState(() {
      _isLoadingProfessional = true;
    });

    try {
      final token = widget.token;
      if (token == null || token.isEmpty) {
        setState(() {
          _isLoadingProfessional = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/professionals/${widget.professionalId}'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _professionalData = data['data'];
          _isLoadingProfessional = false;
        });
      } else {
        setState(() {
          _isLoadingProfessional = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingProfessional = false;
      });
    }
  }

  Widget _getProfessionalPhoto() {
    // Si on charge les données du professionnel
    if (_isLoadingProfessional) {
      return const SizedBox(
        width: 70,
        height: 70,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFFFFCC00),
        ),
      );
    }

    // Essaie d'extraire l'URL de la photo depuis les données du professionnel
    String? avatarUrl;

    if (_professionalData != null) {
      // Essaie profile_photo.url d'abord (nouvelle structure)
      if (_professionalData!['profile_photo'] is Map<String, dynamic>) {
        avatarUrl = _professionalData!['profile_photo']['url'];
      }

      // Essaie avatar_url ensuite (ancienne structure)
      if (avatarUrl == null || avatarUrl.isEmpty) {
        avatarUrl = _professionalData!['avatar_url'];
      }

      // Essaie user.profile_photo_url
      if (avatarUrl == null || avatarUrl.isEmpty) {
        avatarUrl = _professionalData!['user']?['profile_photo_url'];
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
    }

    return avatarUrl != null && avatarUrl.isNotEmpty
        ? ClipOval(
            child: CachedNetworkImage(
              imageUrl: avatarUrl,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFCC00).withOpacity(0.15),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFFCC00),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFCC00).withOpacity(0.15),
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFFFFCC00),
                  size: 35,
                ),
              ),
            ),
          )
        : Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFCC00).withOpacity(0.15),
            ),
            child: const Icon(
              Icons.person,
              color: Color(0xFFFFCC00),
              size: 35,
            ),
          );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFFCC00),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _addAttachment() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      print('Fichier sélectionné: ${file.path}');
      print('Taille du fichier sélectionné: ${await file.length()} bytes');

      setState(() {
        _attachments.add(file);
      });
      print('Nombre total de pièces jointes: ${_attachments.length}');
    } else {
      print('Aucun fichier sélectionné');
    }
  }

  Future<void> _submitQuoteRequest() async {
    // Fonction d'envoi de demande de devis avec logs de débogage complets
    // pour diagnostiquer les problèmes d'envoi côté serveur
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir une description'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Utiliser le token passé en paramètre au lieu de SharedPreferences
      final token = widget.token;

      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentification requise. Veuillez vous reconnecter.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print('=== DEBUG ENVOI DEVIS ===');
      print('Token utilisé: ${token.substring(0, 20)}...');
      print('Professional ID: ${widget.professionalId}');
      print('Description: ${_descriptionController.text.trim()}');
      print('Date proposée: ${_selectedDate.toIso8601String().split('T')[0]}');
      print('Nombre de pièces jointes: ${_attachments.length}');

      // Créer la requête multipart pour supporter les pièces jointes
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:8000/api/quotations'),
      );

      // Ajouter les headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Ajouter les champs de formulaire
      request.fields['professional_id'] = widget.professionalId;
      request.fields['description'] = _descriptionController.text.trim();
      request.fields['proposed_date'] = _selectedDate.toIso8601String().split('T')[0];

      // Ajouter les pièces jointes
      for (int i = 0; i < _attachments.length; i++) {
        final file = _attachments[i];
        print('Ajout de la pièce jointe ${i + 1}: ${file.path}');
        print('Taille du fichier: ${await file.length()} bytes');
        final multipartFile = await http.MultipartFile.fromPath(
          'attachments[$i]',
          file.path,
        );
        print('Taille du fichier multipart: ${multipartFile.length} bytes');
        request.files.add(multipartFile);
      }

      print('Envoi de la requête à: ${request.url}');
      print('Headers: ${request.headers}');
      print('Fields: ${request.fields}');
      print('Nombre de fichiers: ${request.files.length}');

      // Envoyer la requête
      final response = await request.send();

      print('=== RÉPONSE REÇUE ===');
      print('Status Code: ${response.statusCode}');
      print('Headers: ${response.headers}');

      if (response.statusCode == 201) {
        // Succès - afficher les détails
        final responseData = await response.stream.bytesToString();
        print('Corps de la réponse succès: $responseData');
        final data = json.decode(responseData);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => QuoteSuccessScreen(
                quoteData: data['data'],
                token: widget.token,
                userData: widget.userData,
              ),
            ),
          );
        }
      } else {
        final responseData = await response.stream.bytesToString();
        print('Corps de la réponse erreur: $responseData');

        try {
          final error = json.decode(responseData);
          print('Erreur décodée: $error');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur ${response.statusCode}: ${error['message'] ?? 'Erreur lors de l\'envoi'}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } catch (jsonError) {
          print('Erreur de décodage JSON: $jsonError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur ${response.statusCode}: Réponse serveur invalide'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Exception lors de l\'envoi de la demande: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'envoi de la demande'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFFFCC00),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A5F)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Demande de devis',
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
            // Informations du professionnel
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E3A5F).withValues(),
                    const Color(0xFF1E3A5F).withValues(),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFFCC00).withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFCC00).withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFCC00).withOpacity(0.15),
                      border: Border.all(
                        color: const Color(0xFFFFCC00),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFCC00).withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFCC00).withOpacity(0.15),
                        border: Border.all(
                          color: const Color(0xFFFFCC00),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFCC00).withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _getProfessionalPhoto(),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.professionalName,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFFCC00),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFCC00).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFFFCC00),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.professionalJob,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: const Color(0xFFFFCC00),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Formulaire
            Text(
              'Détails de votre demande',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 24),

            // Description
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF1E3A5F).withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A5F).withValues(),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description du travail *',
                  hintText: 'Décrivez en détail ce dont vous avez besoin...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: const Color(0xFFFFCC00).withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: Color(0xFFFFCC00),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(24),
                  labelStyle: GoogleFonts.poppins(
                    color: const Color(0xFFFFCC00),
                    fontWeight: FontWeight.w600,
                  ),
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 5,
                style: GoogleFonts.poppins(fontSize: 16),
                textInputAction: TextInputAction.next,
              ),
            ),

            const SizedBox(height: 20),

            // Date souhaitée
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFFCC00).withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFCC00).withOpacity(0.08),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFCC00).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFCC00).withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.calendar_today,
                        color: Color(0xFFFFCC00),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date souhaitée',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFCC00).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        size: 18,
                        color: Color(0xFFFFCC00),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Pièces jointes
            Text(
              'Pièces jointes (optionnel)',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 16),

            // Liste des pièces jointes
            if (_attachments.isNotEmpty) ...[
              ..._attachments.map((file) => Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFCC00).withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFCC00).withOpacity(0.08),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFCC00).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFCC00).withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.attach_file,
                        color: Color(0xFFFFCC00),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pièce jointe',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            file.path.split('/').last,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _attachments.remove(file);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              )),
            ],

            // Bouton ajouter pièce jointe
            Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFFFFCC00).withOpacity(0.1),
                    const Color(0xFFFFCC00).withOpacity(0.05),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFFFCC00).withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFCC00).withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: OutlinedButton.icon(
                onPressed: _addAttachment,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFCC00).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: Color(0xFFFFCC00),
                    size: 20,
                  ),
                ),
                label: Text(
                  _attachments.isEmpty ? 'Ajouter des pièces jointes' : 'Ajouter une autre pièce jointe',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFFCC00),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFFFCC00), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Bouton d'envoi
            Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF1E3A5F),
                    const Color(0xFF1E3A5F).withValues(),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A5F).withValues(),
                    spreadRadius: 3,
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitQuoteRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isSubmitting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Envoi en cours...',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Envoyer la demande',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Note
            Text(
              '* Champs obligatoires',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class QuoteSuccessScreen extends StatelessWidget {
  final Map<String, dynamic> quoteData;
  final String? token;
  final Map<String, dynamic>? userData;

  const QuoteSuccessScreen({
    Key? key,
    required this.quoteData,
    this.token,
    this.userData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Demande envoyée',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFFFFCC00),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message de succès
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E3A5F).withValues(),
                    const Color(0xFF1E3A5F).withValues(),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF1E3A5F).withValues(),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFCC00).withOpacity(0.1),
                    spreadRadius: 3,
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFCC00).withOpacity(0.15),
                      border: Border.all(
                        color: const Color(0xFFFFCC00),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFCC00).withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      size: 60,
                      color: Color(0xFFFFCC00),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Demande envoyée avec succès !',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCC00).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Le professionnel va examiner votre demande et vous répondre prochainement.',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: const Color(0xFFFFCC00).withValues(),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Détails de la demande
            Text(
              'Récapitulatif de votre demande',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 16),

            // Informations du professionnel
            Card(
              elevation: 4,
              shadowColor: const Color(0xFF1E3A5F).withValues(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: const Color(0xFF1E3A5F).withValues(),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F).withValues(),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFFFFCC00),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Professionnel',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E3A5F),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      quoteData['professional']['company_name'] ?? 'N/A',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quoteData['professional']['job_title'] ?? 'N/A',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Description
            Card(
              elevation: 4,
              shadowColor: const Color(0xFF1E3A5F).withValues(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: const Color(0xFF1E3A5F).withValues(),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F).withValues(),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.description,
                            color: Color(0xFFFFCC00),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Description',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E3A5F),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      quoteData['description'] ?? 'N/A',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Date proposée
            Card(
              elevation: 4,
              shadowColor: const Color(0xFF1E3A5F).withValues(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: const Color(0xFF1E3A5F).withValues(),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F).withValues(),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E3A5F).withValues(),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.calendar_today,
                        color: Color(0xFFFFCC00),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date souhaitée',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E3A5F),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            quoteData['proposed_date'] ?? 'N/A',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Pièces jointes
            if (quoteData['attachments'] != null && (quoteData['attachments'] as List).isNotEmpty) ...[
              Card(
                elevation: 4,
                shadowColor: const Color(0xFFFFCC00).withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: const Color(0xFFFFCC00).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFCC00).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.attach_file,
                              color: Color(0xFFFFCC00),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Pièces jointes',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFFCC00),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...quoteData['attachments'].map<Widget>((attachment) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFCC00).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.insert_drive_file,
                                color: Color(0xFFFFCC00),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                attachment['original_name'] ?? 'Fichier',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.grey[100]!,
                          Colors.grey[200]!,
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFFFCC00).withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFCC00).withOpacity(0.05),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Retour à la page précédente
                        Navigator.of(context).pop(); // Retour à la liste des professionnels
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(
                          color: Color(0xFFFFCC00),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Retour à la recherche',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFFCC00),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFF1E3A5F).withValues(),
                          const Color(0xFF1E3A5F).withValues(),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A5F).withValues(),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        // Naviguer vers la page des demandes de devis avec les paramètres
                        Navigator.pushNamed(
                          context,
                          '/client/quotations',
                          arguments: {
                            'token': token ?? '',
                            'userData': userData ?? {},
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Voir demandes',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
