import 'screens/welcome/welcome_screen.dart';
import 'screens/onboarding/onboarding_presentation_screen.dart';
import 'screens/onboarding/onboarding_role_screen.dart';
import 'screens/auth/register_professional_screen.dart';
import 'screens/auth/login_professional_screen.dart';
import 'screens/onboarding/onboarding_auth_choice_screen.dart';
import 'screens/professional/professional_complete_profile_screen.dart';
import 'screens/professional/professional_dashboard_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/professional/professional_nav_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'screens/client/client_dashboard_screen.dart';
import 'screens/client/auth/client_sign_in_screen.dart';
import 'screens/client/auth/client_sign_up_screen.dart';
import 'screens/client/client_profile_screen.dart';
import 'screens/client/client_quotations_screen.dart';
import 'screens/unified_quotation_detail_screen.dart';
import 'screens/client/client_completed_quotations_screen.dart';
import 'constants.dart';
import 'screens/client/client_favorites_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Création de l'instance d'AuthService avec l'URL de base
  final authService = AuthService(
    baseUrl: 'http://10.0.2.2:8000', // URL locale pour développement
  );

  runApp(
    Provider<AuthService>.value(
      value: authService,
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Healthcare - Doctor Consultation App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: primaryColor,
        textTheme: Theme.of(context).textTheme.apply(displayColor: textColor),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: TextButton.styleFrom(
            backgroundColor: primaryColor,
            padding: EdgeInsets.all(defaultPadding),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: textFieldBorder,
          enabledBorder: textFieldBorder,
          focusedBorder: textFieldBorder,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding-presentation': (context) => const OnboardingPresentationScreen(),
        '/onboarding-role': (context) => const OnboardingRoleScreen(),
        '/auth-choice': (context) => const OnboardingAuthChoiceScreen(),
        '/register-professional': (context) => const RegisterProfessionalScreen(),
        '/login-professional': (context) => const LoginProfessionalScreen(),
        '/pro/complete-profile': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ProfessionalCompleteProfileScreen(
            token: args?['token'] ?? '',
            profile: args?['profile'] ?? <String, dynamic>{},
            missingFields: (args?['missingFields'] as List<String>?) ?? const <String>[],
          );
        },
        '/pro/dashboard': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ProfessionalDashboardScreen(
            token: args?['token'] ?? '',
            profile: args?['profile'] ?? <String, dynamic>{},
          );
        },
        '/pro/nav': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ProfessionalNavScreen(
            token: args?['token'] ?? '',
            profile: args?['profile'] ?? <String, dynamic>{},
          );
        },
        '/welcome': (context) => WelcomeScreen(),
        // Routes d'authentification client
        '/client/login': (context) => const ClientSignInScreen(),
        '/client/register': (context) => const ClientSignUpScreen(),

        // Routes principales client
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
      '/client/profile/edit': (context) {
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        return ClientProfileScreen(
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
      '/client/quotation-detail': (context) {
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        return UnifiedQuotationDetailScreen(
          quotationId: args?['quotationId'] ?? '',
          quotation: args?['quotation'] ?? <String, dynamic>{},
          token: args?['token'] ?? '',
          context: args?['context'] ?? QuotationContext.client,
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