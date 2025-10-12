import 'dart:convert';
import 'package:flutter/material.dart';
import '../../constants.dart';
import 'components/sign_up_form.dart';

class RegisterProfessionalScreen extends StatefulWidget {
  const RegisterProfessionalScreen({Key? key}) : super(key: key);

  @override
  State<RegisterProfessionalScreen> createState() => _RegisterProfessionalScreenState();
}

class _RegisterProfessionalScreenState extends State<RegisterProfessionalScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Inscription Professionnel', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Image de fond (asset existant) + léger dégradé sombre
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
                      Color.fromARGB(160, 0, 0, 0),
                      Color.fromARGB(60, 0, 0, 0),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    color: Colors.white.withOpacity(0.97),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Créer un compte professionnel",
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              const Text("Déjà un compte ?"),
                              TextButton(
                                onPressed: () => Navigator.pushReplacementNamed(context, '/login-professional'),
                                child: const Text(
                                  "Se connecter",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SignUpForm(formKey: _formKey, centerButton: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // Widget utilitaire pour fallback sur icône Flutter si asset absent
  Widget _buildSocialIcon(String assetPath, IconData fallback, Color color) {
    return Image.asset(
      assetPath,
      height: 32,
      width: 32,
      errorBuilder: (context, error, stackTrace) {
        return Icon(fallback, color: color, size: 32);
      },
    );
  }
}
