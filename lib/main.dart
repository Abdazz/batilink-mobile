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
import 'screens/client/client_dashboard_screen.dart';
import 'package:flutter/material.dart';

import 'constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
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
        '/client/dashboard': (context) {
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        return ClientDashboardScreen(
          token: args?['token'] ?? '',
          userData: args?['userData'] ?? <String, dynamic>{}, profile: {},
        );
      },
      },
    );
  }
}