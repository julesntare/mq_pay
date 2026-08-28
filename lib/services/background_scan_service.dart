import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../models/transaction_suggestion.dart';
import '../models/ussd_record.dart';
import 'notification_service.dart';
import 'sms_rule_service.dart';
import 'suggestion_service.dart';
import 'sms_parser_service.dart';
import 'transaction_matcher_service.dart';
import 'ussd_record_service.dart';

/// Periodic background scan (WorkManager) that finds outgoing mobile-money
/// transactions made outside the app — SMS receipts that match no existing
/// record — and records them automatically.
///
/// Unlike SmsListenerService/TransactionMatcherService (record-first: an SMS
/// only ever confirms an existing pending record), this is SMS-first: a
/// recognized debit receipt with no matching record creates a new one.
class BackgroundScanService {
  static const String taskName = 'unrecordedScanTask';
  static const String enabledKey = 'autoScanEnabled';
  static const String intervalKey = 'autoScanIntervalHours';
  static const String highWaterMarkKey = 'autoScanLastSmsMs';

  static final SmsQuery _query = SmsQuery();

  /// Enable/disable from settings. On enable the high-water mark is set to
  /// now so the existing inbox history is never backfilled.
  static Future<void> setEnabled(bool enabled, {int? hours}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, enabled);
    if (hours != null) await prefs.setInt(intervalKey, hours);

    if (enabled) {
      if (!prefs.containsKey(highWaterMarkKey)) {
        await prefs.setInt(
            highWaterMarkKey, DateTime.now().millisecondsSinceEpoch);
      }
      final interval = hours ?? prefs.getInt(intervalKey) ?? 2;
      try {
        await Workmanager().registerPeriodicTask(
          taskName,
          taskName,
          frequency: Duration(hours: interval),
          // replace so interval changes from settings take effect
          existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        );
      } catch (_) {}
    } else {
      try {
        await Workmanager().cancelByUniqueName(taskName);
      } catch (_) {}
    }
  }

  /// Called on app startup: re-register (keep policy) if the user enabled it.
  static Future<void> ensureRegisteredIfEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(enabledKey) != true) return;
      final interval = prefs.getInt(intervalKey) ?? 2;
      await Workmanager().registerPeriodicTask(
        taskName,
        taskName,
        frequency: Duration(hours: interval),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (_) {}
  }

  /// Scan entry point — called from WorkManager's callbackDispatcher on the
  /// periodic tick, and from MainWrapper on every app open/resume so newly
  /// arrived receipts are recorded without waiting for the next tick.
  static Future<void> scanForUnrecorded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(enabledKey) != true) return;
      if (!(await Permission.sms.status).isGranted) return;

      final now = DateTime.now();
      final markMs = prefs.getInt(highWaterMarkKey) ?? 0;
      // Safety clamp: never look back more than 48h even if the mark is stale.
      final floor = now.subtract(const Duration(hours: 48));
      var checkFrom = DateTime.fromMillisecondsSinceEpoch(markMs);
      if (checkFrom.isBefore(floor)) checkFrom = floor;

      final suggestionsBefore = await SuggestionService.count();
      final created = await _scanSince(checkFrom, queryCount: 200);
      final newSuggestions = await SuggestionService.count() - suggestionsBefore;

      await prefs.setInt(highWaterMarkKey, now.millisecondsSinceEpoch);

      if (newSuggestions > 0) {
        await NotificationService.showSuggestionNotification(newSuggestions);
      }

      if (created.length == 1) {
        await NotificationService.showAutoRecordedNotification(created.first);
      } else if (created.length > 1) {
        await NotificationService.showAutoRecordedBulkNotification(
            created.length);
      }
    } catch (_) {}
  }

  /// User-triggered deep scan (settings → "Scan missed transactions"):
  /// looks back [lookback] regardless of the high-water mark, to backfill
  /// after a reinstall or a restore from an incomplete backup. Dedup makes
  /// it safe to run repeatedly. Deliberately not gated on [enabledKey] —
  /// an explicit user action should work even with auto-scan off.
  /// Returns the number of records created (the caller shows the result in
  /// the UI, so no notifications here). Advances the mark so the next
  /// periodic scan doesn't redo this work.
  static Future<int> scanMissed({required Duration lookback}) async {
    if (!(await Permission.sms.status).isGranted) return 0;

    final now = DateTime.now();
    final created = await _scanSince(now.subtract(lookback), queryCount: 1000);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(highWaterMarkKey, now.millisecondsSinceEpoch);
    return created.length;
  }

  /// Shared scan core: records every unrecorded debit receipt (and bank-pull
  /// fee) from inbox SMS newer than [checkFrom]. Returns the created records.
  static Future<List<UssdRecord>> _scanSince(
    DateTime checkFrom, {
    required int queryCount,
  }) async {
    // WorkManager runs this in its own isolate, so the parser's cached own
    // number and the detection rules have to be (re)loaded here before any
    // SMS is parsed.
    await SmsParserService.loadSettings();

    final messages = await _query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: queryCount,
    );

    final candidates = messages
        .where((msg) =>
            msg.date != null &&
            msg.date!.isAfter(checkFrom) &&
            SmsParserService.isKnownFinancialSender(msg.sender ?? ''))
        .toList()
      ..sort((a, b) => a.date!.compareTo(b.date!)); // oldest first

    final allRecords = await UssdRecordService.getUssdRecords();
    final created = <UssdRecord>[];

    for (final msg in candidates) {
      final body = msg.body ?? '';
      final sender = msg.sender ?? '';

      // An explicit ignore rule is the user telling us this sender's
      // messages are never transactions.
      if (SmsParserService.isIgnoredByRule(body, sender: sender)) continue;

      // Bank→MoMo pull: not spending, but BK charges a flat fee per
      // transaction — record a fee-only entry (amount 0, fee 20 RWF).
      // Must run before the incoming-money skip, since a pull receipt
      // is an incoming "You have received ..." message.
      final bankPull = SmsParserService.parseBankPull(body);
      if (bankPull != null) {
        if (!_alreadyRecorded(allRecords, created, bankPull, msg.date!)) {
          final record = _buildRecord(bankPull, msg.date!);
          await UssdRecordService.saveUssdRecord(record);
          created.add(record);
        }
        continue;
      }

      // A user-taught rule (their own bank, a fintech the built-in pack has
      // never heard of) owns the message outright. A rule still awaiting
      // confirmation doesn't write to the ledger: its match is queued for
      // the user to approve instead.
      final byRule =
          SmsParserService.detectRuleTransaction(body, sender: sender);
      if (byRule != null) {
        if (_alreadyRecorded(allRecords, created, byRule, msg.date!)) continue;
        if (byRule['needsConfirmation'] == true) {
          await SuggestionService.add(TransactionSuggestion(
            id: '${msg.date!.millisecondsSinceEpoch}-${byRule['ruleId']}',
            ruleId: byRule['ruleId'] as String? ?? '',
            ruleLabel: _ruleLabel(byRule['ruleId'] as String?),
            sender: sender,
            smsBody: body,
            smsDate: msg.date!,
            parsed: byRule,
          ));
          continue;
        }
        final record = _buildRecord(byRule, msg.date!);
        await UssdRecordService.saveUssdRecord(record);
        created.add(record);
        continue;
      }

      // Bank-sender SMS (BKeBANK) are only ever pull confirmations here;
      // never feed them into the MoMo debit-receipt pipeline below.
      if (SmsParserService.isFromBank(sender)) continue;

      if (_looksLikeIncomingMoney(body)) continue;

      final parsed = SmsParserService.parseSms(body);
      if (parsed == null || parsed['status'] != 'success') continue;

      // Match-first: if this SMS confirms an existing pending record,
      // resolve that record instead of creating a duplicate.
      final matched = await TransactionMatcherService.matchSmsToTransaction(
        parsed,
        smsTimestamp: msg.date,
        requireSmsAfterTransaction: true,
      );
      if (matched != null) {
        await UssdRecordService.updateUssdRecord(matched);
        continue;
      }

      if (_alreadyRecorded(allRecords, created, parsed, msg.date!)) continue;

      final record = _buildRecord(parsed, msg.date!);
      await UssdRecordService.saveUssdRecord(record);
      created.add(record);
    }

    return created;
  }

  /// Defense-in-depth on top of parseSms's outgoing-oriented keywords:
  /// broad success keywords ("successfully", "confirmed.") could otherwise
  /// match an incoming "You have received ..." SMS.
  static bool _looksLikeIncomingMoney(String body) {
    final lower = body.toLowerCase();
    final incoming = lower.contains('received') || lower.contains('reçu');
    final outgoing = lower.contains('sent') ||
        lower.contains('transferred') ||
        lower.contains('was completed') ||
        lower.contains('transféré');
    return incoming && !outgoing;
  }

  static bool _alreadyRecorded(
    List<UssdRecord> existing,
    List<UssdRecord> created,
    Map<String, dynamic> parsed,
    DateTime smsDate,
  ) {
    final amount = parsed['amount'] as double;
    final confirmationCode = parsed['confirmationCode'] as String?;
    final rawText = parsed['rawText'] as String?;

    bool matches(UssdRecord r) {
      if (confirmationCode != null && r.confirmationCode == confirmationCode) {
        return true;
      }
      if (rawText != null && r.smsRawText == rawText) return true;
      return (r.amount - amount).abs() <= 1.0 &&
          r.timestamp.difference(smsDate).abs() <= const Duration(minutes: 3);
    }

    return existing.any(matches) || created.any(matches);
  }

  /// Record shape lives in SuggestionService so an approved suggestion and an
  /// auto-recorded scan produce byte-identical records.
  static UssdRecord _buildRecord(
          Map<String, dynamic> parsed, DateTime smsDate) =>
      SuggestionService.buildRecord(parsed, smsDate);

  static String _ruleLabel(String? ruleId) {
    if (ruleId == null) return '';
    final match =
        SmsRuleService.allRules().where((r) => r.id == ruleId).toList();
    return match.isEmpty ? ruleId : match.first.label;
  }
}
