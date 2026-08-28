import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

import 'sms_parser_service.dart';
import 'sms_rule_engine.dart';
import 'ussd_record_service.dart';

/// A message that looks like money moving, that nothing in the app knows how
/// to read.
class UnrecognizedSms {
  final String sender;
  final String body;
  final DateTime date;

  /// How many other messages in the inbox share this one's shape — same
  /// sender, same wording, different numbers. Teaching a rule from this
  /// message covers all of them, and the count is what tells the user that.
  final int similarCount;

  const UnrecognizedSms({
    required this.sender,
    required this.body,
    required this.date,
    this.similarCount = 1,
  });
}

/// Finds the messages the app is currently blind to.
///
/// Without this, the rules feature is undiscoverable: nobody goes looking in
/// settings for a way to teach an app about a message they haven't noticed it
/// missed. This turns "detection is incomplete" into a list you can act on.
class UnrecognizedSmsService {
  static final SmsQuery _query = SmsQuery();

  /// Digits and an RWF/FRW marker in either order — the cheap "is this about
  /// money at all" test, before any rule work happens.
  static final RegExp _moneyPattern = RegExp(
    r'(\d[\d,.]*\s*(?:rwf|frw)|(?:rwf|frw)\s*\d)',
    caseSensitive: false,
  );

  static final RegExp _digitRun = RegExp(r'\d+');
  static final RegExp _whitespace = RegExp(r'\s+');

  /// Scans the inbox for money-looking messages no rule and no built-in
  /// pipeline claims, newest first, one entry per distinct message shape.
  static Future<List<UnrecognizedSms>> find({
    Duration lookback = const Duration(days: 30),
    int queryCount = 300,
  }) async {
    if (!(await Permission.sms.status).isGranted) return const [];
    await SmsParserService.loadSettings();

    final cutoff = DateTime.now().subtract(lookback);
    final messages = await _query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: queryCount,
    );

    final records = await UssdRecordService.getUssdRecords();
    final recordedBodies = <String>{
      for (final record in records)
        if (record.smsRawText != null) record.smsRawText!.trim(),
    };

    // Keyed by sender + message shape, so a month of identical receipts
    // collapses into one row to teach from.
    final grouped = <String, List<SmsMessage>>{};

    for (final message in messages) {
      final date = message.date;
      final body = (message.body ?? '').trim();
      final sender = message.sender ?? '';
      if (date == null || date.isBefore(cutoff) || body.isEmpty) continue;
      if (!_moneyPattern.hasMatch(body)) continue;
      if (recordedBodies.contains(body)) continue;
      if (_isUnderstood(body, sender)) continue;

      grouped.putIfAbsent('${sender.toLowerCase()}|${shapeOf(body)}', () => [])
          .add(message);
    }

    final results = <UnrecognizedSms>[];
    for (final group in grouped.values) {
      group.sort((a, b) => b.date!.compareTo(a.date!));
      final newest = group.first;
      results.add(UnrecognizedSms(
        sender: newest.sender ?? '',
        body: (newest.body ?? '').trim(),
        date: newest.date!,
        similarCount: group.length,
      ));
    }

    results.sort((a, b) => b.date.compareTo(a.date));
    return results;
  }

  /// Whether anything in the app already reads this message: an active rule,
  /// the MoMo receipt pipeline, or the bank-pull stage.
  static bool _isUnderstood(String body, String sender) {
    if (SmsParserService.isIgnoredByRule(body, sender: sender)) return true;
    final byRule = SmsRuleEngine.evaluate(
      body,
      sender: sender,
      builtinParsers: SmsParserService.builtinRuleParsers,
    );
    if (byRule != null) return true;
    if (SmsParserService.isFromMobileMoney(sender) ||
        SmsParserService.isFromBank(sender)) {
      if (SmsParserService.parseSms(body) != null) return true;
    }
    return false;
  }

  /// Filters a found list by a free-text query over sender and body.
  ///
  /// Every whitespace-separated term must appear somewhere, so adding words
  /// narrows the list rather than widening it — "equity simba" finds the one
  /// receipt, not everything from Equity plus everything mentioning Simba.
  static List<UnrecognizedSms> search(
    List<UnrecognizedSms> messages,
    String query,
  ) {
    final terms = query.toLowerCase().trim().split(_whitespace)
      ..removeWhere((term) => term.isEmpty);
    if (terms.isEmpty) return messages;

    return messages.where((sms) {
      final haystack = '${sms.sender} ${sms.body}'.toLowerCase();
      return terms.every(haystack.contains);
    }).toList();
  }

  /// The message with its numbers blanked out, so two receipts that differ
  /// only in amount and date compare equal.
  static String shapeOf(String body) => body
      .toLowerCase()
      .replaceAll(_digitRun, '#')
      .replaceAll(_whitespace, ' ')
      .trim();
}
