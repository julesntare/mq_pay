import 'dart:async';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'transaction_matcher_service.dart';
import 'notification_service.dart';
import '../services/ussd_record_service.dart';

class SmsListenerService {
  static final SmsQuery _query = SmsQuery();
  static Timer? _pollingTimer;

  /// Initialize SMS listener
  /// Uses polling approach to check for new SMS every 5 seconds
  static Future<bool> initialize() async {
    // Request SMS permissions
    final status = await Permission.sms.request();

    if (!status.isGranted) {
      return false;
    }

    // Start polling for new SMS every 5 seconds
    _startPolling();

    return true;
  }

  /// Start polling for new SMS
  static void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkForNewSms();
    });
  }

  /// Check for new SMS since last check
  static Future<void> _checkForNewSms() async {
    try {
      // Only check if we have pending transactions from today
      final records = await UssdRecordService.getUssdRecords();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final hasPendingToday = records.any((r) =>
        r.status.name == 'pending' &&
        r.timestamp.isAfter(today)
      );

      if (!hasPendingToday) {
        return; // No pending transactions from today, skip SMS check
      }

      // Get recent SMS (last 100 messages to check)
      final messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 20, // Check last 20 messages
      );

      // Filter messages received in last 2 minutes
      final recentMessages = messages.where((msg) {
        if (msg.date == null) return false;
        final msgDate = msg.date!; // Already a DateTime object
        final diff = now.difference(msgDate);
        return diff.inMinutes <= 2;
      }).toList();

      // Process each recent message
      for (final message in recentMessages) {
        await _processSms(message);
      }
    } catch (e) {
      // Silently fail - SMS reading is optional feature
      print('Error checking SMS: $e');
    }
  }

  /// Process a single SMS message
  static Future<void> _processSms(SmsMessage message) async {
    final sender = message.sender ?? '';
    final body = message.body ?? '';

    // Process the SMS and try to match it to a pending transaction
    final matched = await TransactionMatcherService.processSms(body, sender);

    if (matched) {
      // Show notification to user
      await NotificationService.showTransactionStatusNotification();
    }
  }

  /// Check if SMS permissions are granted
  static Future<bool> hasPermissions() async {
    final status = await Permission.sms.status;
    return status.isGranted;
  }

  /// Stop SMS polling
  static void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }
}
