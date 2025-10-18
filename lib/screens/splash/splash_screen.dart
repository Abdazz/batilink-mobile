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
      // D'abord, vérifier le rôle de l'utilisateur
      final userResp = await _auth.getCurrentUser(accessToken: token);
      if (!mounted) return;

      if (userResp.statusCode == 200) {
        final userData = jsonDecode(userResp.body);

        print('=== DEBUG RÉPONSE USER ===');
        print('Réponse brute du serveur: ${userResp.body}');
        print('userData type: ${userData.runtimeType}');
        print('userData keys: ${userData is Map ? userData.keys.toList() : 'Pas un Map'}');

        final user = (userData is Map && userData['user'] != null) ? userData['user'] : userData;

        print('user type: ${user.runtimeType}');
        print('user keys: ${user is Map ? user.keys.toList() : 'Pas un Map'}');
        print('user role: ${user is Map ? user['role'] : 'user pas un Map'}');

        print('=== FIN DEBUG RÉPONSE USER ===');

        print('=== DEBUG SPLASH SCREEN ===');
        print('Utilisateur authentifié: ${user != null}');
        print('Rôle utilisateur: ${user is Map ? user['role'] : 'Non défini'}');

        // Vérifier si l'utilisateur est un professionnel
        if (user is Map && user['role'] == 'professional') {
          print('Utilisateur identifié comme professionnel');

          // Si c'est un professionnel, récupérer son profil
          final profResp = await _auth.getProfessionalProfile(accessToken: token);
          if (!mounted) return;

          if (profResp.statusCode == 200) {
            final profData = jsonDecode(profResp.body);
            final profile = (profData is Map && profData['data'] != null) ? profData['data'] : profData;

            print('Profil professionnel récupéré avec succès');

            // Vérifier si le profil est marqué comme complet par le serveur
            bool isProfileCompleted = false;
            if (profile is List && profile.isNotEmpty && profile[0] is Map) {
              isProfileCompleted = profile[0]['profile_completed'] == true;
              print('profile_completed (depuis liste): ${profile[0]['profile_completed']}');
            } else if (profile is Map) {
              isProfileCompleted = profile['profile_completed'] == true;
              print('profile_completed (depuis map): ${profile['profile_completed']}');
            }

            print('Profil considéré comme complet: $isProfileCompleted');

            if (isProfileCompleted) {
              print('Redirection vers dashboard professionnel (profil complet)');
              Navigator.pushReplacementNamed(
                context,
                '/pro/nav',
                arguments: {
                  'token': token,
                  'profile': profile,
                },
              );
            } else {
              print('Profil incomplet détecté - vérification des champs manquants');
              // Profil non marqué comme complet par le serveur, vérifier les champs manquants
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
                print('Aucun champ manquant mais profil marqué incomplet par serveur');
                print('Redirection vers dashboard professionnel');
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
            print('Erreur récupération profil professionnel: ${profResp.statusCode}');
            Navigator.pushReplacementNamed(context, '/onboarding-presentation');
          }
        } else {
          print('Utilisateur non professionnel - redirection vers dashboard client');
          print('Rôle actuel: ${user is Map ? user['role'] : 'Non défini'}');
          Navigator.pushReplacementNamed(
            context,
            '/client/dashboard',
            arguments: {
              'token': token,
              'userData': user,
            },
          );
        }
      } else {
        print('Erreur récupération informations utilisateur: ${userResp.statusCode}');
        Navigator.pushReplacementNamed(context, '/onboarding-presentation');
      }
    } catch (e) {
      print('Exception lors du bootstrap: $e');
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
