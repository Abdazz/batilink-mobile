import 'dart:io';
import 'dart:convert';
import 'package:batilink_mobile_app/core/app_config.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart'; // Pour MediaType
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClientEditProfileScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> userData;

  const ClientEditProfileScreen({
    Key? key,
    required this.token,
    required this.userData,
  }) : super(key: key);

  @override
  _ClientEditProfileScreenState createState() => _ClientEditProfileScreenState();
}

class _ClientEditProfileScreenState extends State<ClientEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.userData['first_name'] ?? '');
    _lastNameController = TextEditingController(text: widget.userData['last_name'] ?? '');
    _emailController = TextEditingController(text: widget.userData['email'] ?? '');
    _phoneController = TextEditingController(text: widget.userData['phone'] ?? '');
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    
    // Debug print user data
    print('User data in edit profile:');
    print('First name: ${widget.userData['first_name']}');
    print('Last name: ${widget.userData['last_name']}');
    print('Email: ${widget.userData['email']}');
    print('Avatar URL: ${widget.userData['avatar']}');
  }
  
  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Conteneur principal de l'avatar
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: _buildImageContent(),
            ),
          ),
          // Icône de la caméra
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          // Indicateur de chargement
          if (_isLoading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(60),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageContent() {
    // Afficher l'image sélectionnée si elle existe
    if (_profileImage != null) {
      return Image.file(
        _profileImage!,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Erreur de chargement de l\'image locale: $error');
          return _buildDefaultAvatar();
        },
      );
    }
    
    // Afficher l'image existante depuis l'URL si disponible
    final avatarUrl = widget.userData['avatar'] ?? widget.userData['profile_photo_url'];
    if (avatarUrl != null && avatarUrl.toString().isNotEmpty && avatarUrl.toString() != 'null') {
      // Ajouter un paramètre de cache busting
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final cachedUrl = '$avatarUrl${avatarUrl.toString().contains('?') ? '&' : '?'}t=$cacheBuster';
      
      return CachedNetworkImage(
        imageUrl: cachedUrl,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildDefaultAvatar(),
        errorWidget: (context, url, error) {
          print('Erreur de chargement de l\'image distante: $error');
          return _buildDefaultAvatar();
        },
      );
    }
    
    // Afficher l'avatar par défaut si aucune image n'est disponible
    return _buildDefaultAvatar();
  }
  
  Widget _buildDefaultAvatar() {
    final firstName = widget.userData['first_name']?.toString().isNotEmpty == true 
        ? widget.userData['first_name'][0].toUpperCase() 
        : '';
    final lastName = widget.userData['last_name']?.toString().isNotEmpty == true 
        ? widget.userData['last_name'][0].toUpperCase() 
        : '';
    final initials = '$firstName$lastName';
    
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.blue[100],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials.isNotEmpty ? initials : 'U',
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Qualité réduite pour des fichiers plus légers
        maxWidth: 1024,   // Largeur maximale de 1024px
        maxHeight: 1024,  // Hauteur maximale de 1024px
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();
        const maxSize = 5 * 1024 * 1024; // 5MB

        if (fileSize > maxSize) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('L\'image est trop volumineuse. Taille maximale : 5MB'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _profileImage = file;
        });

        // Afficher un message de succès
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image sélectionnée avec succès'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection de l\'image: $e')),
        );
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      print('Validation du formulaire échouée');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('Début de la mise à jour du profil...');
      final url = Uri.parse('${AppConfig.baseUrl}/api/profile');
      
      // Créer la requête multipart
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer ${widget.token}'
        ..headers['Accept'] = 'application/json';
      
      // Ne pas définir explicitement Content-Type, il sera défini automatiquement avec la bonne boundary
      print('En-têtes de la requête: ${request.headers}');

      // Ajouter les champs texte
      request.fields.addAll({
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        '_method': 'PUT', // Pour la compatibilité avec Laravel
      });
      
      print('Champs texte ajoutés à la requête');
      
      // Ajouter les champs de mot de passe s'ils sont remplis
      if (_currentPasswordController.text.isNotEmpty) {
        request.fields['current_password'] = _currentPasswordController.text;
        print('Champ de mot de passe actuel ajouté');
      }
      
      if (_newPasswordController.text.isNotEmpty) {
        request.fields['new_password'] = _newPasswordController.text;
        print('Nouveau champ de mot de passe ajouté');
      }

      // Ajouter l'image de profil si sélectionnée
      if (_profileImage != null) {
        print('Ajout de l\'image de profil: ${_profileImage!.path}');
        try {
          // Utiliser fromPath pour éviter de charger tout le fichier en mémoire
          final file = await http.MultipartFile.fromPath(
            'profile_photo',
            _profileImage!.path,
            contentType: MediaType('image', 'jpeg'), // Type MIME par défaut
          );
          
          request.files.add(file);
          print('Image de profil ajoutée à la requête (${await _profileImage!.length()} octets)');
        } catch (e) {
          print('Erreur lors de l\'ajout de l\'image de profil: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur lors du chargement de l\'image: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      } else {
        print('Aucune image sélectionnée pour l\'upload');
      }

      // Envoyer la requête
      print('Envoi de la requête vers: $url');
      print('Champs: ${request.fields}');
      print('Fichiers: ${request.files.map((f) => f.filename).toList()}');
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      print('Statut de la réponse: ${response.statusCode}');
      print('En-têtes de la réponse: ${response.headers}');
      print('Corps de la réponse: ${response.body}');

      // Traiter la réponse
      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          print('Données de la réponse: $responseData');
          
          // Mettre à jour le stockage local avec les nouvelles données
          final prefs = await SharedPreferences.getInstance();
          final userData = Map<String, dynamic>.from(widget.userData);
          
          // Mettre à jour les champs de base
          userData['first_name'] = _firstNameController.text.trim();
          userData['last_name'] = _lastNameController.text.trim();
          userData['email'] = _emailController.text.trim();
          userData['phone'] = _phoneController.text.trim();
          
          // Mettre à jour l'URL de l'avatar depuis la réponse
          String? newAvatarUrl;
          
          // Essayer de récupérer l'URL de l'avatar depuis différentes parties de la réponse
          if (responseData['data']?['user']?['profile_photo_url'] != null) {
            newAvatarUrl = responseData['data']['user']['profile_photo_url'];
          } else if (responseData['data']?['user']?['avatar'] != null) {
            newAvatarUrl = responseData['data']['user']['avatar'];
          } else if (responseData['user']?['profile_photo_url'] != null) {
            newAvatarUrl = responseData['user']['profile_photo_url'];
          } else if (responseData['user']?['avatar'] != null) {
            newAvatarUrl = responseData['user']['avatar'];
          } else if (responseData['profile_photo_url'] != null) {
            newAvatarUrl = responseData['profile_photo_url'];
          } else if (responseData['avatar'] != null) {
            newAvatarUrl = responseData['avatar'];
          }
          
          // Mettre à jour les URLs d'avatar si une nouvelle URL a été trouvée
          if (newAvatarUrl != null) {
            print('Mise à jour de l\'URL de l\'avatar: $newAvatarUrl');
            userData['avatar'] = newAvatarUrl;
            userData['profile_photo_url'] = newAvatarUrl;
            
            // Ajouter un paramètre de cache busting
            final cacheBuster = DateTime.now().millisecondsSinceEpoch;
            final cachedAvatarUrl = '$newAvatarUrl${newAvatarUrl.contains('?') ? '&' : '?'}t=$cacheBuster';
            userData['cached_avatar_url'] = cachedAvatarUrl;
          }
          
          // Sauvegarder les données mises à jour
          await prefs.setString('user_data', json.encode(userData));
          print('Stockage local mis à jour avec les données: $userData');

          if (mounted) {
            // Afficher un message de succès
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profil mis à jour avec succès'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Retourner les données mises à jour à l'écran précédent
            Navigator.pop(context, userData);
          }
        } catch (e) {
          print('Erreur lors de l\'analyse de la réponse: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur lors de la mise à jour du profil: format de réponse invalide'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Gestion des erreurs HTTP
        String errorMessage = 'Erreur lors de la mise à jour du profil';
        
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
          
          // Si des erreurs de validation sont renvoyées
          if (errorData['errors'] != null) {
            final errors = errorData['errors'] as Map<String, dynamic>;
            errorMessage += '\n' + errors.entries
                .map((e) => '${e.key}: ${e.value.join(', ')}')
                .join('\n');
          }
        } catch (e) {
          errorMessage = 'Erreur ${response.statusCode}: ${response.body}';
        }
        
        print('Erreur lors de la mise à jour du profil: $errorMessage');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
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
          'Modifier le profil',
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
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _updateProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Enregistrer',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Picture
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[200],
                            child: _buildProfileImage(),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFCC00),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 20),
                                color: Colors.white,
                                onPressed: _pickImage,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // First Name
                    TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: 'Prénom',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez entrer votre prénom';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Last Name
                    TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Nom',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez entrer votre nom';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez entrer votre email';
                        }
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                          return 'Veuillez entrer un email valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Téléphone',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez entrer votre numéro de téléphone';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Change Password Section
                    const Text(
                      'Changer le mot de passe',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Laissez ces champs vides pour conserver votre mot de passe actuel',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Current Password
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe actuel',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (_newPasswordController.text.isNotEmpty &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Le mot de passe actuel est requis pour le modifier';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // New Password
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (_currentPasswordController.text.isNotEmpty &&
                            (value == null || value.trim().length < 6)) {
                          return 'Le mot de passe doit contenir au moins 6 caractères';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFCC00),
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
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Enregistrer les modifications',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
