import 'package:batilink_mobile_app/screens/professional/complete_profile_form.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';

class ProClientCompleteProfileScreen extends StatefulWidget {
  const ProClientCompleteProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProClientCompleteProfileScreen> createState() => _ProClientCompleteProfileScreenState();
}

class _ProClientCompleteProfileScreenState extends State<ProClientCompleteProfileScreen> {
  bool _isSubmitting = false;
  final _auth = AuthService(baseUrl: 'http://10.0.2.2:8000');

  Future<void> _submitForm(Map<String, dynamic> formData) async {
    if (!mounted) return;

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Token non trouvé');
      }

      // Création d'un client HTTP personnalisé qui suit les redirections
      final client = http.Client();

      try {
        print('Envoi des données du formulaire pro-client...');
        print('URL: http://10.0.2.2:8000/api/pro-client/profile/complete');
        print('Données: $formData');

        final response = await client.post(
          Uri.parse('http://10.0.2.2:8000/api/professional/profile/complete'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({...formData, 'role': 'pro_client'}),
        );

        print('Réponse: ${response.statusCode}');
        print('Corps: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
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
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? 'Erreur lors de la mise à jour du profil: ${response.statusCode}');
        }
      } finally {
        client.close();
      }
    } on FormatException catch (e) {
      print('Erreur de format: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur de format des données. Veuillez réessayer.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on http.ClientException catch (e) {
      print('Erreur de connexion: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
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
