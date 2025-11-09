import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseMessagingService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Demander les autorisations
    await _requestPermissions();
    
    // Configurer les notifications locales
    await _setupLocalNotifications();
    
    // Configurer les gestionnaires de messages
    await _setupMessageHandlers();
    
    // Obtenir le token FCM
    await _getFCMToken();
  }

  static Future<void> _requestPermissions() async {
    // Pour iOS, demander l'autorisation
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

  static Future<void> _setupLocalNotifications() async {
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
  }

  static Future<void> _setupMessageHandlers() async {
    // Gérer les messages en arrière-plan
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Gérer les messages en premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // Gérer le clic sur une notification lorsque l'app est en arrière-plan
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _onNotificationClick(message.data['click_action']);
    });
  }

  static Future<void> _getFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      print('FCM Token: $token'); // À utiliser pour envoyer des notifications ciblées
      // Ici, vous pouvez envoyer le token à votre backend
    } catch (e) {
      print('Erreur lors de la récupération du token FCM: $e');
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'batilink_channel',
      'Notifications Batilink',
      channelDescription: 'Canal pour les notifications Batilink',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
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
    // Implémentez la navigation en fonction du payload
    if (payload != null) {
      print('Notification cliquée: $payload');
      // Exemple: Navigation vers un écran spécifique
      // Navigator.pushNamed(context, payload);
    }
  }

  // Gestionnaire de messages en arrière-plan
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    await _setupLocalNotifications();
    await _showLocalNotification(message);
  }
}
