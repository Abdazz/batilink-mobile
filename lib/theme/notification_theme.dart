import 'package:flutter/material.dart';

class NotificationTheme {
  // Couleurs des notifications par type
  static const Map<String, Color> notificationColors = {
    'profile_update': Colors.blue,
    'email_change': Colors.orange,
    'phone_change': Colors.orange,
    'pro_account_approved': Colors.green,
    'pro_account_activated': Colors.green,
    'favorite_added': Colors.pink,
    'favorite_removed': Colors.grey,
    'quotation_created': Colors.blueAccent,
    'quotation_received': Colors.blueGrey,
    'quotation_accepted': Colors.green,
    'work_started': Colors.teal,
    'work_completed': Colors.purple,
    'quotation_cancelled': Colors.red,
    'default': Colors.blue,
  };

  // Icônes des notifications par type
  static const Map<String, IconData> notificationIcons = {
    'profile_update': Icons.person_outline,
    'email_change': Icons.email_outlined,
    'phone_change': Icons.phone_outlined,
    'pro_account_approved': Icons.verified_user_outlined,
    'pro_account_activated': Icons.check_circle_outline,
    'favorite_added': Icons.favorite_border,
    'favorite_removed': Icons.favorite_border,
    'quotation_created': Icons.description_outlined,
    'quotation_received': Icons.email_outlined,
    'quotation_accepted': Icons.thumb_up_outlined,
    'work_started': Icons.build_outlined,
    'work_completed': Icons.assignment_turned_in_outlined,
    'quotation_cancelled': Icons.cancel_outlined,
    'default': Icons.notifications_none,
  };

  // Titres par défaut des notifications
  static const Map<String, String> notificationTitles = {
    'profile_update': 'Mise à jour du profil',
    'email_change': 'Email modifié',
    'phone_change': 'Téléphone modifié',
    'pro_account_approved': 'Compte professionnel approuvé',
    'pro_account_activated': 'Compte professionnel activé',
    'favorite_added': 'Favori ajouté',
    'favorite_removed': 'Favori retiré',
    'quotation_created': 'Nouvelle demande de devis',
    'quotation_received': 'Devis reçu',
    'quotation_accepted': 'Devis accepté',
    'work_started': 'Travaux commencés',
    'work_completed': 'Travaux terminés',
    'quotation_cancelled': 'Devis annulé',
    'default': 'Nouvelle notification',
  };

  // Récupère la couleur associée à un type de notification
  static Color getColorForType(String type) {
    return notificationColors[type] ?? notificationColors['default']!;
  }

  // Récupère l'icône associée à un type de notification
  static IconData getIconForType(String type) {
    return notificationIcons[type] ?? notificationIcons['default']!;
  }

  // Récupère le titre associé à un type de notification
  static String getTitleForType(String type) {
    return notificationTitles[type] ?? notificationTitles['default']!;
  }
}
