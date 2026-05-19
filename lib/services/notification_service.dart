import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/ussd_record.dart';
import '../models/transaction_status.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

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

  /// Show a transaction-specific notification with amount, recipient, and status.
  static Future<void> showTransactionNotification(UssdRecord record) async {
    await initialize();

    final isSuccess = record.status == TransactionStatus.success;
    final amountStr = _formatAmount(record.amount);
    final recipient = record.contactName ??
        record.maskedRecipient ??
        record.recipient;

    final title = isSuccess ? 'Payment confirmed' : 'Payment failed';
    final body = isSuccess
        ? '$amountStr sent to $recipient'
        : '$amountStr to $recipient was not processed';

    const androidDetails = AndroidNotificationDetails(
      'transaction_status',
      'Transaction Status',
      channelDescription: 'Notifications for transaction status updates',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notifications.show(
      record.id.hashCode,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Generic fallback used when multiple transactions are resolved in bulk
  /// (e.g. after a retry scan on app resume).
  static Future<void> showTransactionStatusNotification() async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'transaction_status',
      'Transaction Status',
      channelDescription: 'Notifications for transaction status updates',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notifications.show(
      0,
      'Transactions updated',
      'One or more pending payments were resolved',
      const NotificationDetails(android: androidDetails),
    );
  }

  static String _formatAmount(double amount) {
    final s = amount.toStringAsFixed(0);
    final formatted = s.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return '$formatted RWF';
  }

  static void _onNotificationTapped(NotificationResponse response) {}
}
