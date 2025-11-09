import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/pro_client_portfolio.dart';
import '../../services/pro_client_portfolio_service.dart';
import '../../core/app_config.dart';

class ProClientPortfolioDialog extends StatefulWidget {
  final ProClientPortfolio? portfolio;
  final String token;

  const ProClientPortfolioDialog({
    Key? key,
    this.portfolio,
    required this.token,
  }) : super(key: key);

  @override
  _ProClientPortfolioDialogState createState() => _ProClientPortfolioDialogState();
}

class _ProClientPortfolioDialogState extends State<ProClientPortfolioDialog> {
  final _portfolioService = ProClientPortfolioService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _projectDateController = TextEditingController();
  final _projectUrlController = TextEditingController();
  final _categoryController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetController = TextEditingController();
  final _tagsController = TextEditingController();
  final List<String> _selectedSkills = [];
  File? _projectImage;
  bool _isLoading = false;
  bool _isFeatured = false;
  bool _isVisible = true;
  String? _projectType;

  @override
  void initState() {
    super.initState();
    if (widget.portfolio != null) {
      _titleController.text = widget.portfolio!.title;
      _descriptionController.text = widget.portfolio!.description;
      _projectUrlController.text = widget.portfolio!.projectUrl ?? '';
      _isFeatured = widget.portfolio!.isFeatured;
      _selectedSkills.addAll(widget.portfolio!.skills);
      // model currently doesn't expose project_type/category/location/budget/tags
      // If API model is extended later, populate here
      if (widget.portfolio!.projectDate != null) {
        _projectDateController.text = 
          '${widget.portfolio!.projectDate!.year}-'
          '${widget.portfolio!.projectDate!.month.toString().padLeft(2, '0')}-'
          '${widget.portfolio!.projectDate!.day.toString().padLeft(2, '0')}';
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _projectDateController.dispose();
  // project type uses _projectType variable
    _projectUrlController.dispose();
    _categoryController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    _tagsController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.portfolio != null ? 'Modifier le projet' : 'Ajouter un projet',
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
                      : widget.portfolio?.imagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Builder(
                                builder: (context) {
                                  final raw = widget.portfolio!.imagePath!;
                                  // If API returns a relative path, build a full URL
                                  final displayUrl = raw.startsWith('http')
                                      ? raw
                                      : '${AppConfig.baseUrl}/storage/$raw';
                                  return Image.network(
                                    displayUrl,
                                    fit: BoxFit.cover,
                                    headers: const {
                                      'Accept': 'image/*',
                                    },
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      debugPrint('Failed to load portfolio image: $error');
                                      debugPrint('Tried URL: $displayUrl');
                                      return const Icon(Icons.broken_image, size: 50);
                                    },
                                  );
                                },
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
              // Project type (required)
              DropdownButtonFormField<String>(
                value: _projectType,
                decoration: const InputDecoration(
                  labelText: 'Type de projet',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'web', child: Text('Web')),
                  DropdownMenuItem(value: 'mobile', child: Text('Mobile')),
                  DropdownMenuItem(value: 'design', child: Text('Design')),
                  DropdownMenuItem(value: 'marketing', child: Text('Marketing')),
                  DropdownMenuItem(value: 'other', child: Text('Autre')),
                ],
                onChanged: (v) => setState(() => _projectType = v),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Veuillez sélectionner un type de projet';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Category
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Catégorie (optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Project URL
              TextFormField(
                controller: _projectUrlController,
                decoration: const InputDecoration(
                  labelText: 'URL du projet (optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Location
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Localisation (optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Budget
              TextFormField(
                controller: _budgetController,
                decoration: const InputDecoration(
                  labelText: 'Budget (optionnel)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              // Tags (comma separated)
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (séparés par des virgules)',
                  border: OutlineInputBorder(),
                ),
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
                  const SizedBox(width: 12),
                  Checkbox(
                    value: _isVisible,
                    onChanged: (v) {
                      setState(() {
                        _isVisible = v ?? true;
                      });
                    },
                  ),
                  Text(
                    'Visible',
                    style: GoogleFonts.poppins(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Annuler',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () async {
                        if (_formKey.currentState!.validate()) {
                          if (_projectImage == null && widget.portfolio == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Veuillez sélectionner une image'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setState(() {
                            _isLoading = true;
                          });

                          try {
                            final tags = _tagsController.text.trim().isNotEmpty
                                ? _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
                                : null;

                            final int? budget = _budgetController.text.trim().isNotEmpty
                                ? int.tryParse(_budgetController.text.trim())
                                : null;

                            if (widget.portfolio == null) {
                              // Création d'un nouveau portfolio
                              await _portfolioService.createPortfolio(
                                token: widget.token,
                                title: _titleController.text,
                                description: _descriptionController.text,
                                projectType: _projectType ?? 'other',
                                imageFile: _projectImage!,
                                category: _categoryController.text.isNotEmpty ? _categoryController.text : null,
                                projectUrl: _projectUrlController.text.isNotEmpty ? _projectUrlController.text : null,
                                projectDate: _projectDateController.text.isNotEmpty ? _projectDateController.text : null,
                                location: _locationController.text.isNotEmpty ? _locationController.text : null,
                                projectBudget: budget,
                                isFeatured: _isFeatured,
                                isVisible: _isVisible,
                                tags: tags,
                              );
                            } else {
                              // Mise à jour d'un portfolio existant
                              await _portfolioService.updatePortfolio(
                                token: widget.token,
                                portfolioId: widget.portfolio!.id,
                                title: _titleController.text,
                                description: _descriptionController.text,
                                projectType: _projectType ?? 'other',
                                imageFile: _projectImage,
                                category: _categoryController.text.isNotEmpty ? _categoryController.text : null,
                                projectUrl: _projectUrlController.text.isNotEmpty ? _projectUrlController.text : null,
                                projectDate: _projectDateController.text.isNotEmpty ? _projectDateController.text : null,
                                location: _locationController.text.isNotEmpty ? _locationController.text : null,
                                projectBudget: budget,
                                isFeatured: _isFeatured,
                                isVisible: _isVisible,
                                tags: tags,
                              );
                            }

                            if (mounted) {
                              Navigator.of(context).pop(true);
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Erreur: ${e.toString()}',
                                  ),
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
                      },
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
                              widget.portfolio != null ? 'Mettre à jour' : 'Ajouter',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}