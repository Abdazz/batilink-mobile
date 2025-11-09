import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _fcmTokenKey = 'fcm_token';
  static String? _serverUrl;
  static String? _authToken;

  // Initialisation du service de notifications
  static Future<void> initialize({required String serverUrl, String? authToken}) async {
    _serverUrl = serverUrl;
    _authToken = authToken;

    // Configuration pour Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuration pour iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Gérer le clic sur la notification
        _onNotificationClick(response.payload);
      },
    );

    // Demander les autorisations
    await _requestPermissions();
    
    // Obtenir le token FCM
    await _getFCMToken();

    // Configurer les gestionnaires de messages en arrière-plan
    _setupInteractedMessage();
  }

  static Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    }
  }

  static Future<void> _getFCMToken() async {
    try {
      // Vérifier si on a déjà un token enregistré
      final prefs = await SharedPreferences.getInstance();
      final String? savedToken = prefs.getString(_fcmTokenKey);
      
      if (savedToken == null) {
        // Obtenir un nouveau token
        final String? token = await _firebaseMessaging.getToken();
        if (token != null) {
          await prefs.setString(_fcmTokenKey, token);
          await _sendTokenToServer(token);
        }
      } else {
        // Vérifier si le token a changé
        final String? currentToken = await _firebaseMessaging.getToken();
        if (currentToken != null && currentToken != savedToken) {
          await prefs.setString(_fcmTokenKey, currentToken);
          await _sendTokenToServer(currentToken);
        }
      }
    } catch (e) {
      print('Erreur lors de l\'obtention du token FCM: $e');
    }
  }

  static Future<void> _sendTokenToServer(String token) async {
    if (_serverUrl == null || _authToken == null) return;

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/api/device/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: {
          'token': token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
        },
      );

      if (response.statusCode != 200) {
        print('Erreur lors de l\'envoi du token au serveur: ${response.body}');
      }
    } catch (e) {
      print('Erreur lors de l\'envoi du token au serveur: $e');
    }
  }

  static void _setupInteractedMessage() {
    // Gérer les notifications en arrière-plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // Gérer le clic sur la notification lorsque l'application est en arrière-plan
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _onNotificationClick(message.data['click_action']);
    });
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'batilink_channel',
      'Batilink Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      platformChannelSpecifics,
      payload: message.data['click_action'],
    );
  }

  static void _onNotificationClick(String? payload) {
    // Gérer la navigation en fonction du payload
    if (payload != null) {
      // Implémentez votre logique de navigation ici
      print('Notification cliquée: $payload');
    }
  }

  // Méthode pour mettre à jour le token d'authentification
  static void updateAuthToken(String? authToken) {
    _authToken = authToken;
  }

  // Méthode pour supprimer le token lors de la déconnexion
  static Future<void> deleteToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString(_fcmTokenKey);
      
      if (token != null) {
        await prefs.remove(_fcmTokenKey);
        
        // Informer le serveur de la suppression du token
        if (_serverUrl != null && _authToken != null) {
          await http.delete(
            Uri.parse('$_serverUrl/api/device/unregister'),
            headers: {
              'Authorization': 'Bearer $_authToken',
            },
            body: {
              'token': token,
            },
          );
        }
      }
    } catch (e) {
      print('Erreur lors de la suppression du token FCM: $e');
    }
  }

  // Afficher une notification locale
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'error_channel',
      'Erreurs',
      channelDescription: 'Notifications d\'erreur',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // ID unique
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }
}
