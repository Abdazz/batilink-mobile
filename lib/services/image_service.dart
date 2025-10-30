import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../core/app_config.dart';

class ImageService {
  static Future<String> uploadImage(File imageFile, String type, String token) async {
    try {
      // Créer la requête multipart
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/api/upload'),
      );

      // Ajouter le token d'authentification
      request.headers['Authorization'] = 'Bearer $token';
      
      // Obtenir le type MIME du fichier
      final mimeType = lookupMimeType(imageFile.path);
      final mimeTypeData = mimeType?.split('/');
      
      // Ajouter le fichier à la requête
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType(mimeTypeData?[0] ?? 'image', mimeTypeData?[1] ?? 'jpeg'),
        ),
      );

      // Ajouter les champs supplémentaires
      request.fields['type'] = type;

      // Envoyer la requête
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['url'] ?? '';
      } else {
        throw Exception('Échec du téléchargement de l\'image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur lors du téléchargement de l\'image: $e');
    }
  }

  // Méthode pour formater l'URL de l'image
  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '';
    }
    
    // Si l'URL est déjà complète, la retourner telle quelle
    if (imagePath.startsWith('http')) {
      return imagePath;
    }
    
    // Sinon, construire l'URL complète
    return '${AppConfig.baseUrl}${imagePath.startsWith('/') ? '' : '/'}$imagePath';
  }
}
