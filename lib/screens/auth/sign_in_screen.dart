import 'sign_up_screen.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';
import 'components/sign_in_form.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;

  Future<void> _handleLogin(String email, String password) async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: Implémenter l'appel à l'API de connexion
      // Exemple :
      // final user = await AuthService.signIn(email, password, _rememberMe);
      await Future.delayed(const Duration(seconds: 2)); // Simulation de chargement
      
      // Si la connexion réussit, naviguer vers l'écran d'accueil
      // ignore: use_build_context_synchronously
      // Navigator.pushReplacementNamed(context, '/home');
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Email ou mot de passe incorrect';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
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
                  // Top bar with back and title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Text(
                        'MoveEase',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 36),
                  // Center title
                  Center(
                    child: Column(
                      children: const [
                        Icon(Icons.download_rounded, color: Colors.white70),
                        SizedBox(height: 8),
                        Text(
                          'Login to Doorstep',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Segmented control (Login selected)
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
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SignUpScreen()),
                            ),
                            child: Center(
                              child: Text('Sign Up', style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Theme the inputs as pills
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SignInForm(
                          formKey: _formKey,
                          onSaved: _handleLogin,
                          isLoading: _isLoading,
                          errorMessage: _errorMessage,
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (v) => setState(() => _rememberMe = v ?? false),
                              activeColor: const Color(0xFF5B5BFF),
                            ),
                            const Text('Remember me', style: TextStyle(color: Colors.white70)),
                            const Spacer(),
                            TextButton(
                              onPressed: () {},
                              child: const Text('Forgot Password?', style: TextStyle(color: Colors.white70)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Login gradient button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _isLoading
                            ? null
                            : () {
                                if (_formKey.currentState!.validate()) {
                                  _formKey.currentState!.save();
                                }
                              },
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
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
                        child: Text('Or login with', style: TextStyle(color: Colors.white70)),
                      ),
                      Expanded(child: Container(height: 1, color: Colors.white24)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Social buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _SocialButton(icon: Icons.g_mobiledata, onPressed: null),
                      SizedBox(width: 20),
                      _SocialButton(icon: Icons.facebook, onPressed: null),
                      SizedBox(width: 20),
                      _SocialButton(icon: Icons.apple, onPressed: null),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _SocialButton({
    Key? key,
    required this.icon,
    this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}