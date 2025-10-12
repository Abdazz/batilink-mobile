import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/portfolio_service.dart';
import '../../models/portfolio_item.dart';

// Créer une instance d'ImagePicker en dehors de la classe
final ImagePicker _imagePicker = ImagePicker();

class ProfessionalSettingsScreen extends StatefulWidget {
  final String token;
  
  const ProfessionalSettingsScreen({Key? key, required this.token}) : super(key: key);

  @override
  _ProfessionalSettingsScreenState createState() => _ProfessionalSettingsScreenState();
}

class _ProfessionalSettingsScreenState extends State<ProfessionalSettingsScreen> {
  late Future<Map<String, dynamic>> _profileFuture = Future.value({});
  final AuthService _authService = AuthService(baseUrl: 'http://10.0.2.2:8000');
  final PortfolioService _portfolioService = PortfolioService(baseUrl: 'http://10.0.2.2:8000');
  // État pour la gestion du portfolio
  List<PortfolioItem> _portfolios = [];
  bool _isLoadingPortfolios = false;
  String _portfolioError = '';
  File? _selectedImage;
  
  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPortfolios();
  }
  
  // Charger les portfolios
  Future<void> _loadPortfolios() async {
    if (mounted) {
      setState(() {
        _isLoadingPortfolios = true;
        _portfolioError = '';
      });
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? widget.token;
      
      final portfolios = await _portfolioService.getPortfolios(token);
      
      if (mounted) {
        setState(() {
          _portfolios = portfolios;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _portfolioError = 'Erreur lors du chargement des portfolios: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPortfolios = false;
        });
      }
    }
  }
  
  // Ajouter un nouveau portfolio
  Future<void> _addPortfolio() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final categoryController = TextEditingController();
    final tagsController = TextEditingController();
    File? imageFile;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un projet au portfolio'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bouton d'ajout d'image
              GestureDetector(
                onTap: () async {
                  final XFile? pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    imageFile = File(pickedFile.path);
                    // Mettre à jour l'aperçu de l'image si nécessaire
                    setState(() {
                      _selectedImage = imageFile;
                    });
                  }
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _selectedImage != null
                      ? Image.file(_selectedImage!, fit: BoxFit.cover)
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                            Text('Ajouter une image', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre du projet',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (séparés par des virgules)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && 
                  descriptionController.text.isNotEmpty &&
                  categoryController.text.isNotEmpty &&
                  imageFile != null) {
                Navigator.of(context).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez remplir tous les champs et ajouter une image')),
                );
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token') ?? widget.token;
        
        await _portfolioService.createPortfolio(
          token: token,
          title: titleController.text,
          description: descriptionController.text,
          category: categoryController.text,
          tags: tagsController.text.split(',').map((e) => e.trim()).toList(),
          imagePath: imageFile!.path,
        );
        
        // Recharger la liste des portfolios
        await _loadPortfolios();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Portfolio ajouté avec succès')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de l\'ajout du portfolio: $e')),
          );
        }
      }
    }
  }
  
  // Supprimer un portfolio
  Future<void> _deletePortfolio(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce projet du portfolio ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token') ?? widget.token;
        
        await _portfolioService.deletePortfolio(token, id);
        
        // Recharger la liste des portfolios
        await _loadPortfolios();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Portfolio supprimé avec succès')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la suppression: $e')),
          );
        }
      }
    }
  }
  
  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? widget.token;
      
      final response = await _authService.getProfessionalProfile(accessToken: token);
      
      if (mounted) {
        setState(() {
          if (response.statusCode == 200) {
            final responseData = jsonDecode(response.body);
            print('Réponse complète du profil: $responseData'); // Debug
            
            Map<String, dynamic> profileData = {};
            
            if (responseData is Map && responseData['success'] == true) {
              final responseDataData = responseData['data'];
              
              // Vérifier si nous avons un tableau de profils
              if (responseDataData is Map && 
                  responseDataData['data'] is List && 
                  (responseDataData['data'] as List).isNotEmpty) {
                // Prendre le premier profil de la liste
                profileData = Map<String, dynamic>.from(responseDataData['data'][0]);
              } else if (responseDataData is Map) {
                // Si la structure est différente, essayer d'extraire directement
                profileData = Map<String, dynamic>.from(responseDataData);
              }
            }
            
            print('Données du profil extraites: $profileData'); // Debug
            _profileFuture = Future<Map<String, dynamic>>.value(profileData);
          } else {
            final error = 'Erreur ${response.statusCode}: ${response.body}';
            print(error); // Debug
            _profileFuture = Future.error(error);
          }
        });
      }
    } catch (e, stackTrace) {
      print('Erreur lors du chargement du profil: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _profileFuture = Future.error(e.toString());
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement du profil: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Erreur lors du chargement du profil'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadProfile,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        final profile = snapshot.data ?? {};
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Mon Profil'),
            centerTitle: true,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadProfile,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête avec photo et nom
                _buildProfileHeader(profile),
                const SizedBox(height: 24),
                
                // Section Informations professionnelles
                _buildSectionHeader('Informations professionnelles'),
                _buildInfoItem(Icons.business_outlined, 'Entreprise', profile['company_name'] ?? 'Non renseigné'),
                _buildInfoItem(Icons.work_outline, 'Métier', profile['job_title'] ?? 'Non renseigné'),
                _buildInfoItem(Icons.description_outlined, 'Description', profile['description'] ?? 'Non renseignée'),
                _buildInfoItem(Icons.work_history, 'Expérience', '${profile['experience_years']?.toString() ?? '0'} ans'),
                _buildInfoItem(Icons.star_border, 'Note', '${profile['rating'] ?? '0'}/5 (${profile['completed_jobs'] ?? '0'} missions)'),
                
                const SizedBox(height: 24),
                
                // Section Adresse
                _buildSectionHeader('Localisation'),
                _buildInfoItem(Icons.location_on_outlined, 'Adresse', profile['address'] ?? 'Non renseignée'),
                _buildInfoItem(Icons.location_city_outlined, 'Ville', profile['city'] ?? 'Non renseignée'),
                _buildInfoItem(Icons.markunread_mailbox_outlined, 'Code postal', profile['postal_code'] ?? 'Non renseigné'),
                _buildInfoItem(Icons.radar, 'Rayon d\'intervention', '${profile['radius_km'] ?? '0'} km'),
                
                const SizedBox(height: 24),
                
                // Section Tarification
                _buildSectionHeader('Tarification'),
                _buildInfoItem(Icons.attach_money_outlined, 'Taux horaire', '${profile['hourly_rate'] ?? '0'} FCFA'),
                _buildInfoItem(Icons.attach_money_outlined, 'Prix minimum', '${profile['min_price'] ?? '0'} FCFA'),
                _buildInfoItem(Icons.attach_money_outlined, 'Prix maximum', '${profile['max_price'] ?? '0'} FCFA'),
                
                const SizedBox(height: 24),
                
                // Section Compétences
                _buildSectionHeader('Compétences'),
                if (profile['skills'] != null && (profile['skills'] as List).isNotEmpty)
                  ...(profile['skills'] as List).map<Widget>((skill) => 
                    _buildInfoItem(
                      Icons.check_circle_outline, 
                      skill['name'] ?? 'Compétence', 
                      'Niveau: ${skill['level'] ?? 'Non spécifié'} (${skill['experience_years'] ?? '0'} ans d\'expérience)'
                    )
                  ).toList()
                else
                  _buildInfoItem(Icons.info_outline, 'Aucune compétence ajoutée', 'Ajoutez vos compétences'),
                
                const SizedBox(height: 24),
                
                // Section Portfolio
                _buildSectionHeader('Portfolio'),
                if (_isLoadingPortfolios)
                  const Center(child: CircularProgressIndicator())
                else if (_portfolioError.isNotEmpty)
                  _buildErrorPortfolioSection()
                else if (_portfolios.isEmpty)
                  _buildEmptyPortfolioSection()
                else
                  ..._portfolios.map((portfolio) => _buildPortfolioItem(portfolio)).toList(),
                  
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _addPortfolio,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Ajouter un projet'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Section Paramètres du compte
                _buildSectionHeader('Paramètres du compte'),
                _buildSettingItem(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  onTap: () {}
                ),
                _buildSettingItem(
                  icon: Icons.lock_outline,
                  title: 'Sécurité',
                  onTap: () {}
                ),
                _buildSettingItem(
                  icon: Icons.help_outline,
                  title: 'Aide & Support',
                  onTap: () {}
                ),
                _buildSettingItem(
                  icon: Icons.logout,
                  title: 'Déconnexion',
                  isLogout: true,
                  onTap: () => _handleLogout(context),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> profile) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: profile['profile_photo_url'] != null 
                ? NetworkImage(profile['profile_photo_url']) as ImageProvider
                : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
          ),
          const SizedBox(height: 16),
          Text(
            '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (profile['profession'] != null) ...[
            const SizedBox(height: 4),
            Text(
              profile['profession'],
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Naviguer vers l'édition du profil
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Modifier le profil'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Text(
          value.isNotEmpty ? value : 'Non renseigné',
          style: TextStyle(color: value.isNotEmpty ? null : Colors.grey[600]),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        onTap: () {
          // TODO: Gérer l'action de modification
        },
      ),
    );
  }

  // Widget pour afficher un élément de portfolio
  Widget _buildPortfolioItem(PortfolioItem portfolio) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image du portfolio
          if (portfolio.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              child: Image.network(
                portfolio.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              ),
            ),
          
          // Contenu du portfolio
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        portfolio.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Badge pour les projets mis en avant
                    if (portfolio.isFeatured)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Mis en avant',
                          style: TextStyle(fontSize: 10, color: Colors.orange[800]),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Description
                if (portfolio.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      portfolio.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                
                // Catégorie et date
                Row(
                  children: [
                    Icon(Icons.category_outlined, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      portfolio.category,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    if (portfolio.completedAt != null)
                      Text(
                        'Terminé le ${portfolio.completedAt!.day}/${portfolio.completedAt!.month}/${portfolio.completedAt!.year}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
                
                // Tags
                if (portfolio.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: portfolio.tags.map((tag) => Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.grey[200],
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
                ],
                
                // Actions
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _deletePortfolio(portfolio.id),
                      child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implémenter l'édition du portfolio
                      },
                      child: const Text('Modifier'),
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

  // Widget pour afficher la section vide du portfolio
  Widget _buildEmptyPortfolioSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Aucun projet dans votre portfolio',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez vos réalisations pour les montrer à vos clients potentiels',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget pour afficher les erreurs de chargement du portfolio
  Widget _buildErrorPortfolioSection() {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red[600]),
            const SizedBox(height: 8),
            Text(
              _portfolioError,
              style: TextStyle(color: Colors.red[800]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _loadPortfolios,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[50],
                foregroundColor: Colors.red[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    bool isLogout = false,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Icon(icon, color: isLogout ? Colors.red : Colors.blue),
        title: Text(
          title,
          style: TextStyle(
            color: isLogout ? Colors.red : null,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? widget.token;
      
      final success = await _authService.logout(token);
      
      if (mounted) {
        if (success) {
          // Rediriger vers l'écran de connexion
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login', // Assurez-vous que cette route est définie dans votre application
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de la déconnexion')),
          );
        }
      }
    }
  }
}
