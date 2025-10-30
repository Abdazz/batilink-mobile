import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/app_config.dart';
import '../../services/image_service.dart';
import '../../widgets/custom_dialog.dart';

class PortfolioManagementScreen extends StatefulWidget {
  final List<dynamic> portfolios;
  final String token;
  final Function(List<dynamic>)? onUpdate;

  const PortfolioManagementScreen({
    Key? key,
    required this.portfolios,
    required this.token,
    this.onUpdate,
  }) : super(key: key);

  @override
  _PortfolioManagementScreenState createState() => _PortfolioManagementScreenState();
}

class _PortfolioManagementScreenState extends State<PortfolioManagementScreen> {
  late List<dynamic> _portfolios;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _projectTypeController = TextEditingController();
  final _projectDateController = TextEditingController();
  File? _projectImage;
  bool _isLoading = false;
  bool _isFeatured = false;
  String? _editingId;

  @override
  void initState() {
    super.initState();
    _portfolios = List.from(widget.portfolios);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _projectTypeController.dispose();
    _projectDateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _projectImage = File(pickedFile.path);
      });
    }
  }

  void _editPortfolio(Map<String, dynamic> portfolio) {
    setState(() {
      _editingId = portfolio['id'];
      _titleController.text = portfolio['title'] ?? '';
      _descriptionController.text = portfolio['description'] ?? '';
      _projectTypeController.text = portfolio['project_type'] ?? '';
      _projectDateController.text = portfolio['project_date'] ?? '';
      _isFeatured = portfolio['is_featured'] ?? false;
      _projectImage = null;
    });
    _showPortfolioForm();
  }

  void _showPortfolioForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _editingId != null ? 'Modifier le projet' : 'Ajouter un projet',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.grey[400]!,
                      width: 1,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _projectImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _projectImage!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : _editingId != null &&
                              _portfolios
                                      .firstWhere(
                                        (p) => p['id'] == _editingId,
                                        orElse: () => {'image_path': null},
                                      )['image_path'] !=
                                  null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                '${AppConfig.baseUrl}${_portfolios.firstWhere((p) => p['id'] == _editingId)['image_path']}',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.broken_image, size: 50),
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_photo_alternate,
                                    size: 40, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(
                                  'Ajouter une image',
                                  style: GoogleFonts.poppins(color: Colors.grey),
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre du projet',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un titre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer une description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _projectTypeController,
                decoration: const InputDecoration(
                  labelText: 'Type de projet',
                  border: OutlineInputBorder(),
                  hintText: 'Ex: Site web, Application mobile, etc.',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un type de projet';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _projectDateController,
                decoration: const InputDecoration(
                  labelText: 'Date du projet',
                  border: OutlineInputBorder(),
                  hintText: 'AAAA-MM-JJ',
                ),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    _projectDateController.text =
                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez sélectionner une date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isFeatured,
                    onChanged: (value) {
                      setState(() {
                        _isFeatured = value ?? false;
                      });
                    },
                  ),
                  Text(
                    'Mettre en avant',
                    style: GoogleFonts.poppins(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _savePortfolio,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF1E3A5F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _editingId != null ? 'Mettre à jour' : 'Ajouter',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      // Réinitialiser le formulaire après la fermeture
      _editingId = null;
      _titleController.clear();
      _descriptionController.clear();
      _projectTypeController.clear();
      _projectDateController.clear();
      _projectImage = null;
      _isFeatured = false;
    });
  }

  Future<void> _savePortfolio() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Télécharger l'image si une nouvelle a été sélectionnée
      String? imageUrl;
      if (_projectImage != null) {
        imageUrl = await ImageService.uploadImage(
          _projectImage!,
          'portfolio',
          widget.token,
        );
      } else if (_editingId != null) {
        // Si on est en mode édition et qu'aucune nouvelle image n'a été sélectionnée,
        // on garde l'URL de l'image existante
        final existingPortfolio = _portfolios.firstWhere(
          (p) => p['id'] == _editingId,
          orElse: () => {'image_path': null},
        );
        if (existingPortfolio['image_path'] != null) {
          imageUrl = existingPortfolio['image_path'];
        }
      }

      final portfolioData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'project_type': _projectTypeController.text.trim(),
        'project_date': _projectDateController.text.trim(),
        'is_featured': _isFeatured,
        if (imageUrl != null) 'image_path': imageUrl,
      };

      if (_editingId != null) {
        // Mise à jour d'un portfolio existant
        await _updatePortfolio(_editingId!, portfolioData);
      } else {
        // Création d'un nouveau portfolio
        await _createPortfolio(portfolioData);
      }

      if (mounted) {
        Navigator.pop(context); // Fermer le formulaire
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
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

  Future<void> _createPortfolio(Map<String, dynamic> portfolioData) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/pro-client/portfolios'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode(portfolioData),
    );

    if (response.statusCode == 201) {
      final newPortfolio = json.decode(response.body)['data'];
      setState(() {
        _portfolios.add(newPortfolio);
      });
      _notifyParent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Projet ajouté avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      throw Exception('Échec de la création du projet: ${response.body}');
    }
  }

  Future<void> _updatePortfolio(
      String id, Map<String, dynamic> portfolioData) async {
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/api/pro-client/portfolios/$id'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode(portfolioData),
    );

    if (response.statusCode == 200) {
      final updatedPortfolio = json.decode(response.body)['data'];
      setState(() {
        final index = _portfolios.indexWhere((p) => p['id'] == id);
        if (index != -1) {
          _portfolios[index] = {
            ..._portfolios[index],
            ...updatedPortfolio,
            'id': id, // S'assurer que l'ID reste le même
          };
        }
      });
      _notifyParent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Projet mis à jour avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      throw Exception('Échec de la mise à jour du projet: ${response.body}');
    }
  }

  void _notifyParent() {
    if (widget.onUpdate != null) {
      widget.onUpdate!(_portfolios);
    }
  }

  Future<void> _deletePortfolio(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => CustomDialog(
        title: 'Supprimer le projet',
        content:
            'Êtes-vous sûr de vouloir supprimer ce projet ? Cette action est irréversible.',
        confirmText: 'Supprimer',
        cancelText: 'Annuler',
        confirmColor: Colors.red,
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/api/pro-client/portfolios/$id'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _portfolios.removeWhere((p) => p['id'] == id);
        });
        _notifyParent();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Projet supprimé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Échec de la suppression du projet: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gérer mon portfolio',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(_portfolios),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _portfolios.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun projet dans votre portfolio',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _showPortfolioForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          'Ajouter un projet',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _portfolios.length,
                        itemBuilder: (context, index) {
                          final portfolio = _portfolios[index];
                          final imageUrl = portfolio['image_path'] != null
                              ? '${AppConfig.baseUrl}${portfolio['image_path']}'
                              : null;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Image du projet
                                Container(
                                  height: 180,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                    color: Colors.grey[200],
                                  ),
                                  child: imageUrl != null
                                      ? ClipRRect(
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(12),
                                          ),
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(Icons.broken_image,
                                                        size: 50),
                                          ),
                                        )
                                      : const Center(
                                          child: Icon(Icons.photo_library,
                                              size: 50, color: Colors.grey),
                                        ),
                                ),
                                // Détails du projet
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              portfolio['title'] ?? 'Sans titre',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (portfolio['is_featured'] == true)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.amber[100],
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.star,
                                                      size: 14, color: Colors.amber),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'À la une',
                                                    style:
                                                        GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: Colors.amber[800],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (portfolio['project_type'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E3A5F)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            portfolio['project_type']
                                                .toString()
                                                .toUpperCase(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF1E3A5F),
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      if (portfolio['description'] != null)
                                        Text(
                                          portfolio['description'],
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: Colors.grey[700],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            portfolio['project_date'] ?? '',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Actions
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(12),
                                    ),
                                    border: Border(
                                      top: BorderSide(
                                        color: Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _editPortfolio(portfolio),
                                        icon: const Icon(Icons.edit,
                                            size: 18, color: Color(0xFF1E3A5F)),
                                        label: Text(
                                          'Modifier',
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFF1E3A5F),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: () => _deletePortfolio(portfolio['id']),
                                        icon: const Icon(Icons.delete,
                                            size: 18, color: Colors.red),
                                        label: Text(
                                          'Supprimer',
                                          style: GoogleFonts.poppins(
                                            color: Colors.red,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Bouton d'ajout en bas de l'écran
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _showPortfolioForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.add, size: 20),
                        label: Text(
                          'Ajouter un projet',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
