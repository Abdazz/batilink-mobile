import 'package:flutter/material.dart';
import 'components/sign_up_form.dart';

class RegisterProClientScreen extends StatefulWidget {
  const RegisterProClientScreen({Key? key}) : super(key: key);

  @override
  State<RegisterProClientScreen> createState() => _RegisterProClientScreenState();
}

class _RegisterProClientScreenState extends State<RegisterProClientScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

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
                  // Logo circulaire avec icône pro-client
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.people_outline,
                      size: 50,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Inscription Pro-Client',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Créez votre compte pour accéder aux fonctionnalités client et professionnel',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // Formulaire d'inscription
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              SignUpForm(
                formKey: _formKey,
                centerButton: true,
                role: 'pro_client',
                onLoading: (isLoading) {
                  if (mounted) {
                    setState(() {
                      _loading = isLoading;
                    });
                  }
                },
                onError: (error) {
                  if (mounted) {
                    setState(() {
                      _error = error;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              // Divider avec texte
              Row(
                children: [
                  Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text('Ou s\'inscrire avec', style: TextStyle(color: Colors.grey)),
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
              // Lien vers la connexion
              TextButton(
                onPressed: _loading ? null : () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text('Déjà un compte ? Se connecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
