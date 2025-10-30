import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../core/app_config.dart';

enum QuotationContext {
  professional,
  client,
}

class UnifiedQuotationDetailScreen extends StatefulWidget {
  final String quotationId;
  final Map<String, dynamic> quotation;
  final String token;
  final QuotationContext context;

  const UnifiedQuotationDetailScreen({
    super.key,
    required this.quotationId,
    required this.quotation,
    required this.token,
    required this.context,
  });

  @override
  _UnifiedQuotationDetailScreenState createState() => _UnifiedQuotationDetailScreenState();
}

class _UnifiedQuotationDetailScreenState extends State<UnifiedQuotationDetailScreen> {
  bool _isLoading = false;
  String _errorMessage = '';
  final ImagePicker _picker = ImagePicker();

  // Contrôleurs pour les formulaires
  final TextEditingController _startDescriptionController = TextEditingController();
  final TextEditingController _completionDescriptionController = TextEditingController();
  final TextEditingController _cancellationReasonController = TextEditingController();
  final TextEditingController _reviewCommentController = TextEditingController();
  final TextEditingController _materialsUsedController = TextEditingController();

  Map<String, dynamic>? _currentQuotation;

  DateTime _selectedStartDate = DateTime.now();
  DateTime _selectedCompletionDate = DateTime.now();
  DateTime _selectedCancellationDate = DateTime.now();

  double _reviewRating = 5.0;
  int _recommendationScore = 9;

  // Variables temporaires pour stocker les données des formulaires
  String? _tempStartDate;
  String? _tempStartDescription;
  int? _tempStartPhotosCount;

  String? _tempCompletionDate;
  String? _tempCompletionDescription;
  String? _tempMaterialsUsed;
  int? _tempCompletionPhotosCount;

  String? _tempCancellationDate;
  String? _tempCancellationReason;
  int? _tempCancellationPhotosCount;

  final List<File> _startPhotos = [];
  final List<File> _completionPhotos = [];
  final List<File> _cancellationPhotos = [];
  final List<File> _reviewPhotos = [];
  List<File> _acceptancePhotos = [];

  final TextEditingController _quoteAmountController = TextEditingController();
  final TextEditingController _quoteNotesController = TextEditingController();
  DateTime? _quoteProposedDate;

  bool _fileTooLarge(File f, int maxBytes) => f.lengthSync() > maxBytes;

  @override
  void initState() {
    super.initState();
    _currentQuotation = Map<String, dynamic>.from(widget.quotation);
  }

  Map<String, String>? _imageHeaders() {
    final t = widget.token;
    if (t.isNotEmpty) {
      return {'Authorization': 'Bearer $t'};
    }
    return null;
  }

  String _resolveMediaUrl(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.contains('via.placeholder.com') || raw.contains('placeholder')) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    // Toute URL relative: utiliser AppConfig.buildMediaUrl
    try {
      final path = raw.startsWith('/') ? raw : '/$raw';
      final full = AppConfig.buildMediaUrl(path);
      // Debug
      // ignore: avoid_print
      print('Resolved media URL: $raw -> $full');
      return full;
    } catch (_) {
      // Fallback ancien comportement storage
      if (raw.startsWith('/storage/') || raw.startsWith('storage/')) {
        final cleanPath = raw.startsWith('/') ? raw.substring(1) : raw;
        return '${AppConfig.baseUrl}/$cleanPath';
      }
      return raw;
    }
  }

  List<String> _extractPhotoUrls(dynamic source) {
    final List<String> urls = [];
    if (source == null) return urls;

    dynamic raw = source;
    
    // Handle direct proof_photos array from acceptance_proof
    if (raw is Map && raw.containsKey('proof_photos') && raw['proof_photos'] is List) {
      final proofPhotos = raw['proof_photos'] as List;
      for (final photo in proofPhotos) {
        if (photo is Map) {
          final url = photo['url']?.toString() ?? photo['path']?.toString();
          if (url != null && url.isNotEmpty) {
            urls.add(_resolveMediaUrl(url));
          }
        }
      }
      if (urls.isNotEmpty) return urls;
    }
    
    // Si string JSON
    if (raw is String) {
      final s = raw.trim();
      if (s.startsWith('[') && s.endsWith(']')) {
        try {
          final decoded = json.decode(s);
          raw = decoded;
        } catch (_) {
          // string non JSON: peut-être CSV
          final parts = s.split(',');
          for (final p in parts) {
            final u = _resolveMediaUrl(p.trim());
            if (u.isNotEmpty) urls.add(u);
          }
          return urls;
        }
      } else {
        // Single path string
        final u = _resolveMediaUrl(s);
        if (u.isNotEmpty) urls.add(u);
        return urls;
      }
    }

    // Si liste
    if (raw is List) {
      for (final item in raw) {
        if (item is String) {
          final u = _resolveMediaUrl(item);
          if (u.isNotEmpty) urls.add(u);
        } else if (item is Map) {
          final url = item['url']?.toString() ?? item['path']?.toString() ?? item['full_url']?.toString() ?? item['src']?.toString();
          if (url != null && url.isNotEmpty) {
            final u = _resolveMediaUrl(url);
            if (u.isNotEmpty) urls.add(u);
          }
        }
      }
      return urls;
    }

    // Si map, chercher différentes clés possibles
    if (raw is Map) {
      final keys = ['review_photos', 'proof_photos', 'start_photos', 'completion_photos', 'cancellation_photos', 'photos', 'images', 'files'];
      for (final k in keys) {
        if (raw[k] != null) {
          urls.addAll(_extractPhotoUrls(raw[k]));
        }
      }
      // Si map représente directement un fichier unique
      if (urls.isEmpty) {
        final u = _resolveMediaUrl(
          raw['url']?.toString() ?? raw['path']?.toString() ?? raw['full_url']?.toString() ?? raw['src']?.toString(),
        );
        if (u.isNotEmpty) urls.add(u);
      }
    }

    return urls;
  }

  void _clearTempData() {
    _tempStartDate = null;
    _tempStartDescription = null;
    _tempStartPhotosCount = null;

    _tempCompletionDate = null;
    _tempCompletionDescription = null;
    _tempMaterialsUsed = null;
    _tempCompletionPhotosCount = null;

    _tempCancellationDate = null;
    _tempCancellationReason = null;
    _tempCancellationPhotosCount = null;
  }

  Future<void> _refreshQuotation(String token) async {
    try {
      final resp = await ApiService.getWithToken('quotations/${widget.quotationId}', token: token);
      if (resp != null && resp['data'] != null) {
        setState(() {
          _currentQuotation = Map<String, dynamic>.from(resp['data']);
        });
      }
    } catch (e) {
      // On ignore l'erreur de rafraîchissement pour ne pas bloquer l'UX
      print('Erreur rafraîchissement quotation: $e');
    }
  }

  Future<void> _respondToQuotation(String status) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final q = _currentQuotation ?? widget.quotation;
      print('Tentative de réponse - Statut actuel du devis: ${q['status']}');
      print('ID du devis: ${widget.quotationId}');
      print('Contexte: ${widget.context}');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? prefs.getString('access_token') ?? widget.token;

      // Différentes logiques selon le contexte
      if (widget.context == QuotationContext.professional) {
        await _respondAsProfessional(status, token);
      } else {
        if (status == 'accepted') {
          // S'assurer que les boutons du popup ne sont pas désactivés
          if (_isLoading) {
            setState(() => _isLoading = false);
          }
          await _handleClientAcceptance(token);
        } else {
          await _respondAsClient(status, token);
        }
      }
    } catch (e) {
      print('Erreur lors de la réponse: $e');
      setState(() {
        _errorMessage = 'Erreur lors de la réponse: $e';
      });

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

  Future<void> _respondAsProfessional(String status, String token) async {
    if (status != 'accepted' && status != 'rejected') {
      throw Exception('Action non supportée pour le professionnel');
    }

    if (status == 'accepted') {
      // S'assurer que les boutons du popup ne sont pas désactivés
      if (_isLoading) {
        setState(() => _isLoading = false);
      }
      await _showQuoteDialog(token);
      return;
    }

    // Rejet simple (notes optionnelles)
    final url = Uri.parse('${AppConfig.baseUrl}/api/quotations/${widget.quotationId}');
    final q = _currentQuotation ?? widget.quotation;
    final professionalId = q['professional_id'] ?? q['professional']?['id'];
    final response = await http.put(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'professional_notes': 'Demande refusée par le professionnel',
        if (professionalId != null) 'professional_id': professionalId,
        if (q['description'] != null) 'description': q['description'],
        'status': 'rejected',
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      _showSuccessMessage('rejected');
      Navigator.of(context).pop(true);
    } else {
      throw Exception('Erreur serveur (${response.statusCode}): ${response.body}');
    }
  }

  Future<void> _showQuoteDialog(String token) async {
    _quoteAmountController.text = '';
    _quoteNotesController.text = '';
    _quoteProposedDate = null;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Proposer un devis', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _quoteAmountController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Montant (obligatoire)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _quoteNotesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (≤ 1000 caractères)',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 1000,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text('Date proposée (optionnel): ', style: GoogleFonts.poppins()),
                        TextButton(
                          onPressed: () async {
                            final now = DateTime.now();
                            final date = await showDatePicker(
                              context: context,
                              initialDate: now.add(const Duration(days: 1)),
                              firstDate: now.add(const Duration(days: 1)),
                              lastDate: now.add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() => _quoteProposedDate = date);
                            }
                          },
                          child: Text(
                            _quoteProposedDate != null
                                ? DateFormat('dd/MM/yyyy').format(_quoteProposedDate!)
                                : 'Choisir',
                            style: GoogleFonts.poppins(color: Colors.blue, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],

          
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Annuler', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final amountText = _quoteAmountController.text.trim().replaceAll(',', '.');
                          if (amountText.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Le montant est obligatoire'), backgroundColor: Colors.red),
                            );
                            return;
                          }
                          final amount = double.tryParse(amountText);
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Montant invalide'), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          Navigator.of(context).pop();
                          await _submitProfessionalQuote(token, amount: amount, notes: _quoteNotesController.text.trim(), proposedDate: _quoteProposedDate);
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: Text('Envoyer', style: GoogleFonts.poppins()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitProfessionalQuote(String token, {required double amount, String? notes, DateTime? proposedDate}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/quotations/${widget.quotationId}');
      final q = _currentQuotation ?? widget.quotation;
      final professionalId = q['professional_id'] ?? q['professional']?['id'];
      final payload = {
        'amount': amount,
        if (notes != null) 'professional_notes': notes,
        if (notes != null) 'notes': notes,
        if (proposedDate != null) 'proposed_date': DateFormat('yyyy-MM-dd').format(proposedDate),
        if (professionalId != null) 'professional_id': professionalId,
        if (q['description'] != null) 'description': q['description'],
        'status': 'quoted',
      };
      final response = await http.put(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(payload),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSuccessMessage('quoted');
        await _refreshQuotation(token);
        // Ne pas fermer l'écran de détails pour laisser voir les infos mises à jour
      } else {
        throw Exception('Erreur serveur (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erreur lors de l\'envoi du devis: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _respondAsClient(String status, String token) async {
    if (status == 'accepted') {
      // L'acceptation avec preuves est gérée par _handleClientAcceptance
      return;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fonctionnalité de refus côté client à implémenter'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _handleClientAcceptance(String token) async {
    final TextEditingController clientNotesController = TextEditingController(text: "Devis accepté via l'application mobile");
    _acceptancePhotos = [];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text('Accepter le devis', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: clientNotesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes du client (optionnel, ≤ 1000)',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 1000,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final photos = await _picker.pickMultiImage();
                      if (photos.isEmpty) return;
                      final added = <File>[];
                      for (final x in photos) {
                        final f = File(x.path);
                        if (_fileTooLarge(f, 5 * 1024 * 1024)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Chaque photo doit être ≤ 5 Mo'), backgroundColor: Colors.red),
                          );
                          continue;
                        }
                        added.add(f);
                      }
                      setState(() {
                        _acceptancePhotos.addAll(added);
                      });
                    },
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Ajouter des photos de preuve'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black),
                  ),
                  if (_acceptancePhotos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('${_acceptancePhotos.length} photo(s) sélectionnée(s)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Annuler', style: GoogleFonts.poppins())),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        Navigator.of(context).pop();
                        await _submitClientAcceptance(token, clientNotes: clientNotesController.text.trim());
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: Text('Confirmer', style: GoogleFonts.poppins()),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _submitClientAcceptance(String token, {String? clientNotes}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      if (_acceptancePhotos.isNotEmpty) {
        final request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/api/quotations/${widget.quotationId}/accept'));
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['acceptance_date'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
        if (clientNotes != null && clientNotes.isNotEmpty) request.fields['client_notes'] = clientNotes;
        for (int i = 0; i < _acceptancePhotos.length; i++) {
          final photo = _acceptancePhotos[i];
          final multipartFile = await http.MultipartFile.fromPath(
            'proof_photos[]',
            photo.path,
          );
          request.files.add(multipartFile);
        }
        final resp = await request.send();
        final body = await resp.stream.bytesToString();
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Devis accepté avec succès !'), backgroundColor: Colors.green));
          await _refreshQuotation(token);
          Navigator.of(context).pop(true);
        } else {
          throw Exception('Erreur serveur (${resp.statusCode}): $body');
        }
      } else {
        final response = await http.post(
          Uri.parse('${AppConfig.baseUrl}/api/quotations/${widget.quotationId}/accept'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'acceptance_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
            if (clientNotes != null && clientNotes.isNotEmpty) 'client_notes': clientNotes,
          }),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Devis accepté avec succès !'), backgroundColor: Colors.green));
          await _refreshQuotation(token);
          Navigator.of(context).pop(true);
        } else {
          throw Exception('Erreur serveur (${response.statusCode}): ${response.body}');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erreur lors de l\'acceptation: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showStartWorkDialog() async {
    _startDescriptionController.text = _tempStartDescription ?? 'Début des travaux de construction';

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Démarrer les travaux', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _startDescriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description du démarrage',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        setState(() {
                          _tempStartDescription = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Date de démarrage: ', style: GoogleFonts.poppins()),
                        TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedStartDate,
                              firstDate: DateTime.now().subtract(Duration(days: 30)),
                              lastDate: DateTime.now().add(Duration(days: 30)),
                            );
                            if (date != null) {
                              setState(() {
                                _selectedStartDate = date;
                                _tempStartDate = DateFormat('dd/MM/yyyy').format(date);
                              });
                            }
                          },
                          child: Text(
                            _tempStartDate ?? DateFormat('dd/MM/yyyy').format(_selectedStartDate),
                            style: GoogleFonts.poppins(color: Colors.blue, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final photos = await _picker.pickMultiImage();
                        if (photos.isEmpty) return;
                        final added = <File>[];
                        for (final x in photos) {
                          final f = File(x.path);
                          if (_fileTooLarge(f, 5 * 1024 * 1024)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Chaque photo doit être ≤ 5 Mo'), backgroundColor: Colors.red),
                            );
                            continue;
                          }
                          added.add(f);
                        }
                        setState(() {
                          _startPhotos.addAll(added);
                          _tempStartPhotosCount = _startPhotos.length;
                        });
                                            },
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Ajouter des photos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black,
                      ),
                    ),
                    if (_tempStartPhotosCount != null && _tempStartPhotosCount! > 0) ...[
                      const SizedBox(height: 8),
                      Text('$_tempStartPhotosCount photo(s) sélectionnée(s)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Annuler', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : () async {
                    Navigator.of(context).pop();
                    await _startWork();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                      : Text('Démarrer', style: GoogleFonts.poppins()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _startWork() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? widget.token;

      // Créer une requête multipart pour envoyer les fichiers
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/api/quotations/${widget.quotationId}/start'),
      );

      // Ajouter les headers d'autorisation
      request.headers['Authorization'] = 'Bearer $token';

      // Ajouter les données textuelles
      request.fields['start_date'] = DateFormat('yyyy-MM-dd').format(_selectedStartDate);
      request.fields['initial_description'] = _startDescriptionController.text;

      // Ajouter les photos
      for (int i = 0; i < _startPhotos.length; i++) {
        final photo = _startPhotos[i];
        final fileName = photo.path.split('/').last;

        final multipartFile = await http.MultipartFile.fromPath(
          'start_photos[$i]',
          photo.path,
          contentType: MediaType('image', fileName.split('.').last),
        );

        request.files.add(multipartFile);
      }

      print('Envoi de ${request.files.length} photo(s) de démarrage');
      print('Données textuelles: ${request.fields}');

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('Réponse démarrage (${response.statusCode}): $responseBody');

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);

        if (data['data'] != null || data['status'] == 'in_progress') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Travaux démarrés avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
          await _refreshQuotation(token);
          _clearTempData();
          Navigator.of(context).pop(true);
        } else {
          throw Exception('Réponse inattendue du serveur');
        }
      } else {
        final errorData = json.decode(responseBody);
        if (response.statusCode == 422) {
          throw Exception('Le devis doit être en attente pour pouvoir être démarré. ${errorData['message'] ?? ''}');
        } else if (response.statusCode == 403) {
          throw Exception('Vous n\'êtes pas autorisé à démarrer ce travail. Il se peut qu\'il ne vous appartienne pas.');
        } else {
          throw Exception('Erreur serveur: ${response.statusCode} - ${errorData['message'] ?? 'Erreur inconnue'}');
        }
      }
    } catch (e) {
      print('Erreur lors du démarrage: $e');
      setState(() {
        _errorMessage = 'Erreur lors du démarrage: $e';
      });

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

  Future<void> _showCompleteWorkDialog() async {
    _completionDescriptionController.text = _tempCompletionDescription ?? 'Travail terminé avec succès';
    _materialsUsedController.text = _tempMaterialsUsed ?? 'Matériaux utilisés selon devis';

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Terminer les travaux', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _completionDescriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description finale',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        setState(() {
                          _tempCompletionDescription = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _materialsUsedController,
                      decoration: const InputDecoration(
                        labelText: 'Matériaux utilisés',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onChanged: (value) {
                        setState(() {
                          _tempMaterialsUsed = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Date d\'achèvement: ', style: GoogleFonts.poppins()),
                        TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedCompletionDate,
                              firstDate: DateTime.now().subtract(Duration(days: 30)),
                              lastDate: DateTime.now().add(Duration(days: 30)),
                            );
                            if (date != null) {
                              setState(() {
                                _selectedCompletionDate = date;
                                _tempCompletionDate = DateFormat('dd/MM/yyyy').format(date);
                              });
                            }
                          },
                          child: Text(
                            _tempCompletionDate ?? DateFormat('dd/MM/yyyy').format(_selectedCompletionDate),
                            style: GoogleFonts.poppins(color: Colors.blue, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final photos = await _picker.pickMultiImage();
                        if (photos.isEmpty) return;
                        final added = <File>[];
                        for (final x in photos) {
                          final f = File(x.path);
                          if (_fileTooLarge(f, 5 * 1024 * 1024)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Chaque photo doit être ≤ 5 Mo'), backgroundColor: Colors.red),
                            );
                            continue;
                          }
                          added.add(f);
                        }
                        setState(() {
                          _completionPhotos.addAll(added);
                          _tempCompletionPhotosCount = _completionPhotos.length;
                        });
                                            },
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Ajouter des photos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black,
                      ),
                    ),
                    if (_tempCompletionPhotosCount != null && _tempCompletionPhotosCount! > 0) ...[
                      const SizedBox(height: 8),
                      Text('$_tempCompletionPhotosCount photo(s) sélectionnée(s)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Annuler', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : () async {
                    Navigator.of(context).pop();
                    await _completeWork();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                      : Text('Terminer', style: GoogleFonts.poppins()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _completeWork() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? widget.token;

      // Créer une requête multipart si on a des photos, sinon JSON
      http.MultipartRequest? request;

      if (_completionPhotos.isNotEmpty) {
        request = http.MultipartRequest(
          'POST',
          Uri.parse('${AppConfig.baseUrl}/api/quotations/${widget.quotationId}/complete'),
        );
        request.headers['Authorization'] = 'Bearer $token';

        // Ajouter les données textuelles
        request.fields['completion_date'] = DateFormat('yyyy-MM-dd').format(_selectedCompletionDate);
        request.fields['final_description'] = _completionDescriptionController.text;
        request.fields['materials_used'] = _materialsUsedController.text;

        // Ajouter les photos
        for (int i = 0; i < _completionPhotos.length; i++) {
          final photo = _completionPhotos[i];
          final fileName = photo.path.split('/').last;

          final multipartFile = await http.MultipartFile.fromPath(
            'completion_photos[$i]',
            photo.path,
            contentType: MediaType('image', fileName.split('.').last),
          );

          request.files.add(multipartFile);
        }
      } else {
        // Si pas de photos, utiliser une requête JSON normale
        final response = await http.post(
          Uri.parse('${AppConfig.baseUrl}/api/quotations/${widget.quotationId}/complete'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'completion_date': DateFormat('yyyy-MM-dd').format(_selectedCompletionDate),
            'final_description': _completionDescriptionController.text,
            'materials_used': _materialsUsedController.text,
          }),
        );

        final responseBody = response.body;
        print('Réponse achèvement (${response.statusCode}): $responseBody');

        if (response.statusCode == 200) {
          final data = json.decode(responseBody);

          if (data['data'] != null || data['status'] == 'completed') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Travaux terminés ! Vous pouvez maintenant laisser un avis.'),
                backgroundColor: Colors.green,
              ),
            );
            await _refreshQuotation(token);
            _clearTempData();
            Navigator.of(context).pop(true);
            return;
          } else {
            throw Exception('Réponse inattendue du serveur');
          }
        } else {
          final errorData = json.decode(responseBody);
          if (response.statusCode == 422) {
            throw Exception('Le devis doit être en cours pour pouvoir être terminé. ${errorData['message'] ?? ''}');
          } else if (response.statusCode == 403) {
            throw Exception('Vous n\'êtes pas autorisé à terminer ce travail. Il se peut qu\'il ne vous appartienne pas.');
          } else {
            throw Exception('Erreur serveur: ${response.statusCode} - ${errorData['message'] ?? 'Erreur inconnue'}');
          }
        }
      }

      print('Envoi de ${request.files.length} photo(s) d\'achèvement');
      print('Données textuelles: ${request.fields}');

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('Réponse achèvement (${response.statusCode}): $responseBody');

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);

        if (data['data'] != null || data['status'] == 'completed') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Travaux terminés ! Vous pouvez maintenant laisser un avis.'),
              backgroundColor: Colors.green,
            ),
          );
          await _refreshQuotation(token);
          _clearTempData();
          Navigator.of(context).pop(true);
        } else {
          throw Exception('Réponse inattendue du serveur');
        }
      } else {
        final errorData = json.decode(responseBody);
        if (response.statusCode == 422) {
          throw Exception('Le devis doit être en cours pour pouvoir être terminé. ${errorData['message'] ?? ''}');
        } else if (response.statusCode == 403) {
          throw Exception('Vous n\'êtes pas autorisé à terminer ce travail. Il se peut qu\'il ne vous appartienne pas.');
        } else {
          throw Exception('Erreur serveur: ${response.statusCode} - ${errorData['message'] ?? 'Erreur inconnue'}');
        }
      }
        } catch (e) {
      print('Erreur lors de l\'achèvement: $e');
      setState(() {
        _errorMessage = 'Erreur lors de l\'achèvement: $e';
      });

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

  Future<void> _showCancelDialog() async {
    _cancellationReasonController.text = _tempCancellationReason ?? 'Annulation demandée via l\'application mobile';

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Annuler le devis', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _cancellationReasonController,
                      decoration: const InputDecoration(
                        labelText: 'Raison de l\'annulation',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        setState(() {
                          _tempCancellationReason = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Date d\'annulation: ', style: GoogleFonts.poppins()),
                        TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedCancellationDate,
                              firstDate: DateTime.now().subtract(Duration(days: 30)),
                              lastDate: DateTime.now().add(Duration(days: 30)),
                            );
                            if (date != null) {
                              setState(() {
                                _selectedCancellationDate = date;
                                _tempCancellationDate = DateFormat('dd/MM/yyyy').format(date);
                              });
                            }
                          },
                          child: Text(
                            _tempCancellationDate ?? DateFormat('dd/MM/yyyy').format(_selectedCancellationDate),
                            style: GoogleFonts.poppins(color: Colors.blue, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final photos = await _picker.pickMultiImage();
                        if (photos.isEmpty) return;
                        final added = <File>[];
                        for (final x in photos) {
                          final f = File(x.path);
                          if (_fileTooLarge(f, 5 * 1024 * 1024)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Chaque justificatif doit être ≤ 5 Mo'), backgroundColor: Colors.red),
                            );
                            continue;
                          }
                          added.add(f);
                        }
                        setState(() {
                          _cancellationPhotos.addAll(added);
                          _tempCancellationPhotosCount = _cancellationPhotos.length;
                        });
                                            },
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Ajouter des justificatifs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black,
                      ),
                    ),
                    if (_tempCancellationPhotosCount != null && _tempCancellationPhotosCount! > 0) ...[
                      const SizedBox(height: 8),
                      Text('$_tempCancellationPhotosCount justificatif(s) ajouté(s)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Annuler', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : () async {
                    Navigator.of(context).pop();
                    await _cancelQuotation();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                      : Text('Confirmer l\'annulation', style: GoogleFonts.poppins()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cancelQuotation() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Envoi multipart si des preuves sont présentes, sinon JSON
      if (_cancellationPhotos.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token') ?? widget.token;

        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${AppConfig.baseUrl}/api/quotations/${widget.quotationId}/cancel'),
        );
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['cancellation_reason'] = _cancellationReasonController.text;
        request.fields['cancellation_date'] = DateFormat('yyyy-MM-dd').format(_selectedCancellationDate);

        for (int i = 0; i < _cancellationPhotos.length; i++) {
          final photo = _cancellationPhotos[i];
          final fileName = photo.path.split('/').last;
          final multipartFile = await http.MultipartFile.fromPath(
            'cancellation_proof[$i]',
            photo.path,
            contentType: MediaType('image', fileName.split('.').last),
          );
          request.files.add(multipartFile);
        }

        final resp = await request.send();
        final body = await resp.stream.bytesToString();
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Devis annulé avec succès.'), backgroundColor: Colors.orange));
          await _refreshQuotation(token);
          _clearTempData();
          Navigator.of(context).pop(true);
        } else {
          throw Exception('Erreur serveur (${resp.statusCode}): $body');
        }
      } else {
        final response = await ApiService.post(
          'quotations/${widget.quotationId}/cancel',
          data: {
            'cancellation_reason': _cancellationReasonController.text,
            'cancellation_date': DateFormat('yyyy-MM-dd').format(_selectedCancellationDate),
          },
        );
        if (response != null && (response['data'] != null || response['status'] == 'cancelled')) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Devis annulé avec succès.'), backgroundColor: Colors.orange));
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token') ?? widget.token;
          await _refreshQuotation(token);
          _clearTempData();
          Navigator.of(context).pop(true);
        } else {
          throw Exception('Réponse inattendue du serveur');
        }
      }
    } catch (e) {
      print('Erreur lors de l\'annulation: $e');
      setState(() {
        _errorMessage = 'Erreur lors de l\'annulation: $e';
      });

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

  Future<void> _showReviewDialog() async {
    _reviewCommentController.text = 'Excellent travail ! Le professionnel a été très professionnel et le résultat dépasse mes attentes.';

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Laisser un avis', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Row(
                        children: [
                          Text('Note globale: ', style: GoogleFonts.poppins()),
                          const SizedBox(width: 8),
                          Container(
                            constraints: BoxConstraints(maxWidth: 200),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...List.generate(5, (index) {
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _reviewRating = index + 1.0;
                                      });
                                    },
                                    child: Icon(
                                      index < _reviewRating ? Icons.star : Icons.star_border,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                  );
                                }),
                                const SizedBox(width: 4),
                                Text('($_reviewRating/5)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _reviewCommentController,
                      decoration: const InputDecoration(
                        labelText: 'Votre commentaire',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Score de recommandation: ', style: GoogleFonts.poppins()),
                        Expanded(
                          child: Slider(
                            value: _recommendationScore.toDouble(),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            onChanged: (value) {
                              setState(() {
                                _recommendationScore = value.toInt();
                              });
                            },
                          ),
                        ),
                        Text('$_recommendationScore/10', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final photos = await _picker.pickMultiImage();
                        setState(() {
                          _reviewPhotos.addAll(photos.map((xfile) => File(xfile.path)));
                        });
                                            },
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Ajouter des photos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black,
                      ),
                    ),
                    if (_reviewPhotos.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('${_reviewPhotos.length} photo(s) d\'avis ajoutée(s)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Annuler', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : () async {
                    await _submitReview();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                      : Text('Publier l\'avis', style: GoogleFonts.poppins()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitReview() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? widget.token;

      final uri = Uri.parse('${AppConfig.baseUrl}/api/quotations/${widget.quotationId}/reviews');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['rating'] = _reviewRating.toString();
      request.fields['comment'] = _reviewCommentController.text;
      request.fields['recommendation_score'] = _recommendationScore.toString();

      for (final photo in _reviewPhotos) {
        final file = await http.MultipartFile.fromPath('review_photos[]', photo.path);
        request.files.add(file);
      }

      http.StreamedResponse resp = await request.send();
      String body = await resp.stream.bytesToString();
      print('Réponse avis (POST): ${resp.statusCode} -> $body');

      if (resp.statusCode == 422) {
        // Si un avis existe déjà, tenter une mise à jour via PUT
        final putReq = http.MultipartRequest('POST', uri.replace(path: '${uri.path}/update'));
        putReq.headers['Authorization'] = 'Bearer $token';
        putReq.fields['rating'] = _reviewRating.toString();
        putReq.fields['comment'] = _reviewCommentController.text;
        putReq.fields['recommendation_score'] = _recommendationScore.toString();
        for (final photo in _reviewPhotos) {
          final file = await http.MultipartFile.fromPath('review_photos[]', photo.path);
          putReq.files.add(file);
        }
        resp = await putReq.send();
        body = await resp.stream.bytesToString();
        print('Réponse avis (UPDATE): ${resp.statusCode} -> $body');
      }

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Avis envoyé avec succès'), backgroundColor: Colors.green),
          );
        }
        await _refreshQuotation(token);
        setState(() {
          _reviewPhotos.clear();
          _reviewCommentController.clear();
        });
        if (mounted) Navigator.of(context).pop(true);
      } else {
        throw Exception('Échec (${resp.statusCode})');
      }
    } catch (e) {
      print('Erreur lors de la création d\'avis: $e');
      setState(() {
        _errorMessage = 'Erreur lors de la création d\'avis: $e';
      });

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

  void _showSuccessMessage(String status) {
    final actionText = status == 'accepted' ? 'acceptation' : 'refus';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Réponse d\'$actionText envoyée avec succès'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'quoted':
        return 'Devis reçu';
      case 'accepted':
        return 'Accepté';
      case 'in_progress':
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'quoted':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'in_progress':
        return Colors.amber;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.grey;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
    final isProfessionalContext = widget.context == QuotationContext.professional;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isProfessionalContext ? 'Détails du devis' : 'Ma demande de devis',
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informations du professionnel (côté client) ou du client (côté pro)
            _buildPartyInfo(),

            const SizedBox(height: 24),

            // Détails de la demande/devis
            _buildQuotationDetails(),

            const SizedBox(height: 24),

            // Section d'action selon le contexte et l'état
            _buildActionSection(),

            // Si erreur, afficher le message
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  _errorMessage,
                  style: GoogleFonts.poppins(
                    color: Colors.red[700],
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPartyInfo() {
    final isProfessionalContext = widget.context == QuotationContext.professional;
    final q = _currentQuotation ?? widget.quotation;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFCC00).withOpacity(0.1),
            const Color(0xFFFFCC00).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFCC00).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isProfessionalContext ? 'Informations du client' : 'Informations du professionnel',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey[200],
                radius: 30,
                child: Text(
                  isProfessionalContext
                      ? (q['client']?['first_name']?[0] ?? 'C').toUpperCase()
                      : (q['professional']?['company_name']?[0] ?? 'P').toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFFCC00),
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isProfessionalContext
                          ? '${q['client']?['first_name'] ?? ''} ${q['client']?['last_name'] ?? ''}'.trim()
                          : q['professional']?['company_name'] ?? 'N/A',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isProfessionalContext
                          ? (q['client']?['email'] ?? 'N/A')
                          : (q['professional']?['job_title'] ?? 'N/A'),
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
        ],
      ),
    );
  }

  Widget _buildQuotationDetails() {
    final q = _currentQuotation ?? widget.quotation;
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
            'Détails ${widget.context == QuotationContext.professional ? 'de la demande' : 'du devis'}',
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
            q['description'] ?? 'Non spécifiée',
            Icons.description,
          ),

          const SizedBox(height: 16),

          // Date souhaitée
          _buildDetailItem(
            'Date souhaitée',
            _formatDate(q['proposed_date']),
            Icons.calendar_today,
          ),

          const SizedBox(height: 16),

          // Montant (selon le contexte)
          if (q['amount'] != null)
            _buildDetailItem(
              widget.context == QuotationContext.professional ? 'Budget proposé' : 'Montant du devis',
              '${q['amount']} FCFA',
              Icons.attach_money,
              valueColor: const Color(0xFFFFCC00),
            ),

          const SizedBox(height: 16),

          // Notes (selon le contexte)
          if (widget.context == QuotationContext.professional && q['professional_notes'] != null && q['professional_notes'].isNotEmpty)
            _buildDetailItem(
              'Vos notes',
              q['professional_notes'],
              Icons.note,
            ),

          if (widget.context == QuotationContext.client && q['professional_notes'] != null && q['professional_notes'].isNotEmpty)
            _buildDetailItem(
              'Notes du professionnel',
              q['professional_notes'],
              Icons.note,
            ),

          const SizedBox(height: 16),

          // Bloc dédié: Réponse du professionnel (toujours visible côté client et pro)
          if ((q['status'] == 'quoted' || q['status'] == 'accepted' || q['status'] == 'in_progress' || q['status'] == 'completed')) ...[
            Text(
              'Réponse du professionnel',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            if (q['amount'] != null)
              _buildDetailItem(
                'Montant proposé',
                '${q['amount']} FCFA',
                Icons.request_quote,
                valueColor: const Color(0xFFFFCC00),
              ),
            if (q['proposed_date'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: _buildDetailItem(
                  'Date proposée',
                  _formatDate(q['proposed_date']),
                  Icons.event_available,
                ),
              ),
            if ((q['professional_notes'] ?? q['notes']) != null && (q['professional_notes'] ?? q['notes']).toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: _buildDetailItem(
                  'Notes du professionnel',
                  (q['professional_notes'] ?? q['notes']).toString(),
                  Icons.note_alt,
                ),
              ),
            const SizedBox(height: 16),
          ],

          // Informations sur les étapes si disponibles
          if (q['acceptance_proof'] != null) ...[
            // Normaliser structure: Map attendu, mais on gère List comme fallback
            Builder(builder: (context) {
              final ap = q['acceptance_proof'];
              final accDate = ap is Map ? ap['acceptance_date'] : null;
              final clientNotes = q['client_notes'] ?? (ap is Map ? ap['client_notes'] : null);
              final photoUrls = _extractPhotoUrls(ap);
              // Debug: compter les URLs extraites
              try { print('Acceptance proof photos count: ${photoUrls.length}'); } catch (_) {}

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preuve d\'acceptation',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (accDate != null)
                    _buildDetailItem(
                      'Date d\'acceptation',
                      _formatDate(accDate?.toString()),
                      Icons.event_available,
                    ),
                  if (clientNotes != null && clientNotes.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: _buildDetailItem(
                        'Notes du client',
                        clientNotes.toString(),
                        Icons.sticky_note_2,
                      ),
                    ),
                  if (photoUrls.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ImageGalleryViewer(urls: photoUrls),
                    const SizedBox(height: 16),
                  ]
                  else if (_acceptancePhotos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ImageGalleryViewer(urls: _acceptancePhotos.map((f) => _resolveMediaUrl(f.path)).toList()),
                    const SizedBox(height: 16),
                  ],
                ],
              );
            }),
          ],

          // Démarrage des travaux (visible côté client et pro si disponible)
          Builder(builder: (context) {
            final sp = q['start_proof'];
            if (sp == null) return const SizedBox.shrink();
            final startDate = sp is Map ? sp['start_date'] : null;
            final startDescription = sp is Map ? (sp['initial_description'] ?? sp['description']) : null;
            final startPhotoUrls = _extractPhotoUrls(sp);
            final hasAny = (startDate != null) || (startDescription != null && startDescription.toString().isNotEmpty) || startPhotoUrls.isNotEmpty;
            if (!hasAny) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Démarrage des travaux',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                if (startDate != null)
                  _buildDetailItem(
                    'Date de démarrage',
                    _formatDate(startDate.toString()),
                    Icons.calendar_today,
                  ),
                if (startDescription != null && startDescription.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: _buildDetailItem(
                      'Description initiale',
                      startDescription.toString(),
                      Icons.description,
                    ),
                  ),
                if (startPhotoUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ImageGalleryViewer(urls: startPhotoUrls),
                  const SizedBox(height: 16),
                ],
              ],
            );
          }),

          // Fin des travaux (visible côté client et pro si disponible)
          Builder(builder: (context) {
            final cp = q['completion_proof'];
            if (cp == null) return const SizedBox.shrink();
            final completionDate = cp is Map ? (cp['completion_date'] ?? cp['completed_at']) : null;
            final completionDescription = cp is Map ? (cp['final_description'] ?? cp['description']) : null;
            final materialsUsed = cp is Map ? (cp['materials_used'] ?? cp['materials']) : null;
            final completionPhotoUrls = _extractPhotoUrls(cp);
            final hasAny = (completionDate != null) || (completionDescription != null && completionDescription.toString().isNotEmpty) || (materialsUsed != null && materialsUsed.toString().isNotEmpty) || completionPhotoUrls.isNotEmpty;
            if (!hasAny) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fin des travaux',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                if (completionDate != null)
                  _buildDetailItem(
                    'Date de fin',
                    _formatDate(completionDate.toString()),
                    Icons.event_available,
                  ),
                if (completionDescription != null && completionDescription.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: _buildDetailItem(
                      'Description finale',
                      completionDescription.toString(),
                      Icons.description,
                    ),
                  ),
                if (materialsUsed != null && materialsUsed.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: _buildDetailItem(
                      'Matériaux utilisés',
                      materialsUsed.toString(),
                      Icons.build,
                    ),
                  ),
                if (completionPhotoUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ImageGalleryViewer(urls: completionPhotoUrls),
                  const SizedBox(height: 16),
                ],
              ],
            );
          }),

          // Annulation (visible côté client et pro si disponible)
          Builder(builder: (context) {
            final can = q['cancellation_proof'];
            if (can == null) return const SizedBox.shrink();
            final cancellationDate = can is Map ? (can['cancellation_date'] ?? can['cancelled_at']) : null;
            final cancellationReason = can is Map ? (can['cancellation_reason'] ?? can['reason'] ?? can['description']) : null;
            final cancellationPhotoUrls = _extractPhotoUrls(can);
            final hasAny = (cancellationDate != null) || (cancellationReason != null && cancellationReason.toString().isNotEmpty) || cancellationPhotoUrls.isNotEmpty;
            if (!hasAny) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Annulation',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                if (cancellationDate != null)
                  _buildDetailItem(
                    'Date d\'annulation',
                    _formatDate(cancellationDate.toString()),
                    Icons.event_busy,
                  ),
                if (cancellationReason != null && cancellationReason.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: _buildDetailItem(
                      'Raison',
                      cancellationReason.toString(),
                      Icons.report_problem,
                    ),
                  ),
                if (cancellationPhotoUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ImageGalleryViewer(urls: cancellationPhotoUrls),
                  const SizedBox(height: 16),
                ],
              ],
            );
          }),

          // Informations sur les étapes si disponibles
          _buildStepDetails(),

          const SizedBox(height: 16),

          // Pièces jointes
          if (q['attachments'] is List && (q['attachments'] as List).isNotEmpty) ...[
            Text(
              'Pièces jointes',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ...((q['attachments'] as List).map<Widget>((attachment) {
              String name = 'Fichier';
              String sizeLabel = '';
              if (attachment is Map) {
                name = (attachment['original_name'] ?? attachment['name'] ?? 'Fichier').toString();
                final s = attachment['size'];
                if (s is num) {
                  sizeLabel = '${(s / 1024).toStringAsFixed(1)} KB';
                } else if (s is String) {
                  final parsed = double.tryParse(s);
                  if (parsed != null) sizeLabel = '${(parsed / 1024).toStringAsFixed(1)} KB';
                }
              } else if (attachment is String) {
                name = attachment.split('/').last;
              }
              return Container(
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
                        name,
                        style: GoogleFonts.poppins(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (sizeLabel.isNotEmpty)
                      Text(
                        sizeLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              );
            })),
          ],
        ],
      ),
    );
  }

  Widget _buildStepDetails() {
    final q = _currentQuotation ?? widget.quotation;
    final steps = <Widget>[];

    // Debug: Afficher toutes les données disponibles dans le devis
    print('=== DEBUG DONNEES DEVIS (BACKEND) ===');
    print('Status: ${q['status']}');
    print('Start proof: ${q['start_proof']}');
    print('Completion proof: ${q['completion_proof']}');
    print('Cancellation proof: ${q['cancellation_proof']}');
    print('Acceptance proof: ${q['acceptance_proof']}');
    print('Review: ${q['review']}');
    print('========================================');
    print('=== DEBUG DONNEES TEMPORAIRES ===');
    print('Temp start date: $_tempStartDate');
    print('Temp start description: $_tempStartDescription');
    print('Temp start photos count: $_tempStartPhotosCount');
    print('Temp completion date: $_tempCompletionDate');
    print('Temp completion description: $_tempCompletionDescription');
    print('Temp materials used: $_tempMaterialsUsed');
    print('Temp completion photos count: $_tempCompletionPhotosCount');
    print('Temp cancellation date: $_tempCancellationDate');
    print('Temp cancellation reason: $_tempCancellationReason');
    print('Temp cancellation photos count: $_tempCancellationPhotosCount');
    print('Review rating: $_reviewRating');
    print('Review comment: ${_reviewCommentController.text}');
    print('===============================');
    // Acceptation du devis
    final acceptanceProof = q['acceptance_proof'];
    if (acceptanceProof != null && acceptanceProof is Map) {
      steps.add(_buildStepCard(
        '✅ Acceptation du devis',
        [
          if (acceptanceProof['acceptance_date'] != null)
            _buildDetailItem('Date d\'acceptation', _formatDate(acceptanceProof['acceptance_date']), Icons.calendar_today),
          if (acceptanceProof['proof_photos'] != null && acceptanceProof['proof_photos'] is List && (acceptanceProof['proof_photos'] as List).isNotEmpty)
            _buildDetailItem('Photos serveur', '${(acceptanceProof['proof_photos'] as List).length} photo(s)', Icons.photo),
          if (acceptanceProof['accepted_at'] != null)
            _buildDetailItem('Horodatage', acceptanceProof['accepted_at'], Icons.access_time),
        ],
      ));
    }

    final startProof = q['start_proof'];
    final hasServerStartData = startProof != null && startProof is Map && (startProof['start_date'] != null || startProof['initial_description'] != null);
    final hasTempStartData = _tempStartDate != null || _tempStartDescription != null || (_tempStartPhotosCount != null && _tempStartPhotosCount! > 0);

    if (hasServerStartData || hasTempStartData) {
      steps.add(_buildStepCard(
        '🚀 Démarrage des travaux',
        [
          // Données serveur depuis start_proof
          if (startProof != null && startProof['start_date'] != null)
            _buildDetailItem('Date de démarrage', _formatDate(startProof['start_date']), Icons.calendar_today),
          if (startProof != null && startProof['initial_description'] != null && startProof['initial_description'].isNotEmpty)
            _buildDetailItem('Description', startProof['initial_description'], Icons.description),
          if (startProof != null && startProof['start_photos'] != null && startProof['start_photos'] is List && (startProof['start_photos'] as List).isNotEmpty)
            _buildDetailItem('Photos serveur', '${(startProof['start_photos'] as List).length} photo(s)', Icons.photo),

          // Données temporaires (toujours affichées si elles existent)
          if (hasTempStartData && _tempStartDate != null)
            _buildDetailItem('📝 Date temporaire', _tempStartDate!, Icons.edit_calendar, valueColor: Colors.orange),
          if (hasTempStartData && _tempStartDescription != null)
            _buildDetailItem('📝 Description temporaire', _tempStartDescription!, Icons.edit_note, valueColor: Colors.orange),
          if (hasTempStartData && _tempStartPhotosCount != null && _tempStartPhotosCount! > 0)
            _buildDetailItem('📝 Photos temporaires', '$_tempStartPhotosCount photo(s)', Icons.photo_camera, valueColor: Colors.orange),
        ],
      ));
    }

    // Achèvement des travaux - données serveur ou temporaires
    final completionProof = q['completion_proof'];
    final hasServerCompletionData = completionProof != null && completionProof is Map && (completionProof['completion_date'] != null || completionProof['final_description'] != null || completionProof['materials_used'] != null);
    final hasTempCompletionData = _tempCompletionDate != null || _tempCompletionDescription != null || _tempMaterialsUsed != null || (_tempCompletionPhotosCount != null && _tempCompletionPhotosCount! > 0);

    if (hasServerCompletionData || hasTempCompletionData) {
      steps.add(_buildStepCard(
        '✅ Achèvement des travaux',
        [
          // Données serveur depuis completion_proof
          if (completionProof != null && completionProof['completion_date'] != null)
            _buildDetailItem('Date d\'achèvement', _formatDate(completionProof['completion_date']), Icons.calendar_today),
          if (completionProof != null && completionProof['final_description'] != null && completionProof['final_description'].isNotEmpty)
            _buildDetailItem('Description finale', completionProof['final_description'], Icons.description),
          if (completionProof != null && completionProof['materials_used'] != null && completionProof['materials_used'].isNotEmpty)
            _buildDetailItem('Matériaux utilisés', completionProof['materials_used'], Icons.inventory),
          if (completionProof != null && completionProof['completion_photos'] != null && completionProof['completion_photos'] is List && (completionProof['completion_photos'] as List).isNotEmpty)
            _buildDetailItem('Photos serveur', '${(completionProof['completion_photos'] as List).length} photo(s)', Icons.photo),

          // Données temporaires (toujours affichées si elles existent)
          if (hasTempCompletionData && _tempCompletionDate != null)
            _buildDetailItem('📝 Date temporaire', _tempCompletionDate!, Icons.edit_calendar, valueColor: Colors.orange),
          if (hasTempCompletionData && _tempCompletionDescription != null)
            _buildDetailItem('📝 Description temporaire', _tempCompletionDescription!, Icons.edit_note, valueColor: Colors.orange),
          if (hasTempCompletionData && _tempMaterialsUsed != null)
            _buildDetailItem('📝 Matériaux temporaires', _tempMaterialsUsed!, Icons.edit, valueColor: Colors.orange),
          if (hasTempCompletionData && _tempCompletionPhotosCount != null && _tempCompletionPhotosCount! > 0)
            _buildDetailItem('📝 Photos temporaires', '$_tempCompletionPhotosCount photo(s)', Icons.photo_camera, valueColor: Colors.orange),
        ],
      ));
    }

    // Annulation - données serveur ou temporaires
    final cancellationProof = q['cancellation_proof'];
    final hasServerCancellationData = cancellationProof != null && cancellationProof is Map && (cancellationProof['cancellation_date'] != null || cancellationProof['cancellation_reason'] != null);
    final hasTempCancellationData = _tempCancellationDate != null || _tempCancellationReason != null || (_tempCancellationPhotosCount != null && _tempCancellationPhotosCount! > 0);

    if (hasServerCancellationData || hasTempCancellationData) {
      steps.add(_buildStepCard(
        '❌ Annulation',
        [
          // Données serveur depuis cancellation_proof
          if (cancellationProof != null && cancellationProof['cancellation_date'] != null)
            _buildDetailItem('Date d\'annulation', _formatDate(cancellationProof['cancellation_date']), Icons.calendar_today),
          if (cancellationProof != null && cancellationProof['cancellation_reason'] != null && cancellationProof['cancellation_reason'].isNotEmpty)
            _buildDetailItem('Raison', cancellationProof['cancellation_reason'], Icons.warning),
          if (cancellationProof != null && cancellationProof['cancellation_proof'] != null && cancellationProof['cancellation_proof'] is List && (cancellationProof['cancellation_proof'] as List).isNotEmpty)
            _buildDetailItem('Justificatifs serveur', '${(cancellationProof['cancellation_proof'] as List).length} fichier(s)', Icons.attach_file),

          // Données temporaires (toujours affichées si elles existent)
          if (hasTempCancellationData && _tempCancellationDate != null)
            _buildDetailItem('📝 Date temporaire', _tempCancellationDate!, Icons.edit_calendar, valueColor: Colors.orange),
          if (hasTempCancellationData && _tempCancellationReason != null)
            _buildDetailItem('📝 Raison temporaire', _tempCancellationReason!, Icons.edit_note, valueColor: Colors.orange),
          if (hasTempCancellationData && _tempCancellationPhotosCount != null && _tempCancellationPhotosCount! > 0)
            _buildDetailItem('📝 Justificatifs temporaires', '$_tempCancellationPhotosCount fichier(s)', Icons.photo_camera, valueColor: Colors.orange),
        ],
      ));
    }

    // Avis temporaire (si en cours de saisie)
    // ignore: unnecessary_null_comparison
    final hasTempReviewData = _reviewPhotos.isNotEmpty || _reviewCommentController.text.isNotEmpty;

    if (hasTempReviewData) {
      steps.add(_buildStepCard(
        '⭐ Avis en cours',
        [
          SizedBox(
            width: double.infinity,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...List.generate(5, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 1.0),
                    child: Icon(
                      index < _reviewRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 12,
                    ),
                  );
                }),
                const SizedBox(width: 4),
                Text('($_reviewRating/5)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (_reviewCommentController.text.isNotEmpty)
            _buildDetailItem('📝 Commentaire temporaire', _reviewCommentController.text, Icons.edit_note, valueColor: Colors.orange),
        ],
      ));
    }

    // Avis serveur existant
    Map? review;
    if (q['review'] != null && q['review'] is Map) {
      review = q['review'] as Map;
    } else if (q['reviews'] is List && (q['reviews'] as List).isNotEmpty) {
      final list = (q['reviews'] as List);
      final first = list.first;
      if (first is Map) review = first;
    }
    if (review != null) {
      steps.add(_buildStepCard(
        '⭐ Avis',
        [
          if (review['rating'] != null)
            SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...List.generate(5, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 1.0),
                      child: Icon(
                        index < (review?['rating'] as num) ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 12,
                      ),
                    );
                  }),
                  const SizedBox(width: 4),
                  Text('${review['rating']}/5', style: GoogleFonts.poppins(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          if (review['comment'] != null && review['comment'].toString().isNotEmpty)
            _buildDetailItem('Commentaire', review['comment'], Icons.comment),
          if (review['recommendation_score'] != null)
            _buildDetailItem('Score de recommandation', '${review['recommendation_score']}/10', Icons.thumb_up),
          if (review['reviewer_name'] != null && review['reviewer_name'].toString().isNotEmpty)
            _buildDetailItem('Par', review['reviewer_name'], Icons.person),
          if (review['created_at'] != null)
            _buildDetailItem('Publié le', _formatDate(review['created_at'].toString()), Icons.schedule),
          if (review['quality_rating'] != null)
            _buildDetailItem('Qualité', '${review['quality_rating']}/5', Icons.star_rate),
          if (review['communication_rating'] != null)
            _buildDetailItem('Communication', '${review['communication_rating']}/5', Icons.chat_bubble_outline),
          if (review['punctuality_rating'] != null)
            _buildDetailItem('Ponctualité', '${review['punctuality_rating']}/5', Icons.access_time),
          if (review['price_rating'] != null)
            _buildDetailItem('Prix', '${review['price_rating']}/5', Icons.attach_money),
          if (review['review_photos'] != null)
            Builder(builder: (context) {
              final urls = _extractPhotoUrls(review);
              if (urls.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, i) {
                      final url = urls[i];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          httpHeaders: _imageHeaders(),
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          placeholder: (c, _) => Container(width:72,height:72,color: Colors.grey[100],child: const Center(child: SizedBox(width:18,height:18,child: CircularProgressIndicator(strokeWidth:2)))),
                          errorWidget: (c, _, __) => Container(
                            width: 72,
                            height: 72,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: urls.length,
                  ),
                ),
              );
            }),
        ],
      ));
    }

    return Column(children: steps);
  }

  Widget _buildStepCard(String title, List<Widget> details) {
    if (details.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...details,
        ],
      ),
    );
  }

  Widget _buildActionSection() {
    final isProfessionalContext = widget.context == QuotationContext.professional;
    final q = _currentQuotation ?? widget.quotation;
    final status = q['status'];

    // Différentes actions selon le contexte et l'état
    if (isProfessionalContext) {
      // Côté professionnel
      if (status == 'pending') {
        return _buildProfessionalResponseSection();
      }
      return _buildStatusDisplay();
    }

    // Côté client
    switch (status) {
      case 'quoted':
        return _buildClientResponseSection();
      case 'accepted':
        return _buildAcceptedSection();
      case 'in_progress':
        return _buildWorkInProgressSection();
      case 'completed':
        return _buildCompletedSection();
      default:
        return _buildStatusDisplay();
    }
  }

  Widget _buildProfessionalResponseSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proposer un devis',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Le client attend votre proposition. Renseignez le montant (obligatoire), vos notes (≤ 1000) et une date proposée (optionnelle).',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _respondToQuotation('accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCC00),
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
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Proposer un devis',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
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
                  child: Text(
                    'Refuser',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClientResponseSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Action requise',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Le professionnel a fourni un devis pour votre demande. Vous pouvez l\'accepter ou le refuser.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _respondToQuotation('accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCC00),
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
                            Expanded(
                              child: Text(
                                'Accepter le devis',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
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
                  child: Text(
                    'Refuser',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Devis accepté',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Le devis a été accepté. Vous pouvez maintenant démarrer les travaux.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _showStartWorkDialog,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('Démarrer les travaux'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCC00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _showCancelDialog,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Annuler'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkInProgressSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Travaux en cours',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Les travaux ont commencé. Vous pouvez les marquer comme terminés une fois le travail achevé.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _showCompleteWorkDialog,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check_circle),
                  label: const Text('Marquer comme terminé'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCC00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _showCancelDialog,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Annuler'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Travaux terminés',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Les travaux sont terminés. Vous pouvez maintenant laisser un avis sur la qualité du travail.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _showReviewDialog,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.star),
              label: const Text('Laisser un avis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDisplay() {
    final q = _currentQuotation ?? widget.quotation;
    final status = q['status'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(status),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getStatusIcon(status),
                color: _getStatusColor(status),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Statut: ${_getStatusText(status)}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(status),
                ),
              ),
            ],
          ),
          if (q['amount'] != null) ...[
            const SizedBox(height: 12),
            Text(
              'Montant: ${q['amount']} FCFA',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'quoted':
        return Icons.request_quote;
      case 'accepted':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.engineering;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
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

  @override
  void dispose() {
    _startDescriptionController.dispose();
    _completionDescriptionController.dispose();
    _cancellationReasonController.dispose();
    _reviewCommentController.dispose();
    _materialsUsedController.dispose();
    super.dispose();
  }

  // Ajoute cette fonction dans la classe UnifiedQuotationDetailScreen ou _UnifiedQuotationDetailScreenState :
  List<String> _getAttachmentImageUrls(List attachments) {
    return attachments
        .where((att) {
          final name = (att['original_name'] ?? att['name'] ?? '').toLowerCase();
          return name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png');
        })
        .map((att) {
          final url = att['url'] ?? att['path'];
          if (url == null) return '';
          if (!url.toString().startsWith('http')) {
            return AppConfig.buildMediaUrl(url.toString().startsWith('/') ? url.toString() : '/${url.toString()}');
          }
          return url.toString();
        })
        .where((u) => u.isNotEmpty)
        .toList();
  }
}

class ImageGalleryViewer extends StatelessWidget {
  final List<String> urls;
  const ImageGalleryViewer({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const Text('Aucune image', style: TextStyle(color: Colors.grey));
    int gridCount = urls.length < 3 ? urls.length : 3;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: gridCount, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1),
      itemCount: urls.length,
      itemBuilder: (context, i) {
        final url = urls[i];
        return GestureDetector(
          onTap: () => showDialog(
            context: context,
            barrierColor: Colors.black.withOpacity(0.90),
            builder: (_) => _GalleryFullScreenViewer(urls: urls, initialIndex: i),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 92, height: 92,
              fit: BoxFit.cover,
              placeholder: (c, _) => Container(
                color: Colors.grey[100],
                child: const Center(child: SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2))),
              ),
              errorWidget: (c,_,__) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GalleryFullScreenViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _GalleryFullScreenViewer({required this.urls, required this.initialIndex});
  @override
  State<_GalleryFullScreenViewer> createState() => _GalleryFullScreenViewerState();
}
class _GalleryFullScreenViewerState extends State<_GalleryFullScreenViewer> {
  late int _index;
  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            itemCount: widget.urls.length,
            controller: PageController(initialPage: _index),
            onPageChanged: (v) => setState(() => _index = v),
            itemBuilder: (ctx, i) {
              final url = widget.urls[i];
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    httpHeaders: null,
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 36, right: 18,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.of(context).pop(),
              splashRadius: 26,
            ),
          ),
          if (widget.urls.length > 1)
            Positioned(
              bottom: 30, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(48)),
                  child: Text(
                    '${_index+1} / ${widget.urls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
