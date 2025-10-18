import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/portfolio_service.dart';
import 'dart:convert';

class PortfolioManagementScreen extends StatefulWidget {
  final String token;

  const PortfolioManagementScreen({Key? key, required this.token}) : super(key: key);

  @override
  State<PortfolioManagementScreen> createState() => _PortfolioManagementScreenState();
}

class _PortfolioManagementScreenState extends State<PortfolioManagementScreen> {
  final PortfolioService _portfolioService = PortfolioService(baseUrl: 'http://10.0.2.2:8000');
  List<Map<String, dynamic>> _portfolios = [];
  bool _isLoading = true;
  String _error = '';

  /// Transforme les données du backend vers le format attendu par le frontend
  Map<String, dynamic> _transformPortfolioData(Map<String, dynamic> backendData) {
    // Construire l'URL complète de l'image
    String? fullImageUrl;
    if (backendData['image_path'] != null && backendData['image_path'].toString().isNotEmpty) {
      // Le backend retourne des chemins relatifs comme /storage/portfolios/...
      // On construit l'URL complète en ajoutant la base URL
      fullImageUrl = 'http://10.0.2.2:8000${backendData['image_path']}';
    }

    return {
      'id': backendData['id'],
      'title': backendData['title'],
      'description': backendData['description'],
      'category': backendData['project_type'] ?? backendData['category'] ?? '', // Mapping project_type vers category
      'tags': backendData['tags'] ?? [],
      'image_url': fullImageUrl ?? backendData['image_url'] ?? '', // URL complète de l'image
      'is_featured': backendData['is_featured'] ?? false,
      'completed_at': backendData['project_date'] ?? backendData['completed_at'],
      'created_at': backendData['created_at'],
      'updated_at': backendData['updated_at'],
    };
  }

  @override
  void initState() {
    super.initState();
    _loadPortfolios();
  }

  Future<void> _loadPortfolios() async {
    print('🔄 Chargement de la liste des portfolios...');
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? widget.token;

      print('🔑 Token utilisé: ${token.isNotEmpty ? "OUI (${token.substring(0, 20)}...)" : "NON"}');

      final response = await _portfolioService.getPortfolios(accessToken: token);

      print('📡 Réponse API reçue - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📄 Corps de la réponse complète: $data');

        // Vérification de la structure de la réponse
        if (data is Map<String, dynamic>) {
          print('🔍 Clés disponibles dans la réponse: ${data.keys.toList()}');

          // Vérification spécifique du champ 'data'
          if (data.containsKey('data')) {
            final dataField = data['data'];
            print('📊 Type du champ "data": ${dataField.runtimeType}');
            print('📊 Contenu du champ "data": $dataField');

            if (dataField is List) {
              final portfolios = List<Map<String, dynamic>>.from(dataField);
              print('✅ ${portfolios.length} portfolios récupérés');

              // Vérification de la structure de chaque portfolio
              for (int i = 0; i < portfolios.length; i++) {
                final portfolio = portfolios[i];
                print('📋 Portfolio $i structure: ${portfolio.keys.toList()}');
                print('📋 Portfolio $i données: $portfolio');
              }

              // Transformer les données du backend vers le format attendu
              final transformedPortfolios = portfolios.map((portfolio) => _transformPortfolioData(portfolio)).toList();
              print('🔄 Portfolios transformés: $transformedPortfolios');

              setState(() {
                _portfolios = transformedPortfolios;
              });
            } else if (dataField == null || dataField.isEmpty) {
              print('📭 Aucun portfolio trouvé (data vide ou null)');
              setState(() {
                _portfolios = [];
              });
            } else {
              print('❌ Format inattendu pour le champ "data": $dataField');
              setState(() {
                _error = 'Format de données inattendu';
              });
            }
          } else {
            print('❌ Champ "data" manquant dans la réponse');
            setState(() {
              _error = 'Champ "data" manquant dans la réponse';
            });
          }
        } else {
          print('❌ Réponse API n\'est pas un objet JSON');
          setState(() {
            _error = 'Réponse API invalide';
          });
        }
      } else {
        print('❌ Échec API - Status: ${response.statusCode}');
        print('📄 Corps de l\'erreur: ${response.body}');
        setState(() {
          _error = 'Erreur serveur: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('💥 Exception lors du chargement: $e');
      if (e.toString().contains('Software caused connection abort')) {
        print('🔄 Tentative de reconnexion dans 3 secondes...');
        setState(() {
          _error = 'Problème de connexion serveur. Tentative automatique dans 3 secondes...';
        });

        // Attendre 3 secondes puis réessayer automatiquement (une seule fois)
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          _loadPortfolios();
        }
      } else {
        setState(() {
          _error = 'Erreur de connexion: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('🔄 Fin du chargement des portfolios');
    }
  }

  Future<void> _showAddPortfolioDialog() async {
    print('📋 Ouverture du dialog d\'ajout de portfolio');
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddPortfolioDialog(
        portfolioService: _portfolioService,
        token: widget.token,
      ),
    );

    print('📋 Résultat du dialog: $result');
    if (result != null) {
      print('✅ Dialog fermé avec succès - attente 2 secondes avant rechargement');

      // Attendre 2 secondes pour laisser le serveur traiter complètement le portfolio
      await Future.delayed(const Duration(seconds: 2));

      print('🔄 Rechargement de la liste après délai');
      _loadPortfolios(); // Recharger la liste
    } else {
      print('❌ Dialog fermé sans succès');
    }
  }

  Future<void> _showEditPortfolioDialog(Map<String, dynamic> portfolio) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddPortfolioDialog(
        portfolioService: _portfolioService,
        portfolio: portfolio,
        token: widget.token,
      ),
    );

    if (result != null) {
      _loadPortfolios(); // Recharger la liste
    }
  }

  Future<void> _deletePortfolio(Map<String, dynamic> portfolio) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Supprimer le portfolio',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${portfolio['title']}" ?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Annuler',
              style: GoogleFonts.poppins(),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Supprimer',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token') ?? widget.token;

        final response = await _portfolioService.deletePortfolio(
          accessToken: token,
          portfolioId: portfolio['id'].toString(),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Portfolio supprimé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          _loadPortfolios();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors de la suppression'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          'Gestion du Portfolio',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF4CAF50)),
            onPressed: _showAddPortfolioDialog,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPortfolioDialog,
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error,
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPortfolios,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Réessayer',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (_portfolios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun portfolio créé',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Commencez par ajouter vos réalisations',
              style: GoogleFonts.poppins(
                color: Colors.grey[500],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddPortfolioDialog,
              icon: const Icon(Icons.add),
              label: const Text('Créer votre premier portfolio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPortfolios,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _portfolios.length,
        itemBuilder: (context, index) {
          final portfolio = _portfolios[index];
          return _buildPortfolioCard(portfolio);
        },
      ),
    );
  }

  Widget _buildPortfolioCard(Map<String, dynamic> portfolio) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image du portfolio
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              color: Colors.grey[300],
            ),
            child: portfolio['image_url'] != null
                ? ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Image.network(
                      portfolio['image_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image, size: 64, color: Colors.grey);
                      },
                    ),
                  )
                : const Icon(Icons.image, size: 64, color: Colors.grey),
          ),
          // Contenu du portfolio
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        portfolio['title'] ?? 'Sans titre',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        switch (value) {
                          case 'edit':
                            await _showEditPortfolioDialog(portfolio);
                            break;
                          case 'delete':
                            await _deletePortfolio(portfolio);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 16),
                              SizedBox(width: 8),
                              Text('Modifier'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 16),
                              SizedBox(width: 8),
                              Text('Supprimer', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  portfolio['description'] ?? 'Aucune description',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Créé le ${_formatDate(portfolio['created_at'])}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Date inconnue';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Date invalide';
    }
  }
}

class AddPortfolioDialog extends StatefulWidget {
  final PortfolioService portfolioService;
  final Map<String, dynamic>? portfolio;
  final String token;

  const AddPortfolioDialog({
    Key? key,
    required this.portfolioService,
    this.portfolio,
    required this.token,
  }) : super(key: key);

  @override
  State<AddPortfolioDialog> createState() => _AddPortfolioDialogState();
}

class _AddPortfolioDialogState extends State<AddPortfolioDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _completedAtController = TextEditingController();
  
  String? _selectedImagePath;
  String? _selectedImageName;
  bool _isSubmitting = false;
  bool _isFeatured = false;

  bool get isEditing => widget.portfolio != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _titleController.text = widget.portfolio!['title'] ?? '';
      _descriptionController.text = widget.portfolio!['description'] ?? '';
      _categoryController.text = widget.portfolio!['category'] ?? '';
      _isFeatured = widget.portfolio!['is_featured'] ?? false;
      _tagsController.text = (widget.portfolio!['tags'] as List<dynamic>?)?.join(', ') ?? '';
      _completedAtController.text = widget.portfolio!['completed_at'] ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _completedAtController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await widget.portfolioService.pickImage();
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedImagePath = result.files.first.path;
        _selectedImageName = result.files.first.name;
      });
    }
  }

  Future<void> _submit() async {
    print('=== DEBUG - DÉBUT SOUMISSION PORTFOLIO ===');

    if (!_formKey.currentState!.validate()) {
      print('❌ Échec validation formulaire');
      return;
    }

    print('✅ Formulaire validé avec succès');

    // Validation des données avec debug détaillé
    final errors = widget.portfolioService.validatePortfolioData(
      title: _titleController.text,
      description: _descriptionController.text,
      category: _categoryController.text,
      filePath: _selectedImagePath,
    );

    if (errors.isNotEmpty) {
      print('❌ Erreurs de validation trouvées:');
      errors.forEach((key, value) {
        print('   - $key: $value');
      });

      final firstError = errors.values.first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de validation: $firstError'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    print('✅ Validation des données réussie');
    print('📝 Données du formulaire:');
    print('   - Titre: "${_titleController.text}"');
    print('   - Description: "${_descriptionController.text}"');
    print('   - Catégorie: "${_categoryController.text}"');
    print('   - Image sélectionnée: ${_selectedImagePath != null ? "OUI" : "NON"}');

    if (_tagsController.text.trim().isNotEmpty) {
      print('   - Tags: "${_tagsController.text}"');
    }
    if (_completedAtController.text.trim().isNotEmpty) {
      print('   - Date de completion: "${_completedAtController.text}"');
    }
    print('   - Mis en avant: $_isFeatured');

    setState(() {
      _isSubmitting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? widget.token;

      print('🔑 Token récupéré: ${token.isNotEmpty ? "OUI (${token.substring(0, 20)}...)" : "NON"}');

      if (token.isEmpty) {
        throw Exception('Token d\'authentification manquant. Veuillez vous reconnecter.');
      }

      // Préparer les tags
      List<String> tags = [];
      if (_tagsController.text.trim().isNotEmpty) {
        tags = _tagsController.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();
        print('🏷️ Tags préparés: $tags');
      }

      print('🚀 Envoi de la requête API...');

      final response = isEditing
          ? await widget.portfolioService.updatePortfolio(
              accessToken: token,
              portfolioId: widget.portfolio!['id'].toString(),
              title: _titleController.text,
              description: _descriptionController.text,
              category: _categoryController.text,
              tags: tags,
              isFeatured: _isFeatured,
              completedAt: _completedAtController.text.trim().isNotEmpty ? _completedAtController.text.trim() : null,
              filePath: _selectedImagePath,
            )
          : await widget.portfolioService.createPortfolio(
              accessToken: token,
              title: _titleController.text,
              description: _descriptionController.text,
              category: _categoryController.text,
              tags: tags,
              isFeatured: _isFeatured,
              completedAt: _completedAtController.text.trim().isNotEmpty ? _completedAtController.text.trim() : null,
              filePath: _selectedImagePath!,
            );

      print('📡 Réponse API reçue - Status: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ Portfolio ${isEditing ? "mis à jour" : "créé"} avec succès');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Portfolio ${isEditing ? "mis à jour" : "créé"} avec succès !'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop({'success': true});
      } else {
        final responseBody = await response.stream.bytesToString();
        print('❌ Échec API - Status: ${response.statusCode}');
        print('📄 Corps de la réponse: $responseBody');

        final errorData = json.decode(responseBody);
        final errorMessage = errorData['message'] ?? 'Erreur serveur inconnue';

        print('🚨 Message d\'erreur API: $errorMessage');

        throw Exception(errorMessage);
      }
    } catch (e) {
      print('💥 Exception attrapée: $e');
      print('📍 Stack trace: ${StackTrace.current}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
      print('=== DEBUG - FIN SOUMISSION PORTFOLIO ===\n');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Modifier le portfolio' : 'Nouveau portfolio',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
              
              // Titre
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Titre',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le titre est requis';
                  }
                  if (value.trim().length < 3) {
                    return 'Le titre doit contenir au moins 3 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Catégorie
              DropdownButtonFormField<String>(
                value: _categoryController.text.isNotEmpty ? _categoryController.text : null,
                decoration: InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  'plomberie',
                  'électricité',
                  'peinture',
                  'menuiserie',
                  'jardinage',
                  'nettoyage',
                  'réparation',
                  'installation',
                  'maintenance',
                  'autre'
                ].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _categoryController.text = value ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'La catégorie est requise';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'La description est requise';
                  }
                  if (value.trim().length < 10) {
                    return 'La description doit contenir au moins 10 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Tags (optionnel)
              TextFormField(
                controller: _tagsController,
                decoration: InputDecoration(
                  labelText: 'Tags (optionnel)',
                  hintText: 'Ex: moderne, écologique, rapide',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  helperText: 'Séparez les tags par des virgules',
                ),
              ),
              const SizedBox(height: 16),
              
              // Options avancées
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Options avancées',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Switch pour "Mis en avant"
                      SwitchListTile(
                        title: Text(
                          'Portfolio mis en avant',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        subtitle: Text(
                          'Afficher ce portfolio en priorité',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                        ),
                        value: _isFeatured,
                        onChanged: (bool value) {
                          setState(() {
                            _isFeatured = value;
                          });
                        },
                        activeColor: const Color(0xFF4CAF50),
                      ),
                      const SizedBox(height: 16),
                      
                      // Date de completion (optionnel)
                      TextFormField(
                        controller: _completedAtController,
                        decoration: InputDecoration(
                          labelText: 'Date de completion (optionnel)',
                          hintText: 'AAAA-MM-JJ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: Icon(Icons.calendar_today, color: Colors.grey),
                        ),
                        keyboardType: TextInputType.datetime,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            // Validation du format YYYY-MM-DD
                            final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                            if (!dateRegex.hasMatch(value)) {
                              return 'Format de date invalide (AAAA-MM-JJ)';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(12),
                  child: _selectedImagePath != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image, size: 32, color: Colors.green),
                            const SizedBox(height: 8),
                            Text(
                              _selectedImageName!,
                              style: GoogleFonts.poppins(fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Sélectionner une image',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Boutons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Annuler',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              isEditing ? 'Modifier' : 'Créer',
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
