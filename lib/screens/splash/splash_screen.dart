import 'dart:convert';
import 'package:flutter/material.dart';

import '../../services/session_service.dart';
import '../../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _session = SessionService();
  final _auth = AuthService(baseUrl: 'http://10.0.2.2:8000');

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(milliseconds: 400));
    final token = await _session.getToken();
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      Navigator.pushReplacementNamed(context, '/onboarding-presentation');
      return;
    }

    try {
      final profResp = await _auth.getProfessionalProfile(accessToken: token);
      if (!mounted) return;
      if (profResp.statusCode == 200) {
        final profData = jsonDecode(profResp.body);
        final profile = (profData is Map && profData['data'] != null) ? profData['data'] : profData;

        // Logs de débogage pour voir les données du profil
        print('=== DEBUG SPLASH SCREEN ===');
        print('Données du profil reçues: $profile');
        print('Statut profile_completed: ${profile['profile_completed']}');
        if (profile is Map) {
          print('Type de données du profil: Map');
          print('Clés disponibles: ${profile.keys.toList()}');
        } else if (profile is List) {
          print('Type de données du profil: List');
          if (profile.isNotEmpty) {
            print('Premier élément: ${profile[0]}');
            if (profile[0] is Map) {
              print('Clés du premier élément: ${(profile[0] as Map).keys.toList()}');
              print('profile_completed du premier élément: ${(profile[0] as Map)['profile_completed']}');
            }
          }
        }
        print('===========================');

        // Vérifier si le profil est marqué comme complet par le serveur
        bool isProfileCompleted = false;
        if (profile is List && profile.isNotEmpty && profile[0] is Map) {
          isProfileCompleted = profile[0]['profile_completed'] == true;
        } else if (profile is Map) {
          isProfileCompleted = profile['profile_completed'] == true;
        }

        if (isProfileCompleted) {
          print('Profil marqué comme complet par le serveur, redirection vers dashboard');
          Navigator.pushReplacementNamed(
            context,
            '/pro/nav',
            arguments: {
              'token': token,
              'profile': profile,
            },
          );
        } else {
          print('Profil non marqué comme complet par le serveur, vérification des champs manquants');
          // Vérifier les champs manquants uniquement si le profil n'est pas marqué comme complet
          bool isEmptyStr(v) => v == null || (v is String && v.trim().isEmpty);
          final missing = <String>[];

          // Gérer les deux formats de données du profil
          Map<String, dynamic> profileData;
          if (profile is List && profile.isNotEmpty) {
            profileData = profile[0] as Map<String, dynamic>;
          } else if (profile is Map) {
            profileData = profile as Map<String, dynamic>;
          } else {
            profileData = {};
          }

          if (isEmptyStr(profileData['company_name'])) missing.add('company_name');
          if (isEmptyStr(profileData['job_title'])) missing.add('job_title');
          if (isEmptyStr(profileData['address'])) missing.add('address');
          if (isEmptyStr(profileData['city'])) missing.add('city');
          if (isEmptyStr(profileData['postal_code'])) missing.add('postal_code');

          print('Champs manquants trouvés: $missing');

          if (missing.isNotEmpty) {
            print('Redirection vers écran de complétion avec champs manquants');
            Navigator.pushReplacementNamed(
              context,
              '/pro/complete-profile',
              arguments: {
                'token': token,
                'profile': profile,
                'missingFields': missing,
              },
            );
          } else {
            print('Aucun champ manquant mais profil non marqué complet par serveur, redirection vers dashboard');
            // Si aucun champ n'est manquant mais que le profil n'est pas marqué comme complet
            // On considère le profil comme complet et on redirige vers le tableau de bord
            Navigator.pushReplacementNamed(
              context,
              '/pro/nav',
              arguments: {
                'token': token,
                'profile': profile,
              },
            );
          }
        }
      } else {
        Navigator.pushReplacementNamed(context, '/onboarding-presentation');
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/onboarding-presentation');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
