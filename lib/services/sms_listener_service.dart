import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'transaction_matcher_service.dart';
import 'sms_parser_service.dart';
import 'notification_service.dart';
import '../services/ussd_record_service.dart';

class SmsListenerService {
  static final SmsQuery _query = SmsQuery();
  static Timer? _pollingTimer;

  /// Timestamp of the last completed SMS poll cycle.
  /// Used to avoid reprocessing the same messages on every tick.
  static DateTime? _lastSmsCheckTime;

  static Future<bool> initialize() async {
    final status = await Permission.sms.request();
    if (!status.isGranted) return false;
    _startPolling();
    return true;
  }

  static void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkForNewSms();
    });
  }

  static Future<void> _checkForNewSms() async {
    try {
      final records = await UssdRecordService.getUssdRecords();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final hasPending = records.any((r) =>
        r.status.name == 'pending' && r.timestamp.isAfter(today));
      if (!hasPending) {
        _lastSmsCheckTime = now;
        return;
      }

      // Only examine SMS that arrived since the previous check.
      // On the very first run, look back 5 minutes to catch any SMS that
      // arrived while the app was starting up.
      final checkFrom = _lastSmsCheckTime ??
          now.subtract(const Duration(minutes: 5));

      final messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 20,
      );

      final newMessages = messages.where((msg) =>
        msg.date != null && msg.date!.isAfter(checkFrom),
      ).toList();

      for (final message in newMessages) {
        await _processSms(message);
      }

      _lastSmsCheckTime = now;
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking SMS: $e');
    }
  }

  static Future<void> _processSms(SmsMessage message) async {
    final sender = message.sender ?? '';
    final body = message.body ?? '';

    final matched = await TransactionMatcherService.processSms(body, sender);
    if (matched != null) {
      await NotificationService.showTransactionNotification(matched);
    }
  }

  static Future<bool> hasPermissions() async {
    return (await Permission.sms.status).isGranted;
  }

  static void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Scan stored SMS and resolve all pending transactions from the last 24 h.
  ///
  /// This is called on app start and every time the app returns to the
  /// foreground, so it catches SMS that arrived while the app was backgrounded
  /// or killed — regardless of how long that was.
  static Future<int> retryPendingTransactionMatching() async {
    try {
      final records = await UssdRecordService.getUssdRecords();
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(hours: 24));

      final pendingRecent = records.where((r) =>
        r.status.name == 'pending' && r.timestamp.isAfter(cutoff),
      ).toList();

      if (pendingRecent.isEmpty) return 0;

      final messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 100, // wider net for retry
      );

      // Only consider SMS from the same 24-hour window.
      final recentMessages = messages.where((msg) =>
        msg.date != null && msg.date!.isAfter(cutoff),
      ).toList();

      int matchedCount = 0;

      for (final message in recentMessages) {
        final sender = message.sender ?? '';
        final body = message.body ?? '';
        final smsTime = message.date;

        if (!_isFromMobileMoney(sender)) continue;

        final parsedSms = SmsParserService.parseSms(body);
        if (parsedSms == null) continue;

        // requireSmsAfterTransaction removes the strict upper time cap so
        // transactions that took >5 min to confirm still get matched.
        final matchedRecord = await TransactionMatcherService.matchSmsToTransaction(
          parsedSms,
          smsTimestamp: smsTime,
          requireSmsAfterTransaction: true,
        );

        if (matchedRecord != null) {
          await UssdRecordService.updateUssdRecord(matchedRecord);
          matchedCount++;
        }
      }

      return matchedCount;
    } catch (e) {
      if (kDebugMode) debugPrint('Error in retry matching: $e');
      return 0;
    }
  }

  static bool _isFromMobileMoney(String sender) {
    final s = sender.toLowerCase().trim();
    return s.contains('m-money') ||
        s.contains('mmoney') ||
        s.contains('mtn') ||
        s.contains('airtel') ||
        s.contains('ekash');
  }
}
