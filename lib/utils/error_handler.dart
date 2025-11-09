import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:batilink_mobile_app/services/notification_service.dart';

class ErrorHandler {
  // Gestion générique des erreurs réseau
  static Future<void> handleNetworkError(
    dynamic error, 
    StackTrace stackTrace, {
    String? customMessage,
    bool showNotification = true,
  }) async {
    String errorMessage = customMessage ?? 'Une erreur est survenue';
    
    if (error is SocketException) {
      errorMessage = 'Problème de connexion. Vérifiez votre connexion Internet.';
    } else if (error is TimeoutException) {
      errorMessage = 'La connexion a expiré. Veuillez réessayer.';
    } else if (error is http.ClientException) {
      errorMessage = 'Erreur de communication avec le serveur.';
    }

    debugPrint('Erreur réseau: $error');
    debugPrint('Stack trace: $stackTrace');

    if (showNotification) {
      await NotificationService.showNotification(
        title: 'Erreur',
        body: errorMessage,
        payload: 'error',
      );
    }
  }

  // Vérifier la connexion Internet
  static Future<bool> checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      await NotificationService.showNotification(
        title: 'Hors ligne',
        body: 'Vérifiez votre connexion Internet',
        payload: 'offline',
      );
      return false;
    }
    return false;
  }
}
