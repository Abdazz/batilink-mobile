class NotificationModel {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? data;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.data,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: _parseNotificationType(json['type'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'data': data,
    };
  }

  static NotificationType _parseNotificationType(String type) {
    switch (type) {
      case 'profile_update':
        return NotificationType.profileUpdate;
      case 'email_change':
        return NotificationType.emailChange;
      case 'phone_change':
        return NotificationType.phoneChange;
      case 'pro_account_approved':
        return NotificationType.proAccountApproved;
      case 'pro_account_activated':
        return NotificationType.proAccountActivated;
      case 'favorite_added':
        return NotificationType.favoriteAdded;
      case 'favorite_removed':
        return NotificationType.favoriteRemoved;
      case 'quotation_created':
        return NotificationType.quotationCreated;
      case 'quotation_received':
        return NotificationType.quotationReceived;
      case 'quotation_accepted':
        return NotificationType.quotationAccepted;
      case 'work_started':
        return NotificationType.workStarted;
      case 'work_completed':
        return NotificationType.workCompleted;
      case 'quotation_cancelled':
        return NotificationType.quotationCancelled;
      default:
        return NotificationType.generic;
    }
  }

  String get navigationPath {
    switch (type) {
      case NotificationType.quotationCreated:
      case NotificationType.quotationReceived:
      case NotificationType.quotationAccepted:
      case NotificationType.workStarted:
      case NotificationType.workCompleted:
      case NotificationType.quotationCancelled:
        return '/quotation/${data?['quotationId']}';
      case NotificationType.proAccountApproved:
      case NotificationType.proAccountActivated:
        return '/pro/dashboard';
      case NotificationType.favoriteAdded:
      case NotificationType.favoriteRemoved:
        return '/favorites';
      case NotificationType.profileUpdate:
      case NotificationType.emailChange:
      case NotificationType.phoneChange:
      default:
        return '/notifications';
    }
  }
}

enum NotificationType {
  // Profile updates
  profileUpdate,
  emailChange,
  phoneChange,
  
  // Professional account
  proAccountApproved,
  proAccountActivated,
  
  // Favorites
  favoriteAdded,
  favoriteRemoved,
  
  // Quotations
  quotationCreated,
  quotationReceived,
  quotationAccepted,
  workStarted,
  workCompleted,
  quotationCancelled,
  
  // Generic
  generic,
}
