import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';

class BusinessHoursEditScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic>? currentHours;

  const BusinessHoursEditScreen({
    Key? key,
    required this.token,
    this.currentHours,
  }) : super(key: key);

  @override
  State<BusinessHoursEditScreen> createState() => _BusinessHoursEditScreenState();
}

class _BusinessHoursEditScreenState extends State<BusinessHoursEditScreen> {
  final AuthService _authService = AuthService(baseUrl: 'http://10.0.2.2:8000');
  
  // Horaires d'ouverture par défaut (9h-18h du lundi au vendredi)
  final Map<String, Map<String, String>> _businessHours = <String, Map<String, String>>{
    'monday': <String, String>{'open': '09:00', 'close': '18:00'},
    'tuesday': <String, String>{'open': '09:00', 'close': '18:00'},
    'wednesday': <String, String>{'open': '09:00', 'close': '18:00'},
    'thursday': <String, String>{'open': '09:00', 'close': '18:00'},
    'friday': <String, String>{'open': '09:00', 'close': '18:00'},
    'saturday': <String, String>{'open': '', 'close': ''}, // Fermé par défaut
    'sunday': <String, String>{'open': '', 'close': ''}, // Fermé par défaut
  };
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeBusinessHours();
  }

  void _initializeBusinessHours() {
    if (widget.currentHours != null) {
      try {
        Map<String, dynamic> hours;
        if (widget.currentHours is String) {
          hours = json.decode(widget.currentHours as String);
        } else {
          hours = Map<String, dynamic>.from(widget.currentHours!);
        }

        hours.forEach((day, dayHours) {
          if (_businessHours.containsKey(day) && dayHours is Map) {
            _businessHours[day]!['open'] = dayHours['open']?.toString() ?? '';
            _businessHours[day]!['close'] = dayHours['close']?.toString() ?? '';
          }
        });
      } catch (e) {
        print('Erreur lors de l\'initialisation des horaires: $e');
      }
    }
  }

  void _updateBusinessHours(String day, String type, String value) {
    setState(() {
      _businessHours[day]![type] = value;
    });
  }

  String _getBusinessHoursJson() {
    // Convertir le Map en chaîne JSON avec les noms de jours en anglais
    final Map<String, dynamic> formattedHours = {};
    _businessHours.forEach((day, hours) {
      formattedHours[day] = {
        'open': hours['open'],
        'close': hours['close'],
      };
    });
    return jsonEncode(formattedHours);
  }

  Future<void> _saveBusinessHours() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? widget.token;

      // DEBUG: Afficher les données envoyées
      print('=== DEBUG HORAIRES ===');
      print('Horaires JSON: ${_getBusinessHoursJson()}');
      print('======================');

      // Récupérer le profil actuel pour obtenir l'ID
      final profileResponse = await _authService.getProfessionalProfile(accessToken: token);

      if (profileResponse.statusCode == 200) {
        final profileData = json.decode(profileResponse.body);

        print('=== DEBUG PROFILE DATA ===');
        print('Profile data type: ${profileData.runtimeType}');
        print('Profile data: $profileData');
        print('Profile data[data] type: ${profileData['data']?.runtimeType}');
        print('Profile data[data] content: ${profileData['data']}');
        print('============================');

        final profile = profileData['data']?['data'];

        print('Profile type after extraction: ${profile.runtimeType}');
        print('Profile content: $profile');

        // Récupérer l'ID du profil pour la mise à jour
        String? profileId;

        if (profile is List && profile.isNotEmpty) {
          // Structure: data.data est un tableau
          print('Profile is List - accessing first element');
          final firstProfile = profile[0];
          print('First profile type: ${firstProfile.runtimeType}');
          print('First profile content: $firstProfile');

          if (firstProfile is Map<String, dynamic>) {
            profileId = firstProfile['id']?.toString();
            print('Profile ID from list: $profileId');
          }
        } else if (profile is Map<String, dynamic>) {
          // Structure directe: data est directement le profil
          print('Profile is Map directly');
          profileId = profile['id']?.toString();
          print('Profile ID from map: $profileId');
        }

        print('=== DEBUG PROFIL ID ===');
        print('Final Profile ID: $profileId');
        print('=========================');

        // Préparer les données pour la mise à jour
        Map<String, dynamic> profileDataMap;

        if (profile is List && profile.isNotEmpty) {
          // Structure: data.data est un tableau - utiliser le profil CNSS
          final cnssProfile = profile.firstWhere(
            (p) => p is Map<String, dynamic> && p['company_name'] == 'CNSS',
            orElse: () => profile[0], // Fallback au premier profil si CNSS n'est pas trouvé
          );
          profileDataMap = Map<String, dynamic>.from(cnssProfile);
        } else if (profile is Map<String, dynamic>) {
          // Structure directe: data est directement le profil
          profileDataMap = Map<String, dynamic>.from(profile);
        } else {
          throw Exception('Format de profil invalide');
        }

        // S'assurer que les champs requis sont présents
        if (!profileDataMap.containsKey('rccm_number') || profileDataMap['rccm_number'] == null) {
          profileDataMap['rccm_number'] = 'RCCM${DateTime.now().millisecondsSinceEpoch}';
        }
        if (!profileDataMap.containsKey('id_document_path') || profileDataMap['id_document_path'] == null) {
          profileDataMap['id_document_path'] = '/storage/documents/default/id_document.pdf';
        }

        print('=== DEBUG PROFILE DATA MAP ===');
        print('Selected profile company: ${profileDataMap['company_name']}');
        print('Profile data map keys: ${profileDataMap.keys.toList()}');
        print('Profile data map ID: ${profileDataMap['id']}');
        print('==============================');

        if (profileId == null || profileId.isEmpty) {
          throw Exception('ID du profil non trouvé');
        }

        // Utiliser completeProfessionalProfile au lieu de updateProfessionalProfile
        // car l'API ne supporte que cette méthode pour les mises à jour
        profileDataMap['business_hours'] = _getBusinessHoursJson();

        print('=== DEBUG PROFIL COMPLET ===');
        print('Profile ID: $profileId');
        print('Données envoyées: $profileDataMap');
        print('=============================');

        // Envoyer les données mises à jour via completeProfessionalProfile
        final response = await _authService.completeProfessionalProfile(
          accessToken: token,
          payload: profileDataMap,
        );

        print('=== RÉPONSE PUT ===');
        print('Status Code: ${response.statusCode}');
        print('Body: ${response.body}');
        print('===================');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Horaires mis à jour avec succès'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true);
          }
        } else {
          _handleErrorResponse(response);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _handleErrorResponse(http.Response response) {
    if (response.statusCode == 422) {
      try {
        final errorData = json.decode(response.body);
        String errorMessage = 'Erreur de validation';

        if (errorData['message'] != null) {
          errorMessage = errorData['message'].toString();
        } else if (errorData['errors'] != null) {
          final errors = errorData['errors'] as Map<String, dynamic>;
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            errorMessage = firstError.first.toString();
          } else if (firstError is String) {
            errorMessage = firstError;
          }
        }

        throw Exception('Erreur de validation: $errorMessage');
      } catch (e) {
        throw Exception('Erreur serveur 422: ${response.body}');
      }
    } else {
      throw Exception('Erreur serveur: ${response.statusCode} - ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4CAF50)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Horaires de disponibilité',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveBusinessHours,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Sauvegarder',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF4CAF50),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Définissez vos horaires de disponibilité pour chaque jour de la semaine. Laissez vide pour un jour fermé.',
                      style: GoogleFonts.poppins(
                        color: Colors.blue[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Liste des horaires
            ..._buildBusinessHoursList(),
            
            const SizedBox(height: 32),
            
            // Bouton de sauvegarde
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveBusinessHours,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Sauvegarder les horaires',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBusinessHoursList() {
    final dayNames = {
      'monday': 'Lundi',
      'tuesday': 'Mardi',
      'wednesday': 'Mercredi',
      'thursday': 'Jeudi',
      'friday': 'Vendredi',
      'saturday': 'Samedi',
      'sunday': 'Dimanche',
    };

    return _businessHours.entries.map((entry) {
      final String day = entry.key;
      final String dayDisplayName = dayNames[day] ?? day;
      final String openTime = entry.value['open'] ?? '';
      final String closeTime = entry.value['close'] ?? '';
      final bool isOpen = openTime.isNotEmpty && closeTime.isNotEmpty;
      
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  dayDisplayName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: isOpen,
                  onChanged: (bool value) {
                    if (value) {
                      _updateBusinessHours(day, 'open', '09:00');
                      _updateBusinessHours(day, 'close', '18:00');
                    } else {
                      _updateBusinessHours(day, 'open', '');
                      _updateBusinessHours(day, 'close', '');
                    }
                  },
                  activeColor: const Color(0xFF4CAF50),
                ),
              ],
            ),
            
            if (isOpen) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final TimeOfDay? time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: int.parse(openTime.split(':')[0]),
                            minute: int.parse(openTime.split(':')[1]),
                          ),
                        );
                        if (time != null) {
                          _updateBusinessHours(
                            day,
                            'open',
                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                          );
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Ouverture',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.access_time, size: 20),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        child: Text(openTime),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final TimeOfDay? time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: int.parse(closeTime.split(':')[0]),
                            minute: int.parse(closeTime.split(':')[1]),
                          ),
                        );
                        if (time != null) {
                          _updateBusinessHours(
                            day,
                            'close',
                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                          );
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fermeture',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.access_time, size: 20),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        child: Text(closeTime),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.close, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Fermé',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }
}
