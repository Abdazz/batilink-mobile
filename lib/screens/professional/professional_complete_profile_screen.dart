import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'complete_profile_form.dart';
import 'professional_nav_screen.dart';
import '../../services/auth_service.dart';

class ProfessionalCompleteProfileScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> profile;
  final List<String> missingFields;
  
  const ProfessionalCompleteProfileScreen({
    Key? key, 
    required this.token, 
    required this.profile, 
    required this.missingFields,
  }) : super(key: key);

  @override
  State<ProfessionalCompleteProfileScreen> createState() => _ProfessionalCompleteProfileScreenState();
}

class _ProfessionalCompleteProfileScreenState extends State<ProfessionalCompleteProfileScreen> {
  bool _isSubmitting = false;
  final _auth = AuthService(baseUrl: 'http://10.0.2.2:8000');

  Future<void> _submitForm(Map<String, dynamic> formData) async {
    if (!mounted) return;
    
    setState(() => _isSubmitting = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? widget.token;
      
      // Création d'un client HTTP personnalisé qui suit les redirections
      final client = http.Client();
      
      try {
        print('Envoi des données du formulaire...');
        print('URL: http://10.0.2.2:8000/api/professional/profile/complete');
        print('Données: $formData');
        
        final response = await client.post(
          Uri.parse('http://10.0.2.2:8000/api/professional/profile/complete'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(formData),
        );
        
        print('Réponse du serveur: ${response.statusCode}');
        print('Corps de la réponse: ${response.body}');
        
        if (response.statusCode >= 200 && response.statusCode < 300) {
          // Traitement réussi (200-299) ou redirection (300-399)
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profil mis à jour avec succès'),
                backgroundColor: Colors.green,
              ),
            );

            // Récupérer le profil mis à jour du serveur pour s'assurer de la cohérence
            try {
              print('Récupération du profil mis à jour...');
              final updatedProfileResp = await _auth.getProfessionalProfile(accessToken: token);
              if (updatedProfileResp.statusCode == 200) {
                final updatedProfData = jsonDecode(updatedProfileResp.body);
                final updatedProfile = (updatedProfData is Map && updatedProfData['data'] != null) ? updatedProfData['data'] : updatedProfData;
                print('Profil mis à jour récupéré: $updatedProfile');
                print('=== DEBUG - Profil récupéré après mise à jour ===');
                if (updatedProfile is List && updatedProfile.isNotEmpty) {
                  print('Premier élément du profil: ${updatedProfile[0]}');
                  print('profile_completed dans le profil récupéré: ${updatedProfile[0]['profile_completed']}');
                } else if (updatedProfile is Map) {
                  print('profile_completed dans le profil récupéré: ${updatedProfile['profile_completed']}');
                }
                print('===============================================');

                // Fermer tous les écrans et rediriger vers le tableau de bord avec le profil du serveur
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfessionalNavScreen(
                        token: token,
                        profile: updatedProfile,
                      ),
                    ),
                  );
                }
              } else {
                print('Erreur récupération profil mis à jour: ${updatedProfileResp.statusCode}');
                print('Réponse erreur: ${updatedProfileResp.body}');
                // Utiliser les données locales en cas d'erreur
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfessionalNavScreen(
                      token: widget.token,
                      profile: formData,
                    ),
                  ),
                );
              }
            } catch (e) {
              print('Erreur lors de la récupération du profil mis à jour: $e');
              // Utiliser les données locales en cas d'erreur
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfessionalNavScreen(
                    token: widget.token,
                    profile: formData,
                  ),
                ),
              );
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
        title: const Text('Compléter mon profil professionnel'),
        elevation: 0,
      ),
      body: CompleteProfileForm(
        initialData: widget.profile,
        isLoading: _isSubmitting,
        onSubmit: _submitForm,
      ),
    );
  }
}