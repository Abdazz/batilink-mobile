import 'package:flutter/material.dart';
import '../../constants.dart';

class OnboardingRoleScreen extends StatelessWidget {
  const OnboardingRoleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    "MoveEase",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  const Icon(Icons.group, size: 84, color: Colors.white),
                  const SizedBox(height: 24),
                  Text(
                    "Vous êtes :",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _RoleButton(
                          label: 'Client',
                          icon: Icons.person,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5B5BFF), Color(0xFF6C4DFF)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          textColor: Colors.white,
                          onTap: () => Navigator.pushReplacementNamed(context, '/auth-choice', arguments: 'client'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _RoleButton(
                          label: 'Professionnel',
                          icon: Icons.engineering,
                          gradient: const LinearGradient(
                            colors: [Colors.white24, Colors.white24],
                          ),
                          textColor: Colors.white,
                          outlined: true,
                          onTap: () => Navigator.pushReplacementNamed(context, '/auth-choice', arguments: 'professional'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final Color textColor;
  final bool outlined;
  final VoidCallback onTap;

  const _RoleButton({
    super.key,
    required this.label,
    required this.icon,
    required this.gradient,
    required this.textColor,
    this.outlined = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: outlined ? null : gradient,
            color: outlined ? Colors.transparent : null,
            border: outlined ? Border.all(color: Colors.white70, width: 2) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
