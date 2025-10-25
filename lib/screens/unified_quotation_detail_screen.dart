import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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
    Key? key,
    required this.quotationId,
    required this.quotation,
    required this.token,
    required this.context,
  }) : super(key: key);

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

  List<File> _startPhotos = [];
  List<File> _completionPhotos = [];
  List<File> _cancellationPhotos = [];
  List<File> _reviewPhotos = [];

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

  Future<void> _respondToQuotation(String status) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('Tentative de réponse - Statut actuel du devis: ${widget.quotation['status']}');
      print('ID du devis: ${widget.quotationId}');
      print('Contexte: ${widget.context}');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? widget.token;

      // Différentes logiques selon le contexte
      if (widget.context == QuotationContext.professional) {
        await _respondAsProfessional(status, token);
      } else {
        await _respondAsClient(status, token);
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
    final Map<String, dynamic> requestData = {};

    if (status == 'accepted') {
      requestData.addAll({
        'amount': 0.0,
        'professional_notes': '',
        'proposed_date': DateTime.now().add(Duration(days: 7)).toIso8601String().split('T')[0],
        'professional_id': widget.quotation['professional']?['id'] ?? widget.quotation['professional_id'],
        'description': widget.quotation['description'],
      });
    } else if (status == 'rejected') {
      requestData.addAll({
        'professional_notes': 'Demande refusée par le professionnel',
        'professional_id': widget.quotation['professional']?['id'] ?? widget.quotation['professional_id'],
        'description': widget.quotation['description'],
      });
    }

    final response = await ApiService.post(
      'quotations/${widget.quotationId}',
      data: requestData,
    );

    if (response != null) {
      _showSuccessMessage(status);
      Navigator.of(context).pop(true);
    } else {
      throw Exception('Réponse inattendue du serveur');
    }
  }

  Future<void> _respondAsClient(String status, String token) async {
    if (status == 'accepted') {
      Map<String, dynamic> acceptanceData = {
        'acceptance_date': DateTime.now().toIso8601String().split('T')[0],
        'client_notes': 'Devis accepté via l\'application mobile',
      };

      print('Données d\'acceptation envoyées: $acceptanceData');
      print('ID client du devis: ${widget.quotation['client']?['id']}');

      final response = await ApiService.post(
        'quotations/${widget.quotationId}/accept',
        data: acceptanceData,
      );

      print('Réponse serveur: $response');

      if (response != null) {
        if (response['success'] == true || response['status'] == 'success' || response['data'] != null) {
          if (response['acceptance_proof'] != null) {
            print('Détails d\'acceptation reçus: ${response['acceptance_proof']}');
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Devis accepté avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          print('Structure de réponse inattendue: $response');
          throw Exception('Réponse inattendue du serveur: ${response.toString()}');
        }
      } else {
        throw Exception('Données invalides');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fonctionnalité de refus côté client à implémenter'),
          backgroundColor: Colors.orange,
        ),
      );
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
                        setState(() {
                          _startPhotos.addAll(photos.map((xfile) => File(xfile.path)));
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
                      Text('${_tempStartPhotosCount} photo(s) sélectionnée(s)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
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
                        setState(() {
                          _completionPhotos.addAll(photos.map((xfile) => File(xfile.path)));
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
                      Text('${_tempCompletionPhotosCount} photo(s) sélectionnée(s)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
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
                        setState(() {
                          _cancellationPhotos.addAll(photos.map((xfile) => File(xfile.path)));
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
                      Text('${_tempCancellationPhotosCount} justificatif(s) ajouté(s)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
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
      final cancellationData = {
        'cancellation_reason': _cancellationReasonController.text,
        'cancellation_date': DateFormat('yyyy-MM-dd').format(_selectedCancellationDate),
        'cancellation_proof': _cancellationPhotos.map((photo) => photo.path.split('/').last).toList(),
      };

      print('Données d\'annulation envoyées: $cancellationData');

      final response = await ApiService.post(
        'quotations/${widget.quotationId}/cancel',
        data: cancellationData,
      );

      print('Réponse annulation: $response');

      if (response != null) {
        if (response['data'] != null || response['status'] == 'cancelled') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Devis annulé avec succès.'),
              backgroundColor: Colors.orange,
            ),
          );
          _clearTempData();
          Navigator.of(context).pop(true);
        } else {
          throw Exception('Réponse inattendue du serveur');
        }
      } else {
        throw Exception('Le devis ne peut pas être annulé dans son état actuel');
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
                    Container(
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
                    Navigator.of(context).pop();
                    await _createReview();
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

  Future<void> _createReview() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await SharedPreferences.getInstance();

      final reviewData = {
        'rating': _reviewRating,
        'comment': _reviewCommentController.text,
        'review_photos': _reviewPhotos.map((photo) => photo.path.split('/').last).toList(),
        'recommendation_score': _recommendationScore,
      };

      print('Données d\'avis envoyées: $reviewData');

      final response = await ApiService.post(
        'quotations/${widget.quotationId}/reviews',
        data: reviewData,
      );

      print('Réponse avis: $response');

      if (response != null) {
        if (response['data'] != null || response['id'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avis publié avec succès ! Merci pour votre retour.'),
              backgroundColor: Colors.green,
            ),
          );
          _clearTempData();
          Navigator.of(context).pop(true);
        } else {
          throw Exception('Réponse inattendue du serveur');
        }
      } else {
        throw Exception('Impossible de créer un avis');
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
                      ? (widget.quotation['client']?['first_name']?[0] ?? 'C').toUpperCase()
                      : (widget.quotation['professional']?['company_name']?[0] ?? 'P').toUpperCase(),
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
                          ? '${widget.quotation['client']?['first_name'] ?? ''} ${widget.quotation['client']?['last_name'] ?? ''}'.trim()
                          : widget.quotation['professional']?['company_name'] ?? 'N/A',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isProfessionalContext
                          ? (widget.quotation['client']?['email'] ?? 'N/A')
                          : (widget.quotation['professional']?['job_title'] ?? 'N/A'),
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
            widget.quotation['description'] ?? 'Non spécifiée',
            Icons.description,
          ),

          const SizedBox(height: 16),

          // Date souhaitée
          _buildDetailItem(
            'Date souhaitée',
            _formatDate(widget.quotation['proposed_date']),
            Icons.calendar_today,
          ),

          const SizedBox(height: 16),

          // Montant (selon le contexte)
          if (widget.quotation['amount'] != null)
            _buildDetailItem(
              widget.context == QuotationContext.professional ? 'Budget proposé' : 'Montant du devis',
              '${widget.quotation['amount']} FCFA',
              Icons.attach_money,
              valueColor: const Color(0xFFFFCC00),
            ),

          const SizedBox(height: 16),

          // Notes (selon le contexte)
          if (widget.context == QuotationContext.professional && widget.quotation['professional_notes'] != null && widget.quotation['professional_notes'].isNotEmpty)
            _buildDetailItem(
              'Vos notes',
              widget.quotation['professional_notes'],
              Icons.note,
            ),

          if (widget.context == QuotationContext.client && widget.quotation['professional_notes'] != null && widget.quotation['professional_notes'].isNotEmpty)
            _buildDetailItem(
              'Notes du professionnel',
              widget.quotation['professional_notes'],
              Icons.note,
            ),

          const SizedBox(height: 16),

          // Informations sur les étapes si disponibles
          _buildStepDetails(),

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

  Widget _buildStepDetails() {
    final steps = <Widget>[];

    // Debug: Afficher toutes les données disponibles dans le devis
    print('=== DEBUG DONNEES DEVIS (BACKEND) ===');
    print('Status: ${widget.quotation['status']}');
    print('Start proof: ${widget.quotation['start_proof']}');
    print('Completion proof: ${widget.quotation['completion_proof']}');
    print('Cancellation proof: ${widget.quotation['cancellation_proof']}');
    print('Acceptance proof: ${widget.quotation['acceptance_proof']}');
    print('Review: ${widget.quotation['review']}');
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
    final startProof = widget.quotation['start_proof'];
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
            _buildDetailItem('📝 Photos temporaires', '${_tempStartPhotosCount} photo(s)', Icons.photo_camera, valueColor: Colors.orange),
        ],
      ));
    }

    // Achèvement des travaux - données serveur ou temporaires
    final completionProof = widget.quotation['completion_proof'];
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
            _buildDetailItem('📝 Photos temporaires', '${_tempCompletionPhotosCount} photo(s)', Icons.photo_camera, valueColor: Colors.orange),
        ],
      ));
    }

    // Annulation - données serveur ou temporaires
    final cancellationProof = widget.quotation['cancellation_proof'];
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
            _buildDetailItem('📝 Justificatifs temporaires', '${_tempCancellationPhotosCount} fichier(s)', Icons.photo_camera, valueColor: Colors.orange),
        ],
      ));
    }

    // Avis temporaire (si en cours de saisie)
    // ignore: unnecessary_null_comparison
    final hasTempReviewData = _reviewRating != null;

    if (hasTempReviewData) {
      steps.add(_buildStepCard(
        '⭐ Avis en cours',
        [
          Container(
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
    if (widget.quotation['review'] != null && widget.quotation['review'] is Map) {
      final review = widget.quotation['review'] as Map;
      steps.add(_buildStepCard(
        '⭐ Avis',
        [
          if (review['rating'] != null)
            Container(
              width: double.infinity,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...List.generate(5, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 1.0),
                      child: Icon(
                        index < (review['rating'] as num) ? Icons.star : Icons.star_border,
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
          if (review['comment'] != null && review['comment'].isNotEmpty)
            _buildDetailItem('Commentaire', review['comment'], Icons.comment),
          if (review['recommendation_score'] != null)
            _buildDetailItem('Score de recommandation', '${review['recommendation_score']}/10', Icons.thumb_up),
          if (review['review_photos'] != null && review['review_photos'] is List && (review['review_photos'] as List).isNotEmpty)
            _buildDetailItem('Photos', '${(review['review_photos'] as List).length} photo(s)', Icons.photo),
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
    final status = widget.quotation['status'];

    // Différentes actions selon le contexte et l'état
    if (isProfessionalContext) {
      // Côté professionnel
      if (status == 'pending') {
        return _buildProfessionalResponseSection();
      } else {
        return _buildStatusDisplay();
      }
    } else {
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
            'Votre réponse',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Le client attend votre devis. Fournissez un montant et vos conditions.',
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
    return Container(
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
}
