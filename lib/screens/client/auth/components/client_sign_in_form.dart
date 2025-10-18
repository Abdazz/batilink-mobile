import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:batilink_mobile_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ClientSignInForm extends StatefulWidget {
  const ClientSignInForm({Key? key}) : super(key: key);

  @override
  _ClientSignInFormState createState() => _ClientSignInFormState();
}

class _ClientSignInFormState extends State<ClientSignInForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(
        context,
        listen: false,
      );

      final response = await authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Réponse de connexion réussie: ${response.statusCode}');
        print('Corps de la réponse: ${response.body}');

        // Accéder aux données dans la structure imbriquée
        final data = responseData['data'] ?? {};
        final token = data['access_token'];

        // Gérer la structure de réponse qui peut être différente selon l'endpoint
        Map<String, dynamic> userData;
        if (data.containsKey('user') && data['user'] is Map) {
          userData = data['user'];
        } else if (responseData.containsKey('user') && responseData['user'] is Map) {
          userData = responseData['user'];
        } else {
          userData = data;
        }

        print('Token reçu: $token');
        print('User data reçu: $userData');
        print('Structure de réponse: ${responseData.keys.toList()}');

        if (token != null && token.toString().isNotEmpty) {
          // Stocker le token dans SharedPreferences pour les futures requêtes
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', token.toString());
          await prefs.setString('user', jsonEncode(userData));

          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/client/dashboard',
              arguments: {
                'token': token,
                'userData': userData,
              },
            );
          }
        } else {
          throw Exception('Token manquant dans la réponse du serveur');
        }
      } else {
        print('Échec de connexion: ${response.statusCode}');
        print('Corps de la réponse d\'erreur: ${response.body}');
        throw Exception('Échec de la connexion');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Identifiants incorrects. Veuillez réessayer.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer votre email';
              }
              if (!RegExp(r'^[^@]+@[^\s]+\.[^\s]+$').hasMatch(value)) {
                return 'Veuillez entrer un email valide';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer votre mot de passe';
              }
              if (value.length < 6) {
                return 'Le mot de passe doit contenir au moins 6 caractères';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Se connecter',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/client/register');
            },
            child: const Text("Vous n'avez pas de compte ? S'inscrire"),
          ),
        ],
      ),
    );
  }
}
