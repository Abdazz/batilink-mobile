import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../services/auth_service.dart';
import '../../../services/session_service.dart';
import '../../../core/app_config.dart';

class ClientSignInScreen extends StatefulWidget {
  const ClientSignInScreen({Key? key}) : super(key: key);

  @override
  State<ClientSignInScreen> createState() => _ClientSignInScreenState();
}

class _ClientSignInScreenState extends State<ClientSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService(baseUrl: AppConfig.baseUrl);

  String? _email, _password;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
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
        final data = jsonDecode(response.body);
        final token = data['data']?['access_token'];
        
        if (token != null) {
          await SessionService().saveToken(token);
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/client/dashboard');
          }
        } else {
          setState(() { _error = 'Erreur lors de la connexion'; });
        }
      } else {
        final error = jsonDecode(response.body);
        setState(() { _error = error['message'] ?? 'Erreur de connexion'; });
      }
    } catch (e) {
      setState(() { _error = 'Erreur de connexion'; });
    } finally {
      if (mounted) {
        setState(() { _loading = false; });
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
                  // Logo circulaire avec icône utilisateur
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      size: 50,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Connexion Client',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connectez-vous à votre espace client',
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
                        labelText: 'Email',
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
                    // Boutons sociaux
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
                        Navigator.pushReplacementNamed(context, '/client/signup');
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
