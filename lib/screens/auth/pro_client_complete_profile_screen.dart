import 'package:batilink_mobile_app/screens/professional/complete_profile_form.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../core/app_config.dart';

class ProClientCompleteProfileScreen extends StatefulWidget {
  const ProClientCompleteProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProClientCompleteProfileScreen> createState() => _ProClientCompleteProfileScreenState();
}

class _ProClientCompleteProfileScreenState extends State<ProClientCompleteProfileScreen> {
  bool _isSubmitting = false;
  final _auth = AuthService(baseUrl: AppConfig.baseUrl);

  Future<void> _submitForm(Map<String, dynamic> formData) async {
    if (!mounted) return;

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Token non trouvé');
      }

      print('Envoi des données du formulaire pro-client...');
      print('URL: ${AppConfig.baseUrl}/api/professional/profile/complete');
      print('Données: $formData');

      final response = await ApiService.post(
        'professional/profile/complete',
        data: {...formData, 'role': 'pro_client'},
      );

      print('Réponse: $response');

      if (response != null) {
        // Récupérer le profil mis à jour
        try {
          print('Récupération du profil mis à jour...');
          final updatedProfileResp = await _auth.getProClientProfile(accessToken: token);
          if (updatedProfileResp.statusCode == 200) {
            final updatedProfile = await _auth.parseProClientProfileResponse(updatedProfileResp);
            print('Profil pro-client mis à jour récupéré: $updatedProfile');

            if (mounted) {
              // Aller au dashboard pro-client
              Navigator.pushReplacementNamed(context, '/pro-client/dashboard', arguments: {
                'token': token,
                'profile': updatedProfile ?? formData,
              });
            }
          } else {
            print('Erreur récupération profil mis à jour: ${updatedProfileResp.statusCode}');
            // Aller au dashboard avec les données locales
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/pro-client/dashboard', arguments: {
                'token': token,
                'profile': formData,
              });
            }
          }
        } catch (e) {
          print('Erreur lors de la récupération du profil mis à jour: $e');
          // Aller au dashboard avec les données locales en cas d'erreur
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/pro-client/dashboard', arguments: {
              'token': token,
              'profile': formData,
            });
          }
        }
      } else {
        // Gestion des erreurs côté serveur
        throw Exception('Erreur lors de la mise à jour du profil');
      }
    } catch (e) {
      print('Erreur inattendue: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compléter mon profil Pro-Client'),
        elevation: 0,
      ),
      body: CompleteProfileForm(
        initialData: const {},
        isLoading: _isSubmitting,
        onSubmit: _submitForm,
      ),
    );
  }
}
