import 'package:batilink_mobile_app/screens/pro_client/pro_client_profile_screen.dart';

import 'core/app_config.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/onboarding/onboarding_presentation_screen.dart';
import 'screens/onboarding/onboarding_role_screen.dart';
import 'screens/onboarding/onboarding_auth_choice_screen.dart';
import 'screens/auth/login_pro_client_screen.dart';
import 'screens/auth/login_professional_screen.dart';
import 'screens/auth/register_pro_client_screen.dart';
import 'screens/auth/register_professional_screen.dart';
import 'screens/auth/pro_client_complete_profile_screen.dart';
import 'screens/professional/professional_nav_screen.dart';
import 'screens/pro_client/pro_client_dashboard_screen.dart';
import 'screens/pro_client/pro_client_create_quotation_screen.dart';
import 'screens/pro_client/pro_client_quotations_screen.dart';
import 'screens/pro_client/pro_client_respond_quotations_screen.dart';
import 'screens/pro_client/professional_profile_screen.dart';
import 'screens/client/client_dashboard_screen.dart';
import 'screens/client/auth/client_sign_in_screen.dart';
import 'screens/client/auth/client_sign_up_screen.dart';
import 'screens/client/client_profile_screen.dart';
import 'screens/client/client_completed_quotations_screen.dart';
import 'screens/client/professional_search_screen.dart';
import 'screens/client/client_quotations_screen.dart';
import 'screens/client/client_favorites_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Création de l'instance d'AuthService avec l'URL de base
  final authService = AuthService(
    baseUrl: AppConfig.baseUrl,
  );

  runApp(
    Provider<AuthService>.value(
      value: authService,
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Batilink Mobile',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Color(0xFF1E3A5F),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding-presentation': (context) => const OnboardingPresentationScreen(),
        '/onboarding-role': (context) => const OnboardingRoleScreen(),
        '/auth-choice': (context) => const OnboardingAuthChoiceScreen(),
        '/login-pro-client': (context) => const LoginProClientScreen(),
        '/login-professional': (context) => const LoginProfessionalScreen(),
        '/register-professional': (context) => const RegisterProfessionalScreen(),
        '/register-pro-client': (context) => const RegisterProClientScreen(),
        '/pro/nav': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ProfessionalNavScreen(
            token: args?['token'] ?? '',
            profile: args?['profile'] ?? <String, dynamic>{},
          );
        },
        '/pro-client/complete-profile': (context) => const ProClientCompleteProfileScreen(),
        '/pro-client/dashboard': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ProClientDashboardScreen(
            token: args?['token'] ?? '',
            userData: args?['userData'] ?? <String, dynamic>{},
            initialTab: args?['initialTab'] ?? 0,
          );
        },
        '/pro-client/create-quotation': (context) => const ProClientCreateQuotationScreen(),
        '/pro-client/quotations': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ProClientQuotationsScreen(
            token: args?['token'],
            userData: args?['userData'],
          );
        },
        '/pro-client/respond-quotations': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ProClientRespondQuotationsScreen(
            token: args?['token'],
            userData: args?['userData'],
            filterMode: args?['filterMode'] ?? 'pending',
          );
        },
        '/pro-client/client-jobs': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ClientQuotationsScreen(
            token: args?['token'] ?? '',
            userData: args?['userData'] ?? <String, dynamic>{},
          );
        },
        '/pro-client/professional-search': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ProfessionalSearchScreen(
            token: args?['token'] ?? '',
            userData: args?['userData'] ?? <String, dynamic>{},
          );
        },
        '/client/professional-search': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ProfessionalSearchScreen(
            token: args?['token'] ?? '',
            userData: args?['userData'] ?? <String, dynamic>{},
          );
        },
        '/pro-client/professional-jobs': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ProClientRespondQuotationsScreen(
            token: args?['token'],
            userData: args?['userData'],
            filterMode: 'active',
          );
        },
        '/pro-client/profile': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ProClientProfileScreen(
            token: args?['token'] ?? '',
            userData: args?['userData'] ?? <String, dynamic>{},
          );
        },
        '/pro-client/professional-profile': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ProfessionalProfileScreen(
            token: args?['token'] ?? '',
            userData: args?['userData'] ?? <String, dynamic>{},
          );
        },
        '/client/login': (context) => const ClientSignInScreen(),
        '/client/register': (context) => const ClientSignUpScreen(),
        '/client/dashboard': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ClientDashboardScreen(
            token: args?['token'] ?? '',
            userData: args?['userData'] ?? <String, dynamic>{},
            profile: {},
          );
        },
        '/client/profile': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ClientProfileScreen(
            token: args?['token'] ?? '',
            userData: args?['userData'] ?? <String, dynamic>{},
          );
        },
        '/client/favorites': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ClientFavoritesScreen(
            token: args?['token'] ?? '',
            userData: args?['userData'] ?? <String, dynamic>{},
          );
        },
        '/client/quotations': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ClientQuotationsScreen(
            token: args?['token'],
            userData: args?['userData'],
          );
        },
        '/client/completed-quotations': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ClientCompletedQuotationsScreen(
            token: args?['token'],
            userData: args?['userData'],
          );
        },
      },
    );
  }
}