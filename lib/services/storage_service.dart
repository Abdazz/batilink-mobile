import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

class StorageService {
  /// Vérifie et demande les permissions nécessaires pour le stockage
  static Future<bool> _checkAndRequestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (status.isGranted) return true;

      final result = await Permission.storage.request();
      return result.isGranted;
    }
    return true;  // iOS ne nécessite pas de permission pour le stockage app-specific
  }

  /// Sauvegarde un fichier dans le stockage public (Downloads sur Android, documents sur iOS)
  /// Retourne le chemin du fichier sauvegardé
  static Future<String> saveFile(List<int> bytes, String fileName, {String? mimeType}) async {
    try {
      // Vérifier les permissions
      final hasPermission = await _checkAndRequestStoragePermission();
      if (!hasPermission) {
        throw Exception('Permission de stockage requise');
      }

      // Déterminer le type MIME si non fourni
      final effectiveMimeType = mimeType ?? lookupMimeType(fileName);
      
      if (Platform.isAndroid) {
        // Sur Android, écrire dans le dossier Download public
        final directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          throw Exception('Dossier de téléchargement non accessible');
        }

        // Créer un nom de fichier unique dans le dossier Download
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final uniqueFileName = '${path.basenameWithoutExtension(fileName)}_$timestamp${path.extension(fileName)}';
        final file = File('${directory.path}/$uniqueFileName');
        
        // Écrire le fichier
        await file.writeAsBytes(bytes);
        return file.path;

      } else {
        // Sur iOS, utiliser le dossier Documents de l'app
        final directory = await getApplicationDocumentsDirectory();
        
        // Créer un sous-dossier pour les documents
        final docsDir = Directory('${directory.path}/Documents');
        if (!await docsDir.exists()) {
          await docsDir.create(recursive: true);
        }

        // Créer un nom de fichier unique
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final uniqueFileName = '${path.basenameWithoutExtension(fileName)}_$timestamp${path.extension(fileName)}';
        final file = File('${docsDir.path}/$uniqueFileName');
        
        // Écrire le fichier
        await file.writeAsBytes(bytes);
        return file.path;
      }
    } catch (e) {
      print('Erreur lors de la sauvegarde du fichier: $e');
      
      // Fallback : sauvegarder dans le cache de l'app
      try {
        final cacheDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final uniqueFileName = '${path.basenameWithoutExtension(fileName)}_$timestamp${path.extension(fileName)}';
        final file = File('${cacheDir.path}/$uniqueFileName');
        await file.writeAsBytes(bytes);
        return file.path;
      } catch (e) {
        throw Exception('Impossible de sauvegarder le fichier : $e');
      }
    }
  }

  /// Déplace un fichier vers le stockage public
  static Future<String> moveToPublicStorage(String sourcePath) async {
    final file = File(sourcePath);
    final bytes = await file.readAsBytes();
    return saveFile(bytes, path.basename(sourcePath));
  }
}