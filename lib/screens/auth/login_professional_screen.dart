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
          // Vérifier si le profil est marqué comme complet par l'API
          if (profile['profile_completed'] == true) {
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
            if (isEmptyStr(profile['company_name'])) missing.add('company_name');
            if (isEmptyStr(profile['job_title'])) missing.add('job_title');
            if (isEmptyStr(profile['address'])) missing.add('address');
            if (isEmptyStr(profile['city'])) missing.add('city');
            if (isEmptyStr(profile['postal_code'])) missing.add('postal_code');

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
      extendBody: true,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/onboarding_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color.fromARGB(220, 0, 0, 0),
                      Color.fromARGB(140, 0, 0, 0),
                      Color.fromARGB(60, 0, 0, 0),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.25, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      BackButton(color: Colors.white),
                      Text('MoveEase', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 36),
                  // Center title
                  Center(
                    child: Column(
                      children: const [
                        Icon(Icons.login_rounded, color: Colors.white70),
                        SizedBox(height: 8),
                        Text(
                          "Connexion Professionnelle",
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Segmented control
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Center(
                              child: Text('Login', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => Navigator.pushReplacementNamed(context, '/register-professional'),
                            child: Center(
                              child: Text('Sign Up', style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Themed pill inputs
                  Theme(
                    data: Theme.of(context).copyWith(
                      inputDecorationTheme: InputDecorationTheme(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.85),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            decoration: const InputDecoration(hintText: 'Enter your email', prefixIcon: Icon(Icons.alternate_email_rounded)),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v == null || !v.contains('@') ? 'Email invalide' : null,
                            onSaved: (v) => _email = v,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            decoration: const InputDecoration(hintText: 'Enter your password', prefixIcon: Icon(Icons.lock_outline_rounded)),
                            obscureText: true,
                            validator: (v) => v == null || v.length < 6 ? '6 caractères minimum' : null,
                            onSaved: (v) => _password = v,
                          ),
                          const SizedBox(height: 16),
                          if (_error != null)
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Gradient CTA
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _loading ? null : _submit,
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5B5BFF), Color(0xFF6C4DFF)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                          child: Center(
                            child: _loading
                                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Login', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Divider with text
                  Row(
                    children: [
                      Expanded(child: Container(height: 1, color: Colors.white24)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text('Ou se connecter avec', style: TextStyle(color: Colors.white70)),
                      ),
                      Expanded(child: Container(height: 1, color: Colors.white24)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Social buttons (Google / Facebook)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            backgroundColor: Colors.white.withOpacity(0.12),
                          ),
                          onPressed: _loading ? null : () {},
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.g_mobiledata, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Google'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            backgroundColor: Colors.white.withOpacity(0.12),
                          ),
                          onPressed: _loading ? null : () {},
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.facebook, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Facebook'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
