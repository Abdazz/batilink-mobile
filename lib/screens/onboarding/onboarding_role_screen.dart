import 'package:flutter/material.dart';

class OnboardingRoleScreen extends StatefulWidget {
  const OnboardingRoleScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingRoleScreen> createState() => _OnboardingRoleScreenState();
}

class _OnboardingRoleScreenState extends State<OnboardingRoleScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
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
        color: const Color(0xFFFFCC00), // Bleu primaire uniquement
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  children: [
                    // Header avec titre animé
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 0.8 + (0.2 * _animationController.value),
                          child: child,
                        );
                      },
                      child: Column(
                        children: [
                          const Text(
                            "Batilink",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  offset: Offset(2, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "Choisissez votre profil",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Icône centrale animée
                    // AnimatedBuilder(
                    //   animation: _animationController,
                    //   builder: (context, child) {
                    //     return Transform.scale(
                    //       scale: 0.7 + (0.3 * _animationController.value),
                    //       child: Container(
                    //         width: 120,
                    //         height: 120,
                    //         decoration: BoxDecoration(
                    //           shape: BoxShape.circle,
                    //           gradient: const LinearGradient(
                    //             colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    //             begin: Alignment.topLeft,
                    //             end: Alignment.bottomRight,
                    //           ),
                    //           boxShadow: [
                    //             BoxShadow(
                    //               color: Colors.black.withOpacity(0.2),
                    //               spreadRadius: 3,
                    //               blurRadius: 8,
                    //               offset: const Offset(0, 4),
                    //             ),
                    //           ],
                    //         ),
                    //         child: const Icon(
                    //           Icons.people_outline,
                    //           size: 60,
                    //           color: Colors.white,
                    //         ),
                    //       ),
                    //     );
                    //   },
                    // ),

                    // const SizedBox(height: 32),

                    // // Titre principal
                    // Text(
                    //   "Vous êtes :",
                    //   style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    //         fontWeight: FontWeight.bold,
                    //         color: const Color(0xFF1976D2), // Bleu foncé
                    //         fontSize: 24,
                    //       ),
                    //   textAlign: TextAlign.center,
                    // ),

                    // const SizedBox(height: 40),

                    // Cartes de rôle avec animations en cascade
                    Column(
                      children: [
                        _AnimatedRoleCard(
                          delay: 200,
                          child: _RoleCard(
                            title: 'Client',
                            subtitle: 'Trouvez des professionnels qualifiés',
                            icon: Icons.person_outline,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            onTap: () => Navigator.pushNamed(context, '/auth-choice', arguments: 'client'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _AnimatedRoleCard(
                          delay: 400,
                          child: _RoleCard(
                            title: 'Professionnel',
                            subtitle: 'Proposez vos services',
                            icon: Icons.engineering_outlined,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            outlined: true,
                            onTap: () => Navigator.pushNamed(context, '/auth-choice', arguments: 'professional'),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Footer décoratif
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF2196F3), // Bleu primaire
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF42A5F5), // Bleu plus clair
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF64B5F6), // Bleu encore plus clair
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

class _AnimatedRoleCard extends StatefulWidget {
  final int delay;
  final Widget child;

  const _AnimatedRoleCard({
    required this.delay,
    required this.child,
  });

  @override
  State<_AnimatedRoleCard> createState() => _AnimatedRoleCardState();
}

class _AnimatedRoleCardState extends State<_AnimatedRoleCard>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final bool outlined;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    this.outlined = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: outlined ? null : gradient,
              color: outlined ? Colors.white : null,
              border: outlined
                  ? Border.all(
                      color: const Color(0xFF42A5F5).withOpacity(0.5),
                      width: 2,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: outlined
                        ? const Color(0xFF2196F3).withOpacity(0.1)
                        : Colors.white.withOpacity(0.2),
                  ),
                  child: Icon(
                    icon,
                    size: 30,
                    color: outlined ? const Color(0xFF2196F3) : Colors.white,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: outlined ? const Color(0xFF1976D2) : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: outlined
                              ? const Color(0xFF1976D2).withOpacity(0.8)
                              : Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: outlined ? const Color(0xFF2196F3) : Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
