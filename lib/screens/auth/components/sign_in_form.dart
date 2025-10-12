import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';

import '../../../constants.dart';
import 'sign_up_form.dart';

class SignInForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final Function(String, String) onSaved;
  final bool isLoading;
  final String? errorMessage;

  const SignInForm({
    Key? key,
    required this.formKey,
    required this.onSaved,
    this.isLoading = false,
    this.errorMessage,
  }) : super(key: key);

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  late String _email;
  late String _password;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _email = '';
    _password = '';
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                widget.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          
          const TextFieldName(text: "Email"),
          TextFormField(
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: "votre@email.com",
              filled: true,
              fillColor: Colors.white.withOpacity(0.9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: EmailValidator(errorText: "Veuillez entrer un email valide"),
            onSaved: (email) => _email = email?.trim() ?? '',
            onChanged: (value) => _email = value.trim(),
            enabled: !widget.isLoading,
          ),
          const SizedBox(height: 16),
          
          const TextFieldName(text: "Mot de passe"),
          TextFormField(
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: "••••••••",
              filled: true,
              fillColor: Colors.white.withOpacity(0.9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey[600],
                ),
                onPressed: widget.isLoading 
                    ? null 
                    : () => setState(() => _obscurePassword = !_obscurePassword),
              ),
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
            onSaved: (password) => _password = password ?? '',
            onChanged: (value) => _password = value,
            enabled: !widget.isLoading,
          ),
          
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.isLoading 
                  ? null 
                  : () {
                      // TODO: Implémenter la réinitialisation du mot de passe
                    },
              child: const Text(
                'Mot de passe oublié ?',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool validateAndSave() {
    final form = widget.formKey.currentState;
    if (form?.validate() ?? false) {
      form?.save();
      widget.onSaved(_email, _password);
      return true;
    }
    return false;
  }
}

class TextFieldName extends StatelessWidget {
  final String text;
  
  const TextFieldName({
    Key? key,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }
}