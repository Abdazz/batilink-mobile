import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/app_config.dart';
import '../../models/business_hours.dart';
import '../../widgets/custom_text_field.dart';
import 'business_hours_screen.dart';
import 'documents_screen.dart';

class EditProfessionalProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final String token;

  const EditProfessionalProfileScreen({
    Key? key,
    this.initialData,
    required this.token,
  }) : super(key: key);

  @override
  _EditProfessionalProfileScreenState createState() => _EditProfessionalProfileScreenState();
}

class _EditProfessionalProfileScreenState extends State<EditProfessionalProfileScreen> with TickerProviderStateMixin {
  // Contrôleurs et états
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  
  // Gestion de l'image de profil
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  
  // Contrôleurs de texte
  final _companyNameController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _experienceYearsController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _radiusKmController = TextEditingController();
  
  // Gestion des horaires d'ouverture
  List<BusinessHours> _businessHours = [
    BusinessHours(day: 'Lundi', isOpen: true, openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 18, minute: 0)),
    BusinessHours(day: 'Mardi', isOpen: true, openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 18, minute: 0)),
    BusinessHours(day: 'Mercredi', isOpen: true, openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 18, minute: 0)),
    BusinessHours(day: 'Jeudi', isOpen: true, openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 18, minute: 0)),
    BusinessHours(day: 'Vendredi', isOpen: true, openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 18, minute: 0)),
    BusinessHours(day: 'Samedi', isOpen: false, openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 12, minute: 0)),
    BusinessHours(day: 'Dimanche', isOpen: false, openTime: const TimeOfDay(hour: 0, minute: 0), closeTime: const TimeOfDay(hour: 0, minute: 0)),
  ];

  // Gestion des documents
  List<Document> _documents = [];
  
  // État de disponibilité
  final _isAvailableNotifier = ValueNotifier<bool>(false);

  Future<void> _loadInitialData() async {
    try {
      debugPrint('=== CHARGEMENT DES DONNÉES INITIALES ===');
      final data = widget.initialData;
      
      if (data != null) {
        debugPrint('Données initiales reçues: ${jsonEncode(data)}');
        
        // Données de base de l'utilisateur
        _formData['first_name'] = data['first_name'] ?? data['user']?['first_name'] ?? '';
        _formData['last_name'] = data['last_name'] ?? data['user']?['last_name'] ?? '';
        
        // Données du profil professionnel
        final professional = data['professional'] ?? data;
        
        debugPrint('Données professionnelles: ${jsonEncode(professional)}');
        
        setState(() {
          // Données de base
          _companyNameController.text = professional['company_name']?.toString() ?? '';
          _jobTitleController.text = professional['job_title']?.toString() ?? '';
          _descriptionController.text = professional['description']?.toString() ?? '';
          
          // Numériques avec gestion des valeurs nulles
          _experienceYearsController.text = (professional['experience_years'] ?? 0).toString();
          _hourlyRateController.text = (professional['hourly_rate'] ?? 0.0).toString();
          _minPriceController.text = (professional['min_price'] ?? 0.0).toString();
          _maxPriceController.text = (professional['max_price'] ?? 0.0).toString();
          
          // Adresse
          _addressController.text = professional['address']?.toString() ?? '';
          _cityController.text = professional['city']?.toString() ?? '';
          _postalCodeController.text = professional['postal_code']?.toString() ?? '';
          _radiusKmController.text = (professional['radius_km'] ?? 10).toString();
          
          // Disponibilité
          _isAvailableNotifier.value = professional['is_available'] == true;
          
          // Charger l'image de profil
          final avatar = professional['avatar'] ?? data['user']?['avatar'];
          if (avatar != null) {
            _formData['profile_image'] = avatar.toString();
            debugPrint('Avatar chargé: ${_formData['profile_image']}');
          }
          
          // Charger les horaires d'ouverture
          if (professional['business_hours'] != null) {
            try {
              final hoursData = professional['business_hours'] is String 
                  ? json.decode(professional['business_hours'])
                  : professional['business_hours'];
                  
              debugPrint('=== CHARGEMENT DES HORAIRES ===');
              debugPrint('Type des données: ${hoursData.runtimeType}');
              debugPrint('Contenu: $hoursData');
              
              _businessHours = _businessHours.map((hour) {
                final day = hour.day.toLowerCase();
                debugPrint('Traitement du jour: $day');
                
                if (hoursData[day] is Map && hoursData[day]['is_closed'] != true) {
                  final openTimeStr = hoursData[day]['open']?.toString() ?? '';
                  final closeTimeStr = hoursData[day]['close']?.toString() ?? '';
                  
                  debugPrint('$day: open=$openTimeStr, close=$closeTimeStr');
                  
                  if (openTimeStr.isNotEmpty && closeTimeStr.isNotEmpty) {
                    try {
                      final openTimeParts = openTimeStr.split(':');
                      final closeTimeParts = closeTimeStr.split(':');
                      
                      if (openTimeParts.length >= 2 && closeTimeParts.length >= 2) {
                        final openHour = int.tryParse(openTimeParts[0]) ?? 0;
                        final openMinute = int.tryParse(openTimeParts[1]) ?? 0;
                        final closeHour = int.tryParse(closeTimeParts[0]) ?? 0;
                        final closeMinute = int.tryParse(closeTimeParts[1]) ?? 0;
                        
                        debugPrint('$day: $openHour:$openMinute - $closeHour:$closeMinute');
                        
                        return hour.copyWith(
                          isOpen: true,
                          openTime: TimeOfDay(hour: openHour, minute: openMinute),
                          closeTime: TimeOfDay(hour: closeHour, minute: closeMinute),
                        );
                      }
                    } catch (e) {
                      debugPrint('Erreur lors du parsing des heures pour $day: $e');
                    }
                  }
                  
                  // Si on arrive ici, il y a eu un problème avec les heures
                  return hour.copyWith(
                    isOpen: false,
                    openTime: const TimeOfDay(hour: 9, minute: 0),
                    closeTime: const TimeOfDay(hour: 18, minute: 0),
                  );
                }
                
                // Si le jour est marqué comme fermé ou n'existe pas dans les données
                return hour.copyWith(
                  isOpen: false,
                  openTime: hour.openTime ?? const TimeOfDay(hour: 0, minute: 0),
                  closeTime: hour.closeTime ?? const TimeOfDay(hour: 0, minute: 0),
                );
              }).toList();
              
              // Afficher les horaires chargés pour le débogage
              debugPrint('=== HORAIRES CHARGÉS ===');
              for (var h in _businessHours) {
                debugPrint('${h.day}: ${h.isOpen ? "${h.openTime?.format(context) ?? 'N/A'} - ${h.closeTime?.format(context) ?? 'N/A'}" : "Fermé"}');
              }
              
            } catch (e) {
              debugPrint('Erreur lors du chargement des horaires: $e');
              if (e is Error) {
                debugPrint('Stack trace: ${e.stackTrace}');
              }
            }
          } else {
            debugPrint('Aucun horaire d\'ouverture trouvé dans les données');
            
            // Si pas d'horaires, on garde les valeurs par défaut
            _businessHours = [
              BusinessHours(day: 'Lundi', isOpen: true, openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 18, minute: 0)),
              BusinessHours(day: 'Mardi', isOpen: true, openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 18, minute: 0)),
              BusinessHours(day: 'Mercredi', isOpen: true, openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 18, minute: 0)),
              BusinessHours(day: 'Jeudi', isOpen: true, openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 18, minute: 0)),
              BusinessHours(day: 'Vendredi', isOpen: true, openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 18, minute: 0)),
              BusinessHours(day: 'Samedi', isOpen: false, openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 12, minute: 0)),
              BusinessHours(day: 'Dimanche', isOpen: false, openTime: const TimeOfDay(hour: 0, minute: 0), closeTime: const TimeOfDay(hour: 0, minute: 0)),
            ];
          }
          
          // Charger les documents
          if (professional['documents'] != null) {
            try {
              _documents = (json.decode(professional['documents']) as List)
                  .map((item) => Document.fromJson(item))
                  .toList();
            } catch (e) {
              debugPrint('Erreur lors du chargement des documents: $e');
              _documents = [];
            }
          } else {
            _documents = [];
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des données initiales: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des données: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      
      if (image != null) {
        // Lire et encoder l'image en base64
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        
        // Déterminer le type MIME de l'image
        final extension = image.path.split('.').last.toLowerCase();
        String mimeType = 'image/jpeg'; // Par défaut
        
        if (extension == 'png') {
          mimeType = 'image/png';
        } else if (extension == 'gif') {
          mimeType = 'image/gif';
        } else if (extension == 'webp') {
          mimeType = 'image/webp';
        }
        
        setState(() {
          _profileImage = File(image.path);
          // Stocker l'image au format attendu par l'API
          _formData['avatar_base64'] = 'data:$mimeType;base64,$base64Image';
        });
        
        // Afficher un message de succès
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image sélectionnée avec succès')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection de l\'image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    // Vérifier si le widget est toujours monté
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Vérifier si le formulaire est initialisé
      if (_formKey.currentState == null) {
        debugPrint('Erreur: Le formulaire n\'est pas encore initialisé');
        throw Exception('Le formulaire n\'est pas encore prêt');
      }
      
      // Sauvegarder l'état du formulaire
      _formKey.currentState!.save();
      
      // Valider le formulaire
      if (!_formKey.currentState!.validate()) {
        debugPrint('Validation du formulaire échouée');
        throw Exception('Veuillez corriger les erreurs dans le formulaire');
      }

      debugPrint('=== PRÉPARATION DES DONNÉES ===');
      
      // Préparer les données du profil selon le format attendu par l'API
      final Map<String, dynamic> requestData = {
        // Données de base de l'utilisateur
        'first_name': _formData['first_name']?.toString().trim() ?? '',
        'last_name': _formData['last_name']?.toString().trim() ?? '',
      };
      
      // Données du profil professionnel
      final Map<String, dynamic> professionalData = {
        'company_name': _companyNameController.text.trim(),
        'job_title': _jobTitleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'experience_years': int.tryParse(_experienceYearsController.text) ?? 0,
        'hourly_rate': (double.tryParse(_hourlyRateController.text) ?? 0.0).toStringAsFixed(2),
        'min_price': (double.tryParse(_minPriceController.text) ?? 0.0).toStringAsFixed(2),
        'max_price': (double.tryParse(_maxPriceController.text) ?? 0.0).toStringAsFixed(2),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'postal_code': _postalCodeController.text.trim(),
        'radius_km': int.tryParse(_radiusKmController.text) ?? 10,
        'is_available': _isAvailableNotifier.value,
      };
      
      // Ajouter les données professionnelles à la requête
      requestData['professional'] = professionalData;

      // Ajouter l'avatar s'il a été modifié
      if (_formData['avatar_base64'] != null) {
        requestData['avatar_base64'] = _formData['avatar_base64'];
        debugPrint('Avatar ajouté à la requête');
      }

      // Convertir les horaires d'ouverture au format attendu
      final Map<String, dynamic> businessHoursMap = {};
      
      debugPrint('=== ENREGISTREMENT DES HORAIRES ===');
      
      for (var hours in _businessHours) {
        final day = hours.day.toLowerCase();
        
        if (hours.isOpen && hours.openTime != null && hours.closeTime != null) {
          final openTime = '${hours.openTime!.hour.toString().padLeft(2, '0')}:${hours.openTime!.minute.toString().padLeft(2, '0')}';
          final closeTime = '${hours.closeTime!.hour.toString().padLeft(2, '0')}:${hours.closeTime!.minute.toString().padLeft(2, '0')}';
          
          debugPrint('$day: $openTime - $closeTime');
          
          businessHoursMap[day] = {
            'open': openTime,
            'close': closeTime,
            'is_closed': false,
          };
        } else {
          debugPrint('$day: Fermé');
          businessHoursMap[day] = {
            'open': '',
            'close': '',
            'is_closed': true,
          };
        }
      }
      
      final businessHoursJson = json.encode(businessHoursMap);
      debugPrint('Horaire JSON: $businessHoursJson');
      
      // Ajouter les horaires aux données professionnelles
      requestData['professional']['business_hours'] = businessHoursJson;

      // Afficher les données qui seront envoyées pour débogage
      debugPrint('=== DONNÉES À ENVOYER ===');
      debugPrint(jsonEncode(requestData));

      // Envoyer la requête de mise à jour
      debugPrint('Envoi de la requête à ${AppConfig.baseUrl}/api/professional/profile');
      
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/api/professional/profile'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestData),
      );

      debugPrint('=== RÉPONSE DU SERVEUR ===');
      debugPrint('Statut: ${response.statusCode}');
      debugPrint('Corps: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        debugPrint('Réponse décodée: $responseData');
        
        if (mounted) {
          // Afficher un message de succès
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil mis à jour avec succès'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Retourner les données mises à jour à l'écran parent
          Navigator.of(context).pop({
            'success': true,
            'data': {
              ..._formData,
              'professional': {
                ...professionalData,
                'business_hours': businessHoursJson,
              },
              'avatar': responseData['data']?['avatar'] ?? _formData['avatar'],
            }
          });
        }
      } else {
        String errorMessage = 'Erreur lors de la mise à jour du profil';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message']?.toString() ?? errorMessage;
          if (errorData['errors'] != null) {
            errorMessage += '\n' + errorData['errors'].toString();
          }
          debugPrint('Erreur détaillée: $errorMessage');
        } catch (e) {
          errorMessage = 'Erreur inattendue: ${response.statusCode} - ${response.body}';
          debugPrint('Erreur lors du décodage de la réponse d\'erreur: $e');
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('=== ERREUR LORS DE LA SAUVEGARDE ===');
      debugPrint('Type d\'erreur: ${e.runtimeType}');
      debugPrint('Message: $e');
      
      if (e is Error) {
        debugPrint('Stack trace: ${e.stackTrace}');
      }
      
      if (mounted) {
        // Afficher un message d'erreur détaillé
        String errorMessage = 'Une erreur est survenue';
        
        if (e is FormatException) {
          errorMessage = 'Format de données incorrect';
        } else if (e is http.ClientException) {
          errorMessage = 'Erreur de connexion au serveur';
        } else if (e is Exception) {
          errorMessage = e.toString();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyNameController.dispose();
    _jobTitleController.dispose();
    _descriptionController.dispose();
    _experienceYearsController.dispose();
    _hourlyRateController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _radiusKmController.dispose();
    _isAvailableNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le profil professionnel'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Profil'),
            Tab(icon: Icon(Icons.schedule), text: 'Horaires'),
            Tab(icon: Icon(Icons.attach_file), text: 'Documents'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProfileTab(),
          BusinessHoursScreen(
            initialBusinessHours: _businessHours,
            onSave: (updatedHours) {
              setState(() {
                _businessHours = updatedHours;
              });
            },
          ),
          DocumentsScreen(
            initialDocuments: _documents,
            onSave: (updatedDocuments) {
              setState(() {
                _documents = updatedDocuments.cast<Document>();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileImageSection(),
            const SizedBox(height: 24),
            
            // Bouton de sauvegarde
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveProfile,
              icon: _isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save, size: 20),
              label: const Text('Enregistrer les modifications'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Section Horaires d'ouverture
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Horaires d\'ouverture',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Modifier'),
                  onPressed: () {
                    // Passer à l'onglet des horaires
                    _tabController.animateTo(1);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._businessHours.where((h) => h.isOpen).map((hours) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
                child: Text(
                  '${hours.day}: ${hours.openTime?.format(context) ?? '--:--'} - ${hours.closeTime?.format(context) ?? '--:--'}' ,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }).toList(),
            if (_businessHours.every((h) => !h.isOpen))
              const Padding(
                padding: EdgeInsets.only(top: 8.0, bottom: 8.0, left: 8.0),
                child: Text('Aucun horaire défini', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 14)),
              ),
            const Divider(height: 32),
            
            // Section Informations de l'entreprise
            Text(
              'Informations de l\'entreprise',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            CustomTextField(
              controller: _companyNameController,
              label: 'Nom de l\'entreprise',
              hint: 'Entrez le nom de votre entreprise',
              prefixIcon: Icons.business,
              onChanged: (value) {},
            ),
            const SizedBox(height: 16),
            
            CustomTextField(
              controller: _jobTitleController,
              label: 'Poste occupé',
              hint: 'Ex: Développeur Full Stack',
              prefixIcon: Icons.work,
              onChanged: (value) {},
            ),
            const SizedBox(height: 16),
            
            CustomTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Décrivez vos services en détail',
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              prefixIcon: Icons.description,
              onChanged: (value) {},
            ),
            const SizedBox(height: 24),
            
            // Section Expérience et tarification
            Text(
              'Expérience et tarification',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _experienceYearsController,
                    label: 'Années d\'expérience',
                    hint: '5',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.timeline,
                    onChanged: (value) {},
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    controller: _hourlyRateController,
                    label: 'Taux horaire (FCFA)',
                    hint: '5000',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.attach_money,
                    onChanged: (value) {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Section Localisation
            Text(
              'Localisation',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            CustomTextField(
              controller: _addressController,
              label: 'Adresse',
              hint: 'Votre adresse complète',
              prefixIcon: Icons.location_on,
              onChanged: (value) {},
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: CustomTextField(
                    controller: _cityController,
                    label: 'Ville',
                    hint: 'Votre ville',
                    prefixIcon: Icons.location_city,
                    onChanged: (value) {},
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    controller: _postalCodeController,
                    label: 'Code postal',
                    hint: '0000',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.markunread_mailbox,
                    onChanged: (value) {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            CustomTextField(
              controller: _radiusKmController,
              label: 'Rayon d\'intervention (km)',
              hint: '10',
              keyboardType: TextInputType.number,
              prefixIcon: Icons.explore,
              onChanged: (value) {},
            ),
            const SizedBox(height: 24),
            
            // Section Horaires d'ouverture
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Horaires d\'ouverture',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Modifier'),
                  onPressed: () async {
                    final result = await Navigator.push<List<BusinessHours>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BusinessHoursScreen(
                          initialBusinessHours: _businessHours,
                          onSave: (hours) {
                            setState(() {
                              _businessHours = hours;
                            });
                          },
                        ),
                      ),
                    );
                    
                    if (result != null) {
                      setState(() {
                        _businessHours = result;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._businessHours.where((h) => h.isOpen && h.openTime != null && h.closeTime != null).map((hours) {
              final openTime = hours.openTime!;
              final closeTime = hours.closeTime!;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  '${hours.day}: ${openTime.hour.toString().padLeft(2, '0')}:${openTime.minute.toString().padLeft(2, '0')} - ${closeTime.hour.toString().padLeft(2, '0')}:${closeTime.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }).toList(),
            if (_businessHours.isEmpty || _businessHours.every((h) => !h.isOpen))
              const Padding(
                padding: EdgeInsets.only(top: 8.0, bottom: 16.0),
                child: Text('Aucun horaire défini', style: TextStyle(fontStyle: FontStyle.italic)),
              ),
            
            // Bouton pour éditer les horaires
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Modifier les horaires'),
                onPressed: () {
                  // Passer à l'onglet des horaires
                  _tabController.animateTo(1);
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Section Disponibilité
            Row(
              children: [
                const Icon(Icons.event_available, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Disponible pour de nouvelles missions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                ValueListenableBuilder<bool>(
                  valueListenable: _isAvailableNotifier,
                  builder: (context, isAvailable, _) {
                    return Switch(
                      value: isAvailable,
                      onChanged: (value) => _isAvailableNotifier.value = value,
                    );
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Enregistrer les modifications',
                style: TextStyle(fontSize: 16),
              ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF1E3A5F),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: _profileImage != null
                  ? Image.file(
                      _profileImage!,
                      fit: BoxFit.cover,
                      width: 120,
                      height: 120,
                    )
                  : widget.initialData?['profile_image'] != null
                      ? Image.memory(
                          base64Decode(widget.initialData!['profile_image']),
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                        )
                      : const Icon(
                          Icons.person,
                          size: 50,
                          color: Color(0xFF1E3A5F),
                        ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A5F),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _pickImage,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Note: Assurez-vous que les widgets CustomTextField et ImageService sont correctement implémentés
// dans votre projet ou remplacez-les par des widgets équivalents.
