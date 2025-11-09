import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import '../core/app_config.dart';
import '../models/document.dart';
import '../services/storage_service.dart';

class DocumentService {
  final String token;

  // Définition des types MIME acceptés par type de document
  // Types MIME acceptés par type de document (public pour l'interface utilisateur)
  static const Map<String, List<String>> allowedMimeTypes = {
    'id_document': ['application/pdf', 'image/jpeg', 'image/png'],
    'rccm': ['application/pdf'],
    'license': ['application/pdf'],
    'insurance': ['application/pdf'],
    'other': ['application/pdf', 'image/jpeg', 'image/png'],
  };

  // Extensions autorisées par type de document (public pour l'interface utilisateur)
  static const Map<String, List<String>> allowedExtensions = {
    'id_document': ['.pdf', '.jpg', '.jpeg', '.png'],
    'rccm': ['.pdf'],
    'license': ['.pdf'],
    'insurance': ['.pdf'],
    'other': ['.pdf', '.jpg', '.jpeg', '.png'],
  };

  DocumentService(this.token);

  /// Valide le type MIME et l'extension d'un fichier
  Future<void> validateFileType(File file, String documentType) async {
    final String ext = path.extension(file.path).toLowerCase();
    final String? mimeType = lookupMimeType(file.path);

    // Vérifier les extensions autorisées
    final allowedExts = allowedExtensions[documentType] ?? allowedExtensions['other']!;
    if (!allowedExts.contains(ext)) {
      throw Exception(
        'Extension de fichier non autorisée.\nExtensions acceptées : ${allowedExts.join(", ")}'
      );
    }

    // Vérifier le type MIME
    final allowedMimes = allowedMimeTypes[documentType] ?? allowedMimeTypes['other']!;
    if (mimeType == null || !allowedMimes.contains(mimeType)) {
      throw Exception(
        'Type de fichier non autorisé.\nTypes acceptés : ${allowedMimes.join(", ")}'
      );
    }

    // Vérifier la taille (max 5MB)
    final fileSize = await file.length();
    if (fileSize > 5 * 1024 * 1024) {
      throw Exception('La taille du fichier ne doit pas dépasser 5MB');
    }
  }

  // Télécharger un document
  Future<Document> uploadDocument(File file, String documentType, {String? documentId}) async {
    try {
      // Validation du type de fichier
      await validateFileType(file, documentType);

      final uri = Uri.parse('${AppConfig.baseUrl}/api/documents/upload');
      final request = http.MultipartRequest('POST', uri);

      // Ajout des headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Champs du formulaire
      request.fields['type'] = documentType;
      if (documentId != null) request.fields['document_id'] = documentId;

      // Fichier
      final fileName = path.basename(file.path);
      final stream = http.ByteStream(Stream.castFrom(file.openRead()));
      final length = await file.length();
      final multipartFile = http.MultipartFile('file', stream, length, filename: fileName);
      request.files.add(multipartFile);

      // Envoi
      final streamedResponse = await request.send();
      final responseData = await streamedResponse.stream.bytesToString();
      // Debug
      // ignore: avoid_print
      print('Document upload response status: ${streamedResponse.statusCode}');
      // ignore: avoid_print
      print('Document upload response body: $responseData');

      // Accept both 200 and 201 as success
      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        // Try to decode JSON
        Map<String, dynamic>? jsonData;
        try {
          final decoded = json.decode(responseData);
          if (decoded is Map<String, dynamic>) jsonData = decoded;
        } catch (e) {
          // not JSON
          throw Exception('Upload succeeded but response is not JSON: $e');
        }

        if (jsonData == null) throw Exception('Réponse inattendue du serveur lors du téléchargement');

        // Support different shapes: flat or {success:..., path:..., document_id:...} or {data: {...}}
        Map<String, dynamic> data = jsonData;
        if (jsonData.containsKey('data') && jsonData['data'] is Map<String, dynamic>) {
          data = Map<String, dynamic>.from(jsonData['data']);
        }

        // Map fields
        final id = data['document_id'] ?? data['id'] ?? '';
        final name = data['name'] ?? fileName;
        final url = data['url'] ?? (data['path'] != null ? '${AppConfig.baseUrl}/storage/${data['path']}' : '');
        final type = data['type'] ?? documentType;
        final pathStr = data['path'] ?? data['file_path'] ?? '';

        return Document(
          id: id.toString(),
          name: name.toString(),
          url: url.toString(),
          type: type.toString(),
          uploadedAt: DateTime.now(),
          filePath: pathStr.toString(),
          size: data['size'] is int ? data['size'] as int : null,
          mimeType: data['mime_type']?.toString(),
        );
      }

      // If not successful, try parse error message
      try {
        final err = json.decode(responseData);
        throw Exception('Erreur lors du téléchargement: ${err['message'] ?? err}');
      } catch (_) {
        throw Exception('Erreur lors du téléchargement: HTTP ${streamedResponse.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur lors du téléchargement: $e');
    }
  }

  // Mettre à jour le profil avec les documents
  Future<bool> updateProfileDocuments(List<Document> documents, List<Document> deletedDocuments) async {
    try {
      var uri = Uri.parse('${AppConfig.baseUrl}/api/pro-client/professional-profile');
      
      final documentsData = documents.map((doc) => {
        'id': doc.id,
        'name': doc.name,
        'type': doc.type,
        'path': doc.filePath,
        'url': doc.url,
        'size': 0, // À implémenter si nécessaire
        'mime_type': 'application/pdf', // À adapter selon le type de fichier
        'uploaded_at': doc.uploadedAt.toIso8601String(),
      }).toList();

      final deletedDocumentsData = deletedDocuments.map((doc) => {
        'id': doc.id,
        'path': doc.filePath,
        'type': doc.type,
      }).toList();

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'documents': documentsData,
          'deleted_documents': deletedDocumentsData,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Erreur lors de la mise à jour: ${json.decode(response.body)['message'] ?? 'Erreur inconnue'}');
      }
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour: $e');
    }
  }

  /// Télécharge un document à partir de son URL et le sauvegarde dans le stockage public
  Future<String> downloadDocument(String url, {String? name, String? mimeType}) async {
    try {
      // Faire la requête HTTP
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur lors du téléchargement: HTTP ${response.statusCode}');
      }

      // Déterminer le nom du fichier
      String fileName = name ?? url.split('/').last;
      if (path.extension(fileName).isEmpty) {
        // Si pas d'extension, essayer de la deviner à partir du Content-Type
        final contentType = response.headers['content-type'];
        if (contentType != null) {
          switch (contentType) {
            case 'application/pdf':
              fileName = '$fileName.pdf';
              break;
            case 'image/jpeg':
              fileName = '$fileName.jpg';
              break;
            case 'image/png':
              fileName = '$fileName.png';
              break;
          }
        }
      }

      // Sauvegarder avec le StorageService
      return StorageService.saveFile(
        response.bodyBytes, 
        fileName,
        mimeType: mimeType ?? response.headers['content-type'],
      );

    } catch (e) {
      throw Exception('Erreur lors du téléchargement: $e');
    }
  }

  // Supprimer un document
  Future<bool> deleteDocument(String documentPath) async {
    try {
      var uri = Uri.parse('${AppConfig.baseUrl}/api/documents/delete');
      
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'path': documentPath,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Erreur lors de la suppression: ${json.decode(response.body)['message'] ?? 'Erreur inconnue'}');
      }
    } catch (e) {
      throw Exception('Erreur lors de la suppression: $e');
    }
  }
}