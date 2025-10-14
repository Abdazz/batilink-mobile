import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class CompleteProfileForm extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onSubmit;
  final bool isLoading;

  const CompleteProfileForm({
    Key? key,
    this.initialData,
    required this.onSubmit,
    this.isLoading = false,
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
  bool _isUploading = false;
  List<Map<String, dynamic>> _skills = [];
  final TextEditingController _skillNameCtrl = TextEditingController();
  String? _selectedLevel;
  bool _isLoadingSkills = false;

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
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

  Future<Map<String, String>> _uploadDocument() async {
    if (_idDocumentPath == null) return {};

    try {
      setState(() => _isUploading = true);
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:8000/api/upload'), // Remplacez par votre endpoint d'upload
      );
      
      request.files.add(await http.MultipartFile.fromPath(
        'document',
        _idDocumentPath!,
        filename: _idDocumentName,
      ));
      
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        return {'id_document_path': jsonDecode(responseData)['path']};
      } else {
        throw Exception('Échec de l\'upload du document');
      }
    } catch (e) {
      print('Erreur lors de l\'upload: $e');
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
  
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
        'level': _skillLevelsMap[_selectedLevel!] ?? 'beginner', // Utiliser la valeur mappée pour l'API
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
    // Convertir le Map en chaîne JSON
    return jsonEncode(_businessHours);
  }

  // Désactivez cette constante pour utiliser l'upload de document personnalisé
  static const bool USE_DEFAULT_DOCUMENT = true;
  static const String DEFAULT_DOCUMENT_PATH = 'chemin/vers/document_par_defaut.pdf';

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      setState(() => _isUploading = true);
      
      Map<String, String> uploadedFiles = {};
      
      // Utilisation d'un document par défaut si activé
      if (USE_DEFAULT_DOCUMENT) {
        // Utilisation du document par défaut (pour les tests)
        uploadedFiles = {'id_document_path': DEFAULT_DOCUMENT_PATH};
        print('Utilisation du document par défaut: $DEFAULT_DOCUMENT_PATH');
      } 
      // Sinon, upload du document personnalisé s'il est sélectionné
      else if (_idDocumentPath != null) {
        uploadedFiles = await _uploadDocument();
      }

      final Map<String, dynamic> formData = {
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
        'profile_completed': true, // Marquer le profil comme complet lors de la soumission
        ...uploadedFiles, // Ajoute le chemin du document
      };

      print('Données du formulaire: $formData');
      widget.onSubmit(formData);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'envoi du formulaire: $e')),
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
                    const SizedBox(height: 16),
                    if (!USE_DEFAULT_DOCUMENT) ...[
                      if (_idDocumentPath != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
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
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _isUploading ? null : _pickDocument,
                          icon: const Icon(Icons.upload_file, size: 20),
                          label: const Text('Télécharger un document d\'identité'),
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Formats acceptés : PDF, DOC, DOCX, JPG, PNG (max 5MB)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
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
          title: Text(skill['skillName'] ?? ''),
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
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, hour, minute);
    final format = MaterialLocalizations.of(context);
    return format.formatTimeOfDay(this);
  }
}
