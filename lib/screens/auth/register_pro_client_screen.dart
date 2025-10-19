import 'package:flutter/material.dart';
import 'components/sign_up_form.dart';

class RegisterProClientScreen extends StatefulWidget {
  const RegisterProClientScreen({Key? key}) : super(key: key);

  @override
  State<RegisterProClientScreen> createState() => _RegisterProClientScreenState();
}

class _RegisterProClientScreenState extends State<RegisterProClientScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscription Pro-Client'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Logo et titre
              Column(
                children: [
                  // Logo circulaire avec icône pro-client
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.people_outline,
                      size: 40,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Créer un compte Pro-Client',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Remplissez le formulaire ci-dessous pour créer votre compte Pro-Client avec accès client et professionnel',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Formulaire d'inscription (sans Card wrapper)
              SignUpForm(formKey: _formKey, centerButton: true, role: 'pro_client'),
            ],
          ),
        ),
      ),
    );
  }
}
