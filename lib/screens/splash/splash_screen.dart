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
        bool isEmptyStr(v) => v == null || (v is String && v.trim().isEmpty);
        final missing = <String>[];
        if (isEmptyStr(profile['company_name'])) missing.add('company_name');
        if (isEmptyStr(profile['job_title'])) missing.add('job_title');
        if (isEmptyStr(profile['address'])) missing.add('address');
        if (isEmptyStr(profile['city'])) missing.add('city');
        if (isEmptyStr(profile['postal_code'])) missing.add('postal_code');

        if (missing.isNotEmpty) {
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
          Navigator.pushReplacementNamed(
            context,
            '/pro/nav',
            arguments: {
              'token': token,
              'profile': profile,
            },
          );
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
