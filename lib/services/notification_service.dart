import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Initialize notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// Show notification when transaction status updates
  static Future<void> showTransactionStatusNotification() async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'transaction_status',
      'Transaction Status',
      channelDescription: 'Notifications for transaction status updates',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      0,
      'Transaction Updated',
      'Your transaction status has been updated',
      notificationDetails,
    );
  }

  /// Called when user taps on notification
  static void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap if needed
    // Could navigate to transactions screen
  }
}
