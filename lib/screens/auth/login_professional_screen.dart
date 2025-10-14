import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../professional/professional_complete_profile_screen.dart';

class LoginProfessionalScreen extends StatefulWidget {
  const LoginProfessionalScreen({Key? key}) : super(key: key);

  @override
  State<LoginProfessionalScreen> createState() => _LoginProfessionalScreenState();
}

class _LoginProfessionalScreenState extends State<LoginProfessionalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService(baseUrl: 'http://10.0.2.2:8000');

  String? _email, _password;
  bool _loading = false;
  String? _error;

  String? _extractToken(dynamic data) {
    if (data == null) return null;
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
    final response = await _authService.loginWithDevice(
      email: _email!,
      password: _password!,
      deviceName: 'batilink-mobile',
    );
    setState(() { _loading = false; });
    if (response.statusCode == 200) {
      final dynamic data = jsonDecode(response.body);
      final token = _extractToken(data);
      if (token == null || token.toString().isEmpty) {
        setState(() { _error = 'Token manquant dans la réponse du serveur'; });
        return;
      }
      // Sauvegarder le token en session
      await SessionService().saveToken(token.toString());
      setState(() { _loading = true; });
      try {
        final profResp = await _authService.getProfessionalProfile(accessToken: token);
        setState(() { _loading = false; });
        if (profResp.statusCode == 200) {
          final profData = jsonDecode(profResp.body);
          final profile = (profData is Map && profData['data'] != null) ? profData['data'] : profData;

          // Gérer les deux formats de données du profil
          Map<String, dynamic> profileData;
          if (profile is List && profile.isNotEmpty) {
            profileData = profile[0] as Map<String, dynamic>;
          } else if (profile is Map) {
            profileData = profile as Map<String, dynamic>;
          } else {
            profileData = {};
          }

          // Vérifier si le profil est marqué comme complet par l'API
          if (profileData['profile_completed'] == true) {
            // Aller vers le tableau de bord professionnel
            if (mounted) {
              Navigator.pushReplacementNamed(
                context,
                '/pro/nav',
                arguments: {
                  'token': token.toString(),
                  'profile': profile,
                },
              );
            }
          } else {
            // Vérifier les champs manquants
            bool isEmptyStr(v) => v == null || (v is String && v.trim().isEmpty);
            final missing = <String>[];
            if (isEmptyStr(profileData['company_name'])) missing.add('company_name');
            if (isEmptyStr(profileData['job_title'])) missing.add('job_title');
            if (isEmptyStr(profileData['address'])) missing.add('address');
            if (isEmptyStr(profileData['city'])) missing.add('city');
            if (isEmptyStr(profileData['postal_code'])) missing.add('postal_code');

            if (missing.isNotEmpty) {
              // Aller vers l'écran de complétion du profil
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfessionalCompleteProfileScreen(
                      token: token.toString(),
                      profile: profile,
                      missingFields: missing,
                    ),
                  ),
                );
              }
            } else {
              // Si aucun champ n'est manquant mais que le profil n'est pas marqué comme complet
              // On marque le profil comme complet et on redirige vers le tableau de bord
              if (mounted) {
                Navigator.pushReplacementNamed(
                  context,
                  '/pro/nav',
                  arguments: {
                    'token': token.toString(),
                    'profile': profile,
                  },
                );
              }
            }
          }
        } else {
          setState(() { _error = 'Impossible de récupérer le profil (${profResp.statusCode})'; });
        }
      } catch (e) {
        setState(() { _loading = false; _error = 'Erreur réseau lors de la récupération du profil'; });
      }
    } else {
      try {
        final body = jsonDecode(response.body);
        String message = 'Erreur inconnue';
        if (body is Map) {
          message = (body['message']?.toString() ?? message);
          if (response.statusCode == 403) {
            message = message.isNotEmpty ? message : "Votre compte n'est pas actif.";
          }
          if (response.statusCode == 429) {
            // backend renvoie déjà un message avec secondes
            message = message.isNotEmpty ? message : 'Trop de tentatives. Réessayez plus tard.';
          }
          if (response.statusCode == 422 && body['errors'] is Map && (body['errors'] as Map).isNotEmpty) {
            final firstKey = (body['errors'] as Map).keys.first;
            final firstVal = body['errors'][firstKey];
            if (firstVal is List && firstVal.isNotEmpty) message = firstVal.first.toString();
            if (firstVal is String) message = firstVal;
          }
        }
        setState(() { _error = message; });
      } catch (_) {
        setState(() { _error = 'Erreur ${response.statusCode}'; });
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
              const SizedBox(height: 16),
              // Bouton retour
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 24),
              // Logo et titre
              Column(
                children: [
                  // Logo circulaire avec icône professionnelle
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
                    'Connexion Professionnelle',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connectez-vous à votre espace professionnel',
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
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Email professionnel',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v == null || !v.contains('@') ? 'Email invalide' : null,
                      onSaved: (v) => _email = v,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (v) => v == null || v.length < 6 ? '6 caractères minimum' : null,
                      onSaved: (v) => _password = v,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Se connecter',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Divider avec texte
                    Row(
                      children: [
                        Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text('Ou se connecter avec', style: TextStyle(color: Colors.grey)),
                        ),
                        Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Boutons sociaux adaptés au nouveau design
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                            ),
                            onPressed: _loading ? null : () {},
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.g_mobiledata, color: Colors.grey),
                                SizedBox(width: 8),
                                Text('Google'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                            ),
                            onPressed: _loading ? null : () {},
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.facebook, color: Colors.grey),
                                SizedBox(width: 8),
                                Text('Facebook'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/register-professional');
                      },
                      child: const Text("Vous n'avez pas de compte ? S'inscrire"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
