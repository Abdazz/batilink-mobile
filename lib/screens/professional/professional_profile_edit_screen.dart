import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfessionalProfileEditScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> currentProfile;

  const ProfessionalProfileEditScreen({
    Key? key,
    required this.token,
    required this.currentProfile,
  }) : super(key: key);

  @override
  _ProfessionalProfileEditScreenState createState() => _ProfessionalProfileEditScreenState();
}

class _ProfessionalProfileEditScreenState extends State<ProfessionalProfileEditScreen> {
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
  final TextEditingController _linkedinProfileCtrl = TextEditingController();
  final TextEditingController _hourlyRateCtrl = TextEditingController();
  final TextEditingController _minPriceCtrl = TextEditingController();
  final TextEditingController _maxPriceCtrl = TextEditingController();
  final TextEditingController _radiusKmCtrl = TextEditingController();
  final TextEditingController _experienceYearsCtrl = TextEditingController();

  // Variables d'état
  bool _isAvailable = true;
  String? _profilePhotoPath;
  String? _profilePhotoName;
  bool _isLoading = false;
  List<Map<String, dynamic>> _skills = [];
  final TextEditingController _skillNameCtrl = TextEditingController();
  String? _selectedLevel;
  List<String> _acceptedPaymentMethods = [];

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
    // Pré-remplir les contrôleurs avec les données existantes
    _companyNameCtrl.text = widget.currentProfile['company_name'] ?? '';
    _rccmNumberCtrl.text = widget.currentProfile['rccm_number'] ?? '';
    _jobTitleCtrl.text = widget.currentProfile['job_title'] ?? '';
    _descriptionCtrl.text = widget.currentProfile['description'] ?? '';
    _addressCtrl.text = widget.currentProfile['address'] ?? '';
    _cityCtrl.text = widget.currentProfile['city'] ?? '';
    _postalCodeCtrl.text = widget.currentProfile['postal_code'] ?? '';
    _websiteCtrl.text = widget.currentProfile['website'] ?? '';
    _linkedinProfileCtrl.text = widget.currentProfile['linkedin_profile'] ?? '';
    _hourlyRateCtrl.text = widget.currentProfile['hourly_rate']?.toString() ?? '';
    _minPriceCtrl.text = widget.currentProfile['min_price']?.toString() ?? '';
    _maxPriceCtrl.text = widget.currentProfile['max_price']?.toString() ?? '';
    _radiusKmCtrl.text = widget.currentProfile['radius_km']?.toString() ?? '';
    _experienceYearsCtrl.text = widget.currentProfile['experience_years']?.toString() ?? '';
    _isAvailable = widget.currentProfile['is_available'] ?? true;

    // Charger les méthodes de paiement acceptées
    final paymentMethodsData = widget.currentProfile['accepted_payment_methods'];
    if (paymentMethodsData is List) {
      _acceptedPaymentMethods = List<String>.from(paymentMethodsData);
    } else {
      _acceptedPaymentMethods = [];
    }

    // Charger les compétences existantes
    final skillsData = widget.currentProfile['skills'];
    if (skillsData is List) {
      _skills = List<Map<String, dynamic>>.from(skillsData.map((skill) =>
        skill is Map<String, dynamic> ? skill : Map<String, dynamic>.from(skill)
      ));
    } else {
      _skills = [];
    }

    // Charger les horaires d'ouverture existants
    if (widget.currentProfile['business_hours'] != null) {
      try {
        // Les horaires peuvent être soit un Map, soit une String JSON
        dynamic businessHoursData = widget.currentProfile['business_hours'];

        // Si c'est une String, la décoder en JSON
        if (businessHoursData is String && businessHoursData.isNotEmpty) {
          businessHoursData = json.decode(businessHoursData);
        }

        // S'assurer que c'est bien un Map
        if (businessHoursData is Map<String, dynamic>) {
          businessHoursData.forEach((day, hours) {
            if (_businessHours.containsKey(day) && hours is Map) {
              _businessHours[day]!['open'] = hours['open']?.toString() ?? '';
              _businessHours[day]!['close'] = hours['close']?.toString() ?? '';
            }
          });
        }
      } catch (e) {
        print('Erreur lors du traitement des horaires d\'ouverture: $e');
        // Garder les horaires par défaut en cas d'erreur
      }
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
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

  Widget _buildPaymentMethodsSection() {
    final paymentMethods = [
      {'key': 'especes', 'label': 'Espèces'},
      {'key': 'virement', 'label': 'Virement bancaire'},
      {'key': 'mobile_money', 'label': 'Mobile Money'},
      {'key': 'cheque', 'label': 'Chèque'},
      {'key': 'carte', 'label': 'Carte bancaire'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: paymentMethods.map((method) {
        final isSelected = _acceptedPaymentMethods.contains(method['key']);
        return FilterChip(
          label: Text(method['label']!),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _acceptedPaymentMethods.add(method['key']!);
              } else {
                _acceptedPaymentMethods.remove(method['key']);
              }
            });
          },
          backgroundColor: Colors.grey[100],
          selectedColor: const Color(0xFF4CAF50).withOpacity(0.2),
          checkmarkColor: const Color(0xFF4CAF50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[300]!,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getBusinessHoursJson() {
    return jsonEncode(_businessHours);
  }

  Future<Map<String, dynamic>> _uploadPhotoBase64(String imagePath, String token) async {
    try {
      // Lire le fichier image
      final file = File(imagePath);
      final bytes = await file.readAsBytes();

      // Encoder en base64
      final base64Image = base64Encode(bytes);

      print('=== DEBUG BASE64 UPLOAD ===');
      print('Image encodée en base64, taille: ${base64Image.length} caractères');
      print('Nom du fichier: ${_profilePhotoName ?? 'profile_photo.jpg'}');

      // Envoyer vers l'endpoint base64
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/professional/profile-photo'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'profile_photo_base64': base64Image,
          'profile_photo_name': _profilePhotoName ?? 'profile_photo.jpg',
        }),
      );

      print('=== DEBUG REQUEST ===');
      print('URL: http://10.0.2.2:8000/api/professional/profile-photo');
      print('Headers: {Authorization: Bearer $token, Content-Type: application/json, Accept: application/json}');
      print('Body envoyé: ${jsonEncode({
        'profile_photo_base64': base64Image.substring(0, 50) + '...',
        'profile_photo_name': _profilePhotoName ?? 'profile_photo.jpg',
      })}');

      print('Réponse upload base64 - Status: ${response.statusCode}');
      print('Réponse upload base64 - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'Photo uploadée avec succès',
          'data': responseData,
        };
      } else {
        return {
          'success': false,
          'message': 'Erreur serveur: ${response.statusCode} - ${response.body}',
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
      setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? widget.token;

      // Construire seulement les champs qui ont été modifiés
      final Map<String, dynamic> updatedFields = {};

      // Vérifier chaque champ et ajouter seulement s'il a été modifié
      if (_companyNameCtrl.text.trim() != (widget.currentProfile['company_name'] ?? '')) {
        updatedFields['company_name'] = _companyNameCtrl.text.trim();
      }
      if (_rccmNumberCtrl.text.trim() != (widget.currentProfile['rccm_number'] ?? '')) {
        updatedFields['rccm_number'] = _rccmNumberCtrl.text.trim();
      }
      if (_jobTitleCtrl.text.trim() != (widget.currentProfile['job_title'] ?? '')) {
        updatedFields['job_title'] = _jobTitleCtrl.text.trim();
      }
      if (_descriptionCtrl.text.trim() != (widget.currentProfile['description'] ?? '')) {
        updatedFields['description'] = _descriptionCtrl.text.trim();
      }
      if (_addressCtrl.text.trim() != (widget.currentProfile['address'] ?? '')) {
        updatedFields['address'] = _addressCtrl.text.trim();
      }
      if (_cityCtrl.text.trim() != (widget.currentProfile['city'] ?? '')) {
        updatedFields['city'] = _cityCtrl.text.trim();
      }
      if (_postalCodeCtrl.text.trim() != (widget.currentProfile['postal_code'] ?? '')) {
        updatedFields['postal_code'] = _postalCodeCtrl.text.trim();
      }
      if (_websiteCtrl.text.trim() != (widget.currentProfile['website'] ?? '')) {
        updatedFields['website'] = _websiteCtrl.text.trim();
      }
      if (_linkedinProfileCtrl.text.trim() != (widget.currentProfile['linkedin_profile'] ?? '')) {
        updatedFields['linkedin_profile'] = _linkedinProfileCtrl.text.trim();
      }

      // Vérifier les méthodes de paiement acceptées
      final currentPaymentMethods = widget.currentProfile['accepted_payment_methods'];
      final oldPaymentMethods = currentPaymentMethods is List ? currentPaymentMethods : [];

      if (_acceptedPaymentMethods.length != oldPaymentMethods.length ||
          !_acceptedPaymentMethods.every((method) => oldPaymentMethods.contains(method))) {
        updatedFields['accepted_payment_methods'] = _acceptedPaymentMethods;
      }
      final newHourlyRate = double.tryParse(_hourlyRateCtrl.text) ?? 0;
      final oldHourlyRate = widget.currentProfile['hourly_rate'] ?? 0;
      if (newHourlyRate != oldHourlyRate) {
        updatedFields['hourly_rate'] = newHourlyRate;
      }

      final newMinPrice = double.tryParse(_minPriceCtrl.text) ?? 0;
      final oldMinPrice = widget.currentProfile['min_price'] ?? 0;
      if (newMinPrice != oldMinPrice) {
        updatedFields['min_price'] = newMinPrice;
      }

      final newMaxPrice = double.tryParse(_maxPriceCtrl.text) ?? 0;
      final oldMaxPrice = widget.currentProfile['max_price'] ?? 0;
      if (newMaxPrice != oldMaxPrice) {
        updatedFields['max_price'] = newMaxPrice;
      }

      final newRadiusKm = int.tryParse(_radiusKmCtrl.text) ?? 0;
      final oldRadiusKm = widget.currentProfile['radius_km'] ?? 0;
      if (newRadiusKm != oldRadiusKm) {
        updatedFields['radius_km'] = newRadiusKm;
      }

      final newExperienceYears = int.tryParse(_experienceYearsCtrl.text) ?? 0;
      final oldExperienceYears = widget.currentProfile['experience_years'] ?? 0;
      if (newExperienceYears != oldExperienceYears) {
        updatedFields['experience_years'] = newExperienceYears;
      }

      // Vérifier le statut de disponibilité
      if (_isAvailable != (widget.currentProfile['is_available'] ?? true)) {
        updatedFields['is_available'] = _isAvailable;
      }

      // Vérifier les compétences (comparaison simplifiée)
      final currentSkills = widget.currentProfile['skills'];
      final skillsLength = currentSkills is List ? currentSkills.length : 0;

      if (_skills.length != skillsLength) {
        updatedFields['skills'] = _skills;
      } else {
        // Comparaison plus détaillée si nécessaire
        updatedFields['skills'] = _skills;
      }

      // Vérifier les horaires d'ouverture
      final newBusinessHours = _getBusinessHoursJson();

      // Gérer l'ancien format des horaires (peut être String ou Map)
      String oldBusinessHours;
      try {
        final businessHoursData = widget.currentProfile['business_hours'];
        if (businessHoursData is String) {
          oldBusinessHours = businessHoursData;
        } else if (businessHoursData is Map) {
          oldBusinessHours = jsonEncode(businessHoursData);
        } else {
          oldBusinessHours = '{}';
        }
      } catch (e) {
        oldBusinessHours = '{}';
      }

      if (newBusinessHours != oldBusinessHours) {
        updatedFields['business_hours'] = newBusinessHours;
      }

      // N'envoyer que si il y a des modifications
      if (updatedFields.isEmpty && _profilePhotoPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune modification détectée')),
        );
        return;
      }

      print('Champs modifiés: $updatedFields');

      // Étape 1: Mettre à jour les autres champs normalement
      if (updatedFields.isNotEmpty) {
        final response = await http.put(
          Uri.parse('http://10.0.2.2:8000/api/professional/profile'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(updatedFields),
        );

        print('Réponse autres champs - Status: ${response.statusCode}');
        if (response.statusCode != 200) {
          print('Erreur mise à jour autres champs: ${response.body}');
        }
      }

      // Étape 2: Uploader la photo en base64 si elle existe
      if (_profilePhotoPath != null) {
        try {
          print('Upload de la photo en base64...');
          final uploadResponse = await _uploadPhotoBase64(_profilePhotoPath!, token);

          if (uploadResponse['success'] == true) {
            print('Photo uploadée avec succès');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profil et photo mis à jour avec succès')),
            );
          } else {
            print('Erreur upload photo: ${uploadResponse['message']}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur upload photo: ${uploadResponse['message']}')),
            );
          }
        } catch (e) {
          print('Exception lors de l\'upload de la photo: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de l\'upload de la photo: $e')),
          );
        }
      } else {
        // Pas de photo à uploader, juste afficher le succès
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour avec succès')),
        );
      }

      // Retourner true pour indiquer que les modifications ont été sauvegardées
      Navigator.of(context).pop(true);
    } catch (e) {
      print('Erreur lors de la mise à jour du profil: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
    _linkedinProfileCtrl.dispose();
    _hourlyRateCtrl.dispose();
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    _radiusKmCtrl.dispose();
    _experienceYearsCtrl.dispose();
    super.dispose();
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
          'Modifier le profil',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _submitForm,
              child: Text(
                'Sauvegarder',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF4CAF50),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section Informations générales
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informations générales',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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

              // Section Photo de profil
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Photo de profil',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                                : widget.currentProfile['profile_photo_url'] != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(38),
                                        child: Image.network(
                                          widget.currentProfile['profile_photo_url'],
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
                                  label: Text(_profilePhotoPath != null ? 'Changer la photo' : 'Modifier la photo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _profilePhotoPath != null ? Colors.orange : Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                if (_profilePhotoPath != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _profilePhotoName ?? 'Nouvelle photo sélectionnée',
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
                                    child: const Text('Annuler', style: TextStyle(color: Colors.red)),
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

              // Section Compétences
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compétences',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSkillsList(),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showAddSkillDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une compétence'),
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
                    children: [
                      Text(
                        'Coordonnées',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                        children: [
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _linkedinProfileCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Profil LinkedIn (optionnel)',
                          border: OutlineInputBorder(),
                          prefixText: 'https://',
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Méthodes de paiement acceptées',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPaymentMethodsSection(),
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
                    children: [
                      Text(
                        'Tarification',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                        children: [
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
                    children: [
                      Text(
                        'Expérience',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Bouton de soumission
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Sauvegarder les modifications',
                        style: GoogleFonts.poppins(fontSize: 16),
                      ),
              ),

              const SizedBox(height: 16),
            ],
          ),
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
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    );
  }
}
