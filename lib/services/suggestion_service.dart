import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction_status.dart';
import '../models/transaction_suggestion.dart';
import '../models/ussd_record.dart';
import 'ussd_record_service.dart';

/// The waiting room for transactions a not-yet-trusted rule detected.
///
/// Nothing here has touched the ledger. The queue is capped and de-duplicated
/// on the message body, so a scan that revisits the same SMS — which the 24h
/// and 48h lookbacks do routinely — never stacks up copies.
class SuggestionService {
  static const String storageKey = 'sms_rule_suggestions';

  /// Beyond this the oldest are dropped: a queue nobody has looked at in
  /// weeks is a sign the rule is wrong, not a backlog worth keeping.
  static const int maxSuggestions = 50;

  static Future<List<TransactionSuggestion>> all() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(storageKey);
      if (json == null || json.isEmpty) return const [];
      final list = jsonDecode(json) as List;
      final suggestions = <TransactionSuggestion>[];
      for (final entry in list) {
        try {
          suggestions.add(
            TransactionSuggestion.fromJson(Map<String, dynamic>.from(entry)),
          );
        } catch (_) {}
      }
      suggestions.sort((a, b) => b.smsDate.compareTo(a.smsDate));
      return suggestions;
    } catch (_) {
      return const [];
    }
  }

  static Future<int> count() async => (await all()).length;

  /// Queues a suggestion unless the same message is already waiting.
  /// Returns true when something was actually added.
  static Future<bool> add(TransactionSuggestion suggestion) async {
    final existing = await all();
    if (existing.any((s) => s.smsBody == suggestion.smsBody)) return false;
    final next = [suggestion, ...existing];
    await _persist(
      next.length > maxSuggestions ? next.sublist(0, maxSuggestions) : next,
    );
    return true;
  }

  static Future<void> dismiss(String id) async {
    final next = (await all()).where((s) => s.id != id).toList();
    await _persist(next);
  }

  static Future<void> clear() async => _persist(const []);

  /// Records the suggestion for real and takes it off the queue.
  /// Returns the created record, or null if the suggestion had vanished.
  static Future<UssdRecord?> accept(String id) async {
    final suggestions = await all();
    final match = suggestions.where((s) => s.id == id).toList();
    if (match.isEmpty) return null;

    final record = buildRecord(match.first.parsed, match.first.smsDate);
    await UssdRecordService.saveUssdRecord(record);
    await _persist(suggestions.where((s) => s.id != id).toList());
    return record;
  }

  /// Builds the ledger record for a parsed SMS. Shared by the background
  /// scan and by accepting a suggestion, so a transaction looks the same
  /// however it got in.
  static UssdRecord buildRecord(Map<String, dynamic> parsed, DateTime smsDate) {
    final recipient = (parsed['recipient'] as String?) ??
        (parsed['merchantName'] as String?) ??
        'Unknown';
    final isPhone =
        RegExp(r'^(\+?250)?0?7[2389]\d{7}$').hasMatch(recipient.trim());
    final fee = (parsed['fee'] as num?)?.toDouble();

    return UssdRecord(
      id: '${smsDate.millisecondsSinceEpoch}-auto',
      ussdCode: 'AUTO-DETECTED-${smsDate.millisecondsSinceEpoch}',
      recipient: recipient,
      recipientType: isPhone ? 'phone' : 'misc',
      amount: (parsed['amount'] as num?)?.toDouble() ?? 0.0,
      timestamp: smsDate,
      fee: fee,
      applyFee: fee != null,
      status: TransactionStatus.success,
      confirmationCode: parsed['confirmationCode'] as String?,
      smsRawText: parsed['rawText'] as String?,
      statusUpdatedAt: DateTime.now(),
      serviceKey: parsed['serviceKey'] as String?,
      extraDetails: parsed['extraDetails'] as String?,
      autoDetected: true,
    );
  }

  static Future<void> _persist(List<TransactionSuggestion> suggestions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        storageKey,
        jsonEncode(suggestions.map((s) => s.toJson()).toList()),
      );
    } catch (_) {}
  }
}
