import 'package:flutter/material.dart';
import '../../constants.dart';

class OnboardingAuthChoiceScreen extends StatelessWidget {
  final String? role;
  const OnboardingAuthChoiceScreen({Key? key, this.role}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String? roleArg = ModalRoute.of(context)?.settings.arguments as String? ?? role;
    final bool isProfessional = roleArg == 'professional';
    return Scaffold(
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
                      Color.fromARGB(200, 0, 0, 0),
                      Color.fromARGB(120, 0, 0, 0),
                      Color.fromARGB(40, 0, 0, 0),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.25, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: Column(
                      children: [
                        Icon(isProfessional ? Icons.engineering : Icons.person, size: 84, color: Colors.white),
                        const SizedBox(height: 24),
                        Text(
                          isProfessional ? "Espace Professionnel" : "Espace Client",
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        // Login CTA (filled gradient)
                        _GradientButton(
                          label: 'Se connecter',
                          onTap: () {
                            if (isProfessional) {
                              Navigator.pushNamed(context, '/login-professional');
                            } else {
                              Navigator.pushReplacementNamed(context, '/client/login');
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        // Register CTA (outlined translucent)
                        _OutlinedLightButton(
                          label: 'Créer un compte',
                          onTap: () {
                            if (isProfessional) {
                              Navigator.pushNamed(context, '/register-professional');
                            } else {
                              Navigator.pushReplacementNamed(context, '/client/register');
                            }
                          },
                        ),
                      ],
                    ),
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

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GradientButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF5B5BFF), Color(0xFF6C4DFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: const Center(
            child: Text(
              'Se connecter',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedLightButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlinedLightButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withOpacity(0.08),
            border: Border.all(color: Colors.white70, width: 1.5),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
