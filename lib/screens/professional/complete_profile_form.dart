import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:http/http.dart' as http;
import '../../services/document_service.dart';
import '../../models/document.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../core/app_config.dart';
import 'dart:convert';
import 'dart:io';

class CompleteProfileForm extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onSubmit;
  final bool isLoading;
  final bool isProClient;

  const CompleteProfileForm({
    Key? key,
    this.initialData,
    required this.onSubmit,
    this.isLoading = false,
    this.isProClient = false,
  }) : super(key: key);

  @override
  _CompleteProfileFormState createState() => _CompleteProfileFormState();
}

class _CompleteProfileFormState extends State<CompleteProfileForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Contrôleurs pour les champs du formulaire
  final TextEditingController _companyNameCtrl = TextEditingController();
  final TextEditingController _rccmNumberCtrl = TextEditingController();
  final TextEditingController _jobTitleCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _postalCodeCtrl = TextEditingController();
  final TextEditingController _websiteCtrl = TextEditingController();
  final TextEditingController _hourlyRateCtrl = TextEditingController();
  final TextEditingController _minPriceCtrl = TextEditingController();
  final TextEditingController _maxPriceCtrl = TextEditingController();
  final TextEditingController _radiusKmCtrl = TextEditingController();
  final TextEditingController _experienceYearsCtrl = TextEditingController();

  // Variables d'état
  bool _isAvailable = true;
  String? _idDocumentPath;
  String? _idDocumentName;
  String? _profilePhotoPath;
  String? _profilePhotoName;
  bool _isUploading = false;
  List<Map<String, dynamic>> _skills = [];
  final TextEditingController _skillNameCtrl = TextEditingController();
  String? _selectedLevel;

  Future<void> _pickDocument() async {
    try {
      // Récupérer les extensions autorisées pour ce type de document
      final allowedExts = DocumentService.allowedExtensions['id_document'];
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExts?.map((e) => e.substring(1)).toList() ?? ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        setState(() {
          _idDocumentPath = result.files.single.path!;
          _idDocumentName = result.files.single.name;
        });
      }
    } catch (e) {
      print('Erreur lors de la sélection du fichier: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la sélection du fichier')),
        );
      }
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _profilePhotoPath = result.files.single.path!;
          _profilePhotoName = result.files.single.name;
        });
      }
    } catch (e) {
      print('Erreur lors de la sélection de la photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la sélection de la photo')),
        );
      }
    }
  }

  Future<Map<String, String>> _uploadDocument() async {
    if (_idDocumentPath == null) return {};

    try {
      setState(() => _isUploading = true);
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final docService = DocumentService(token);
      final file = File(_idDocumentPath!);

      final Document uploaded = await docService.uploadDocument(file, 'id_document');

      // Return the path expected by backend (filePath)
      return {'id_document_path': uploaded.filePath};
    } catch (e) {
      print('Erreur lors de l\'upload: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // Méthode d'upload de photo (non utilisée actuellement - la photo est envoyée directement dans le formulaire)
  // Cette méthode peut être utilisée si un endpoint d'upload spécifique est créé côté serveur

  // Horaires d'ouverture par défaut (9h-18h du lundi au vendredi)
  final Map<String, Map<String, String>> _businessHours = <String, Map<String, String>>{
    'lundi': <String, String>{'open': '09:00', 'close': '18:00'},
    'mardi': <String, String>{'open': '09:00', 'close': '18:00'},
    'mercredi': <String, String>{'open': '09:00', 'close': '18:00'},
    'jeudi': <String, String>{'open': '09:00', 'close': '18:00'},
    'vendredi': <String, String>{'open': '09:00', 'close': '18:00'},
    'samedi': <String, String>{'open': '', 'close': ''}, // Fermé par défaut
    'dimanche': <String, String>{'open': '', 'close': ''}, // Fermé par défaut
  };

  // Niveaux de compétence (affichage)
  static const List<String> _skillLevelsDisplay = <String>['Débutant', 'Intermédiaire', 'Avancé', 'Expert'];

  // Mappage des niveaux de compétence vers les valeurs attendues par l'API
  final Map<String, String> _skillLevelsMap = {
    'Débutant': 'beginner',
    'Intermédiaire': 'intermediate',
    'Avancé': 'advanced',
    'Expert': 'expert',
  };

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.initialData != null) {
      // Initialiser les contrôleurs avec les données existantes
      _companyNameCtrl.text = widget.initialData!['companyName'] ?? '';
      _rccmNumberCtrl.text = widget.initialData!['rccmNumber'] ?? '';
      _jobTitleCtrl.text = widget.initialData!['jobTitle'] ?? '';
      _descriptionCtrl.text = widget.initialData!['description'] ?? '';
      _addressCtrl.text = widget.initialData!['address'] ?? '';
      _cityCtrl.text = widget.initialData!['city'] ?? '';
      _postalCodeCtrl.text = widget.initialData!['postalCode'] ?? '';
      _websiteCtrl.text = widget.initialData!['website'] ?? '';
      _hourlyRateCtrl.text = widget.initialData!['hourlyRate']?.toString() ?? '';
      _minPriceCtrl.text = widget.initialData!['minPrice']?.toString() ?? '';
      _maxPriceCtrl.text = widget.initialData!['maxPrice']?.toString() ?? '';
      _radiusKmCtrl.text = widget.initialData!['radiusKm']?.toString() ?? '';
      _experienceYearsCtrl.text = widget.initialData!['experienceYears']?.toString() ?? '';
      _isAvailable = widget.initialData!['isAvailable'] ?? true;
      _skills = List<Map<String, dynamic>>.from(widget.initialData!['skills'] ?? []);

      // Mettre à jour les horaires d'ouverture si disponibles
      if (widget.initialData!['businessHours'] != null) {
        final Map<String, dynamic> savedHours = widget.initialData!['businessHours'];
        savedHours.forEach((day, hours) {
          if (_businessHours.containsKey(day) && hours is Map) {
            _businessHours[day]!['open'] = hours['open']?.toString() ?? '';
            _businessHours[day]!['close'] = hours['close']?.toString() ?? '';
          }
        });
      }
    }
  }

  void _addSkill() {
    final skillName = _skillNameCtrl.text.trim();
    if (skillName.isEmpty || _selectedLevel == null) return;

    setState(() {
      _skills.add({
        'name': skillName,
        'slug': skillName.toLowerCase().replaceAll(' ', '-'),
        'level': _skillLevelsMap[_selectedLevel!] ?? 'beginner',
        'experience_years': int.tryParse(_experienceYearsCtrl.text) ?? 1,
      });
      _skillNameCtrl.clear();
      _selectedLevel = null;
    });
  }

  void _removeSkill(int index) {
    setState(() {
      _skills.removeAt(index);
    });
  }

  @override
  void dispose() {
    _skillNameCtrl.dispose();
    _companyNameCtrl.dispose();
    _rccmNumberCtrl.dispose();
    _jobTitleCtrl.dispose();
    _descriptionCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _postalCodeCtrl.dispose();
    _websiteCtrl.dispose();
    _hourlyRateCtrl.dispose();
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    _radiusKmCtrl.dispose();
    _experienceYearsCtrl.dispose();
    super.dispose();
  }

  Future<void> _showAddSkillDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ajouter une compétence'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _skillNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la compétence',
                    border: OutlineInputBorder(),
                  ),
                  validator: RequiredValidator(errorText: 'Entrez un nom de compétence'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedLevel,
                  decoration: const InputDecoration(
                    labelText: 'Niveau',
                    border: OutlineInputBorder(),
                  ),
                  items: _skillLevelsDisplay.map<DropdownMenuItem<String>>((String level) {
                    return DropdownMenuItem<String>(
                      value: level,
                      child: Text(level),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    setState(() {
                      _selectedLevel = value;
                    });
                  },
                  validator: RequiredValidator(errorText: 'Sélectionnez un niveau'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_skillNameCtrl.text.isNotEmpty && _selectedLevel != null) {
                  _addSkill();
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFCC00),
                foregroundColor: Colors.white,
              ),
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    );
  }

  void _updateBusinessHours(String day, String type, String value) {
    setState(() {
      _businessHours[day]![type] = value;
    });
  }

  String _getBusinessHoursJson() {
    return jsonEncode(_businessHours);
  }


  // Désactivez cette constante pour utiliser l'upload de document personnalisé
  static const bool USE_DEFAULT_DOCUMENT = true;
  static const String DEFAULT_DOCUMENT_PATH = 'chemin/vers/document_par_defaut.pdf';

  Future<Map<String, dynamic>> _uploadPhotoBase64(String imagePath, String token) async {
    try {
      // Lire le fichier image
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final fileName = _profilePhotoName ?? path.basename(imagePath);

      print('=== DEBUG BASE64 UPLOAD ===');
      print('Image encodée en base64, taille: ${base64Image.length} caractères');
      print('Nom du fichier: $fileName');

      // Envoyer vers l'endpoint base64 avec le bon token
      final response = await ApiService.postWithToken(
        'professional/profile-photo',
        token: token,
        data: {
          'profile_photo_base64': base64Image,
          'profile_photo_name': fileName,
        },
      );

      print('=== DEBUG REQUEST ===');
      print('URL: ${AppConfig.baseUrl}/api/professional/profile-photo');
      print('Body envoyé: ${jsonEncode({
        'profile_photo_base64': base64Image.substring(0, 50) + '...',
        'profile_photo_name': fileName,
      })}');

      if (response != null) {
        print('Réponse upload base64 - Body: $response');
        return {
          'success': true,
          'message': 'Photo uploadée avec succès',
          'data': response,
        };
      } else {
        return {
          'success': false,
          'message': 'Erreur lors de l\'upload de la photo',
        };
      }
    } catch (e) {
      print('Exception lors de l\'encodage base64: $e');
      return {
        'success': false,
        'message': 'Erreur lors de l\'encodage: $e',
      };
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      setState(() => _isUploading = true);

      // Préparer les données du formulaire
      final formData = {
        'company_name': _companyNameCtrl.text.trim(),
        'rccm_number': _rccmNumberCtrl.text.trim(),
        'job_title': _jobTitleCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'postal_code': _postalCodeCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'hourly_rate': double.tryParse(_hourlyRateCtrl.text) ?? 0,
        'min_price': double.tryParse(_minPriceCtrl.text) ?? 0,
        'max_price': double.tryParse(_maxPriceCtrl.text) ?? 0,
        'radius_km': int.tryParse(_radiusKmCtrl.text) ?? 0,
        'experience_years': int.tryParse(_experienceYearsCtrl.text) ?? 0,
        'is_available': _isAvailable,
        'skills': _skills,
        'business_hours': _getBusinessHoursJson(),
        'profile_completed': true,
        'id_document_path': USE_DEFAULT_DOCUMENT 
            ? DEFAULT_DOCUMENT_PATH 
            : _idDocumentPath,
      };

      // Récupérer le token d'authentification
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      // Traiter la photo de profil si elle existe
      if (_profilePhotoPath != null) {
        try {
          final file = File(_profilePhotoPath!);
          final fileSize = await file.length();
          
          // Vérifier la taille du fichier (max 5MB)
          if (fileSize > 5 * 1024 * 1024) {
            throw Exception('La taille de l\'image ne doit pas dépasser 5MB');
          }
          
          // Lire et encoder l'image en base64
          final bytes = await file.readAsBytes();
          final base64Image = base64Encode(bytes);
          final fileName = _profilePhotoName ?? path.basename(_profilePhotoPath!);
          
          // Ajouter les informations de la photo aux données du formulaire
          formData['profile_photo_base64'] = 'data:image/jpeg;base64,$base64Image';
          formData['profile_photo_name'] = fileName;
          
          print('=== DEBUG: Photo encodée en base64 - Taille: ${base64Image.length} caractères');
          print('=== DEBUG: Nom du fichier: $fileName');
          
        } catch (e) {
          print('Erreur lors du traitement de l\'image: $e');
          rethrow;
        }
      }

      // Préparer l'en-tête de la requête
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // Ajouter le token d'authentification depuis la variable token existante
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      print('Envoi de la requête...');
      print('URL: ${AppConfig.baseUrl}/api/professional/profile/complete');
      
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/professional/profile/complete'),
        headers: headers,
        body: jsonEncode(formData),
      );
      
      print('Réponse du serveur (${response.statusCode}): ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Décodage de la réponse
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil mis à jour avec succès')),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de la mise à jour du profil');
      }

    } catch (e) {
      print('Erreur lors de l\'envoi du formulaire: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Section Photo de profil
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Photo de profil (optionnel)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(color: Colors.grey[400]!, width: 2),
                          ),
                          child: _profilePhotoPath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(38),
                                  child: Image.file(
                                    File(_profilePhotoPath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.person, size: 40, color: Colors.grey);
                                    },
                                  ),
                                )
                              : const Icon(Icons.person, size: 40, color: Colors.grey),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _pickProfilePhoto,
                                icon: const Icon(Icons.photo_camera, size: 16),
                                label: Text(_profilePhotoPath != null ? 'Changer la photo' : 'Ajouter une photo'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _profilePhotoPath != null ? const Color(0xFFFFCC00) : const Color(0xFFFFCC00),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              if (_profilePhotoPath != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _profilePhotoName ?? 'Photo sélectionnée',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _profilePhotoPath = null;
                                      _profilePhotoName = null;
                                    });
                                  },
                                  child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Formats acceptés : JPG, PNG (max 5MB)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Section Informations générales
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Informations générales',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _companyNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l\'entreprise',
                        border: OutlineInputBorder(),
                      ),
                      validator: RequiredValidator(errorText: 'Ce champ est requis'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _rccmNumberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Numéro RCCM',
                        border: OutlineInputBorder(),
                      ),
                      validator: RequiredValidator(errorText: 'Ce champ est requis'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _jobTitleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Poste occupé',
                        border: OutlineInputBorder(),
                      ),
                      validator: RequiredValidator(errorText: 'Ce champ est requis'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description de l\'entreprise',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                      validator: RequiredValidator(errorText: 'Ce champ est requis'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Section Document d'identité
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Document d\'identité',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (_idDocumentPath != null) ...[
                      Text(
                        'Document sélectionné: ${_idDocumentPath?.split('/').last}',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 8),
                    ],
                    ElevatedButton.icon(
                      onPressed: _pickDocument,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Sélectionner un document'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFCC00),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Section Compétences
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Compétences',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildSkillsList(),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showAddSkillDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une compétence'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFCC00),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Section Coordonnées
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Coordonnées',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Adresse',
                        border: OutlineInputBorder(),
                      ),
                      validator: RequiredValidator(errorText: 'Ce champ est requis'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _cityCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Ville',
                              border: OutlineInputBorder(),
                            ),
                            validator: RequiredValidator(errorText: 'Ville requise'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _postalCodeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Code postal',
                              border: OutlineInputBorder(),
                            ),
                            validator: RequiredValidator(errorText: 'Code postal requis'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _websiteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Site web (optionnel)',
                        border: OutlineInputBorder(),
                        prefixText: 'https://',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Section Tarification
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Tarification',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _hourlyRateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Taux horaire (FCFA)',
                        border: OutlineInputBorder(),
                        prefixText: 'FCFA ',
                      ),
                      keyboardType: TextInputType.number,
                      validator: RequiredValidator(errorText: 'Ce champ est requis'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _minPriceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Prix min (FCFA)',
                              border: OutlineInputBorder(),
                              prefixText: 'FCFA ',
                            ),
                            keyboardType: TextInputType.number,
                            validator: RequiredValidator(errorText: 'Requis'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _maxPriceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Prix max (FCFA)',
                              border: OutlineInputBorder(),
                              prefixText: 'FCFA ',
                            ),
                            keyboardType: TextInputType.number,
                            validator: RequiredValidator(errorText: 'Requis'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _radiusKmCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Rayon d\'intervention (km)',
                        border: OutlineInputBorder(),
                        suffixText: 'km',
                      ),
                      keyboardType: TextInputType.number,
                      validator: RequiredValidator(errorText: 'Ce champ est requis'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Section Expérience
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Expérience',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _experienceYearsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Années d\'expérience',
                        border: OutlineInputBorder(),
                        suffixText: 'ans',
                      ),
                      keyboardType: TextInputType.number,
                      validator: RequiredValidator(errorText: 'Ce champ est requis'),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Disponible pour de nouvelles missions'),
                      value: _isAvailable,
                      onChanged: (bool value) {
                        setState(() {
                          _isAvailable = value;
                        });
                      },
                      activeColor: const Color(0xFFFFCC00),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Section Téléchargement de documents
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Documents professionnels',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Document d\'identité personnel ou professionnel',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Formats acceptés : '),
                          TextSpan(
                            text: '${(DocumentService.allowedExtensions['id_document'] ?? []).join(", ")}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const TextSpan(text: '\nTaille maximale : '),
                          const TextSpan(
                            text: '5 MB',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    if (!USE_DEFAULT_DOCUMENT) ...[
                      if (_idDocumentPath != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.insert_drive_file, size: 24, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _idDocumentName!,
                                      style: const TextStyle(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Afficher un aperçu si c'est une image
                                  if (_idDocumentPath!.toLowerCase().endsWith('.jpg') ||
                                      _idDocumentPath!.toLowerCase().endsWith('.jpeg') ||
                                      _idDocumentPath!.toLowerCase().endsWith('.png'))
                                    IconButton(
                                      icon: const Icon(Icons.image, size: 20),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => Dialog(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                AppBar(
                                                  title: Text(_idDocumentName!),
                                                  leading: IconButton(
                                                    icon: const Icon(Icons.close),
                                                    onPressed: () => Navigator.of(context).pop(),
                                                  ),
                                                ),
                                                Image.file(
                                                  File(_idDocumentPath!),
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return const Padding(
                                                      padding: EdgeInsets.all(16.0),
                                                      child: Icon(Icons.broken_image, size: 64),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _idDocumentPath = null;
                                        _idDocumentName = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _isUploading ? null : _pickDocument,
                          icon: const Icon(Icons.upload_file, size: 20),
                          label: const Text('Télécharger un document d\'identité'),
                        ),

                    ] else
                      const Text(
                        'Document par défaut utilisé pour les tests',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Section Horaires d'ouverture
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Horaires d\'ouverture',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ..._buildBusinessHoursList(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Bouton de soumission
            ElevatedButton(
              onPressed: widget.isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFFFFCC00),
                foregroundColor: Colors.white,
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Enregistrer le profil',
                      style: TextStyle(fontSize: 16),
                    ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsList() {
    if (_skills.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Aucune compétence ajoutée',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _skills.length,
      itemBuilder: (context, index) {
        final skill = _skills[index];
        return ListTile(
          title: Text(skill['name'] ?? ''),
          subtitle: Text('Niveau: ${skill['level'] ?? ''}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _removeSkill(index),
          ),
        );
      },
    );
  }

  List<Widget> _buildBusinessHoursList() {
    return _businessHours.entries.map((entry) {
      final String day = entry.key;
      final String openTime = entry.value['open'] ?? '';
      final String closeTime = entry.value['close'] ?? '';
      final bool isClosed = openTime.isEmpty || closeTime.isEmpty;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          Text(
            '${day[0].toUpperCase()}${day.substring(1)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final TimeOfDay? time = await showTimePicker(
                      context: context,
                      initialTime: isClosed
                          ? const TimeOfDay(hour: 9, minute: 0)
                          : TimeOfDay(
                              hour: int.parse(openTime.split(':')[0]),
                              minute: int.parse(openTime.split(':')[1]),
                            ),
                    );
                    if (time != null) {
                      _updateBusinessHours(
                        day,
                        'open',
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                      );
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Ouverture',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time, size: 20),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: Text(isClosed ? '--:--' : openTime),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('à'),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final TimeOfDay? time = await showTimePicker(
                      context: context,
                      initialTime: isClosed
                          ? const TimeOfDay(hour: 18, minute: 0)
                          : TimeOfDay(
                              hour: int.parse(closeTime.split(':')[0]),
                              minute: int.parse(closeTime.split(':')[1]),
                            ),
                    );
                    if (time != null) {
                      _updateBusinessHours(
                        day,
                        'close',
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                      );
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fermeture',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time, size: 20),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: Text(isClosed ? '--:--' : closeTime),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  _updateBusinessHours(day, 'open', '');
                  _updateBusinessHours(day, 'close', '');
                },
                tooltip: 'Fermé ce jour',
              ),
            ],
          ),
          const Divider(),
        ],
      );
    }).toList();
  }
}

// Extension pour formater l'heure
extension TimeOfDayExtension on TimeOfDay {
  String format(BuildContext context) {
    final format = MaterialLocalizations.of(context);
    return format.formatTimeOfDay(this);
  }
}
