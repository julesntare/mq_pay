import 'dart:async';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'transaction_matcher_service.dart';
import 'sms_parser_service.dart';
import 'notification_service.dart';
import '../services/ussd_record_service.dart';
import 'service_polling_scheduler.dart';

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
    } catch (_) {}
  }

  static Future<void> _processSms(SmsMessage message) async {
    final sender = message.sender ?? '';
    final body = message.body ?? '';

    final matched = await TransactionMatcherService.processSms(body, sender);
    if (matched != null) {
      await NotificationService.showTransactionNotification(matched);
      return;
    }

    final enriched = await TransactionMatcherService.tryMatchServiceEnrichment(
      body,
      smsTimestamp: message.date,
      sender: sender,
    );
    if (enriched != null) {
      await NotificationService.showTransactionNotification(enriched);
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

      // Service-tagged records (pending or already-success) can still
      // receive a delayed enrichment SMS even after stage-1 resolved them.
      final serviceCandidates = records.where((r) =>
        r.serviceKey != null && r.timestamp.isAfter(cutoff),
      ).toList();

      if (pendingRecent.isEmpty && serviceCandidates.isEmpty) return 0;

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

        if (pendingRecent.isNotEmpty && _isFromMobileMoney(sender)) {
          final parsedSms = SmsParserService.parseSms(body);
          if (parsedSms != null) {
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
              continue;
            }
          }
        }

        if (serviceCandidates.isNotEmpty) {
          final enriched = await TransactionMatcherService.tryMatchServiceEnrichment(
            body,
            smsTimestamp: smsTime,
            sender: sender,
          );
          if (enriched != null) matchedCount++;
        }
      }

      await ServicePollingScheduler.cancelIfIdle();
      return matchedCount;
    } catch (_) {
      return 0;
    }
  }

  /// Background-task entry point (called from WorkManager's callbackDispatcher
  /// every ~15 min while a service-tagged pending transaction exists).
  /// Reuses the same 24h scan as the resume catch-up, then notifies if
  /// anything resolved and self-cancels the background task once idle.
  static Future<void> pollServiceTransactions() async {
    final matchedCount = await retryPendingTransactionMatching();
    if (matchedCount > 0) {
      await NotificationService.showTransactionStatusNotification();
    }
  }

  static bool _isFromMobileMoney(String sender) =>
      SmsParserService.isFromMobileMoney(sender);
}
