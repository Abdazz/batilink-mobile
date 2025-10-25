import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../core/app_config.dart';

class LoginProClientScreen extends StatefulWidget {
  const LoginProClientScreen({Key? key}) : super(key: key);

  @override
  State<LoginProClientScreen> createState() => _LoginProClientScreenState();
}

class _LoginProClientScreenState extends State<LoginProClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService(baseUrl: AppConfig.baseUrl);

  String? _email, _password;
  bool _loading = false;
  String? _error;

  // Méthode pour vérifier localement si le profil est complet basé sur les données du serveur
  bool _isProfileCompleteFromData(dynamic data) {
    print('DEBUG : _isProfileCompleteFromData appelé avec data: $data');

    // Support pour structure imbriquée (data['data']) ou directe
    final responseData = data['data'] ?? data;

    final user = responseData['user'];
    print('DEBUG : user trouvé: $user');
    if (user == null || user['role'] != 'pro_client') {
      print('DEBUG : user null ou rôle pas pro_client');
      return false;
    }

    final proClient = user['pro_client'];
    print('DEBUG : pro_client trouvé: $proClient');
    if (proClient == null) {
      print('DEBUG : pro_client null');
      return false;
    }

    // Vérifier les champs requis (même logique que côté serveur)
    final companyName = proClient['company_name']?.toString().trim();
    final jobTitle = proClient['job_title']?.toString().trim();
    final address = proClient['address']?.toString().trim();
    final city = proClient['city']?.toString().trim();
    final postalCode = proClient['postal_code']?.toString().trim();

    print('DEBUG : Champs extraits - companyName: "$companyName", jobTitle: "$jobTitle", address: "$address", city: "$city", postalCode: "$postalCode"');

    // Vérifier si tous les champs sont présents ET non vides
    final isComplete = (companyName != null && companyName.isNotEmpty) &&
           (jobTitle != null && jobTitle.isNotEmpty) &&
           (address != null && address.isNotEmpty) &&
           (city != null && city.isNotEmpty) &&
           (postalCode != null && postalCode.isNotEmpty);

    print('DEBUG : _isProfileCompleteFromData retourne: $isComplete');
    return isComplete;
  }

  String? _extractToken(dynamic data) {
    if (data is String) return data;
    if (data is Map) {
      // Formats courants
      final direct = data['token'] ?? data['access_token'] ?? data['accessToken'];
      if (direct is String && direct.isNotEmpty) return direct;

      // authorisation / authorization objects
      final authObj = data['authorisation'] ?? data['authorization'];
      if (authObj is Map) {
        final t = authObj['token'];
        if (t is String && t.isNotEmpty) return t;
      }

      // data.*
      final inner = data['data'];
      if (inner is Map) {
        final innerDirect = inner['token'] ?? inner['access_token'] ?? inner['accessToken'];
        if (innerDirect is String && innerDirect.isNotEmpty) return innerDirect;
        final innerAuth = inner['authorisation'] ?? inner['authorization'];
        if (innerAuth is Map) {
          final t = innerAuth['token'];
          if (t is String && t.isNotEmpty) return t;
        }
      }
    }
    return null;
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() { _loading = true; _error = null; });

    try {
      final response = await _authService.loginWithDevice(
        email: _email!,
        password: _password!,
        deviceName: 'batilink-mobile',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = _extractToken(data);

        if (token != null && token.isNotEmpty) {
          // Stocker le token
          final sessionService = SessionService();
          await sessionService.saveToken(token);

          // Stocker les données utilisateur si disponibles
          if (data != null && data is Map<String, dynamic>) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_data', json.encode(data));
            print('DEBUG : Données utilisateur sauvegardées dans SharedPreferences');
          }

          // Récupérer la redirection depuis la réponse de login (si présente)
          final responseData = data['data'] ?? data; // Support pour structure imbriquée ou directe
          final redirectTo = responseData['redirect_to']?.toString();
          final profileCompleted = responseData['profile_completed'];

          print('DEBUG : Données reçues du serveur:');
          print('DEBUG : profileCompleted: $profileCompleted');
          print('DEBUG : redirectTo: $redirectTo');

          // Logique de redirection basée sur la réponse serveur (PRIORITAIRE)
          bool shouldRedirectToDashboard = false;

          // Prioriser la réponse serveur sur toute logique locale
          if (profileCompleted == false) {
            shouldRedirectToDashboard = false;
            print('DEBUG : Serveur dit profil incomplet');
          } else if (profileCompleted == true) {
            shouldRedirectToDashboard = true;
            print('DEBUG : Serveur dit profil complet');
          } else {
            // Si le serveur ne fournit pas profile_completed, utiliser redirect_to
            if (redirectTo == '/pro-client/complete-profile') {
              shouldRedirectToDashboard = false;
              print('DEBUG : redirect_to indique completion');
            } else if (redirectTo == '/pro-client/dashboard') {
              shouldRedirectToDashboard = true;
              print('DEBUG : redirect_to indique dashboard');
            } else {
              // Fallback: vérifier localement si le profil semble complet
              print('DEBUG : Aucun flag serveur, utilisation vérification locale');
              shouldRedirectToDashboard = _isProfileCompleteFromData(data);
            }
          }

          print('Décision finale : shouldRedirectToDashboard=$shouldRedirectToDashboard');
          print('Raison : profileCompleted=$profileCompleted, redirectTo=$redirectTo');

          if (shouldRedirectToDashboard) {
            print('DEBUG : Redirection vers dashboard pro-client');
            // Profil complet, aller vers le tableau de bord pro-client
            if (mounted) {
              Navigator.pushReplacementNamed(
                context,
                '/pro-client/dashboard',
                arguments: {
                  'token': token.toString(),
                  'profile_completed': true,
                  'userData': data, // ← Passer les données utilisateur complètes
                },
              );
            }
          } else {
            print('DEBUG : Redirection vers complétion du profil pro-client');
            // Pas besoin de récupérer le profil car il n'existe pas encore (profile_completed=false)
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/pro-client/complete-profile');
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _error = 'Token non trouvé dans la réponse';
              _loading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Email ou mot de passe incorrect';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur de connexion: ${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Logo et titre
              Column(
                children: [
                  // Remplacer par votre logo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.business_center_outlined,
                      size: 50,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Connexion Pro-Client',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connectez-vous pour accéder à votre espace professionnel',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // Formulaire de connexion
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Email field
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Email requis';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                          return 'Email invalide';
                        }
                        return null;
                      },
                      onSaved: (value) => _email = value,
                    ),
                    const SizedBox(height: 20),
                    // Password field
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Mot de passe requis';
                        if (value!.length < 8) return 'Au moins 8 caractères';
                        return null;
                      },
                      onSaved: (value) => _password = value,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Se connecter',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Forgot password
                    Center(
                      child: TextButton(
                        onPressed: () {
                          // TODO: Implement forgot password
                        },
                        child: const Text('Mot de passe oublié ?'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Bouton retour
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
