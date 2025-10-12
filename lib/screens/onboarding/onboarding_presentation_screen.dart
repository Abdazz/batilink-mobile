import 'package:flutter/material.dart';
import '../../constants.dart';

class OnboardingPresentationScreen extends StatelessWidget {
  const OnboardingPresentationScreen({Key? key}) : super(key: key);

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
          // Bottom gradient overlay for text legibility
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
            child: Column(
              children: [
                const SizedBox(height: 32),
                Text(
                  "MoveEase",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      Text(
                        "Powerful Trucks Muscle On Demand Anytime!",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Powerful trucks, ready to deliver anytime anywhere you need.",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      // Custom CTA button styled as in the mock
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(36),
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/onboarding-role');
                          },
                          child: Ink(
                            width: double.infinity,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(36),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF5B5BFF), Color(0xFF6C4DFF)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                // Left circular icon
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF3D3DFF), Color(0xFF7C6BFF)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text(
                                    'Get Started',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Right chevrons inside a small rounded capsule
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
