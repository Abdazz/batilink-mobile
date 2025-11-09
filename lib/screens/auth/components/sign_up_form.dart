import 'package:form_field_validator/form_field_validator.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../services/auth_service.dart';
import '../../../core/app_config.dart';
import '../../../constants.dart';

class SignUpForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final bool centerButton;
  final String? role;
  final Function(bool)? onLoading;
  final Function(String)? onError;

  const SignUpForm({
    Key? key,
    required this.formKey,
    this.centerButton = false,
    this.role,
    this.onLoading,
    this.onError,
  }) : super(key: key);

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  bool _loading = false;
  String? _error;
  late final AuthService _authService;
  
  @override
  void initState() {
    super.initState();
    _authService = AuthService(baseUrl: AppConfig.baseUrl);
  }

  late String _firstName;
  late String _lastName;
  late String _email;
  late String _phoneNumber;
  late String _password;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _termsAccepted = false;

  Widget _buildSubmitButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      onPressed: _loading || !_termsAccepted ? null : _submit,
      child: _loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text(
              'S\'INSCRIRE',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!widget.formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      final error = 'Veuvez accepter les conditions d\'utilisation';
      setState(() => _error = error);
      widget.onError?.call(error);
      return;
    }
    widget.formKey.currentState!.save();
    
    setState(() => _loading = true);
    widget.onLoading?.call(true);
    setState(() => _error = null);
    widget.onError?.call('');

    try {
      final role = widget.role ?? 'client';
      final response = await _authService.registerUser(
        firstName: _firstName,
        lastName: _lastName,
        email: _email,
        phone: _phoneNumber,
        password: _password,
        passwordConfirmation: _password,
        role: role,
      ).timeout(const Duration(seconds: 30));

      setState(() { _loading = false; });

      // Vérifier d'abord si la réponse est un succès
      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['success'] == true) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Inscription réussie'),
                content: Text(
                  role == 'professional'
                    ? 'Votre compte professionnel doit être activé par un administrateur avant l\'accès au dashboard.'
                    : (role == 'pro_client'
                        ? 'Votre compte Pro-Client doit être activé par un administrateur avant l\'accès au dashboard.'
                        : 'Votre compte client a été créé avec succès. Vous pouvez maintenant vous connecter.'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            return; // Sortir de la fonction en cas de succès
          }
        } catch (jsonError) {
          print('Erreur de parsing JSON: $jsonError');
        }

        // Si on ne peut pas parser mais que le status est OK, considérer comme succès
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Inscription réussie'),
            content: Text(
              role == 'professional'
                ? 'Votre compte professionnel doit être activé par un administrateur avant l\'accès au dashboard.'
                : (role == 'pro_client'
                    ? 'Votre compte Pro-Client doit être activé par un administrateur avant l\'accès au dashboard.'
                    : 'Votre compte client a été créé avec succès. Vous pouvez maintenant vous connecter.'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Si on arrive ici, c'est une vraie erreur
      String message = 'Erreur inconnue';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) {
          message = body['message'];
        }
      } catch (_) {}
      setState(() {
        _error = message;
      });
    } catch (e) {
      print('Erreur lors de l\'inscription: $e');
      String errorMessage;
      if (e.toString().contains('TimeoutException')) {
        errorMessage = "Délai d'attente dépassé. Veuillez réessayer.";
      } else {
        errorMessage = 'Une erreur est survenue. Veuillez réessayer.';
      }
      setState(() => _error = errorMessage);
      widget.onError?.call(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        widget.onLoading?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TextFieldName(text: "Prénom"),
                    TextFormField(
                      decoration: const InputDecoration(
                        hintText: "John",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: RequiredValidator(errorText: "Prénom requis"),
                      onSaved: (firstName) => _firstName = firstName!,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TextFieldName(text: "Nom"),
                    TextFormField(
                      decoration: const InputDecoration(
                        hintText: "Doe",
                        border: OutlineInputBorder(),
                      ),
                      validator: RequiredValidator(errorText: "Nom requis"),
                      onSaved: (lastName) => _lastName = lastName!,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: defaultPadding),
          const TextFieldName(text: "Email"),
          TextFormField(
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: "test@email.com",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: EmailValidator(errorText: "Email invalide"),
            onSaved: (email) => _email = email!,
          ),
          const SizedBox(height: defaultPadding),
          const TextFieldName(text: "Téléphone"),
          TextFormField(
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: "+123456789",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: RequiredValidator(errorText: "Numéro de téléphone requis"),
            onSaved: (phone) => _phoneNumber = phone!,
          ),
          const SizedBox(height: defaultPadding),
          const TextFieldName(text: "Mot de passe"),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: "••••••",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Mot de passe requis';
              }
              if (val.length < 6) {
                return 'Le mot de passe doit contenir au moins 6 caractères';
              }
              return null;
            },
            onChanged: (val) {
              setState(() {
                _confirmPasswordController.text = _confirmPasswordController.text;
              });
            },
            onSaved: (password) => _password = password!,
          ),
          const SizedBox(height: defaultPadding),
          const TextFieldName(text: "Confirmer le mot de passe"),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: "••••••",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Veuillez confirmer votre mot de passe';
              }
              if (val != _passwordController.text) {
                return 'Les mots de passe ne correspondent pas';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _termsAccepted,
                onChanged: (value) {
                  setState(() {
                    _termsAccepted = value ?? false;
                  });
                },
              ),
              const Expanded(
                child: Text(
                  "J'accepte les conditions d'utilisation et la politique de confidentialité",
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.centerButton)
            Center(
              child: _buildSubmitButton(),
            )
          else
            SizedBox(
              width: double.infinity,
              child: _buildSubmitButton(),
            ),
        ],
      ),
    );
  }
}

class TextFieldName extends StatelessWidget {
  final String text;
  const TextFieldName({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }
}