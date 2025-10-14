import 'package:flutter/material.dart';

class OnboardingPresentationScreen extends StatefulWidget {
  const OnboardingPresentationScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingPresentationScreen> createState() => _OnboardingPresentationScreenState();
}

class _OnboardingPresentationScreenState extends State<OnboardingPresentationScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFFFFCC00), // Bleu primaire
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, '/onboarding-role');
              },
              child: Container(
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icône et BATILINK centrés
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Juste l'icône sans cercle
                          const Icon(
                            Icons.construction_outlined,
                            size: 80,
                            color: Colors.white,
                          ),

                          const SizedBox(height: 20),

                          // Texte BATILINK
                          Text(
                            "BATILINK",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(2, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
