import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/sms_rule.dart';
import 'sms_parser_service.dart';
import 'sms_rule_engine.dart';

class RulePreviewMatch {
  final String sender;
  final String body;
  final DateTime date;
  final Map<String, dynamic> data;

  const RulePreviewMatch({
    required this.sender,
    required this.body,
    required this.date,
    required this.data,
  });

  double? get amount => (data['amount'] as num?)?.toDouble();
  String? get recipient => data['recipient'] as String?;
  String? get reference => data['confirmationCode'] as String?;
}

class RulePreview {
  final int scanned;
  final List<RulePreviewMatch> matches;
  final bool permissionDenied;

  const RulePreview({
    required this.scanned,
    required this.matches,
    this.permissionDenied = false,
  });
}

/// Runs a rule the user is still editing against their real inbox.
///
/// This is the safety valve on the whole teach flow. A rule built from one
/// message can be far too greedy, and the only way to see that before it
/// starts writing to the ledger is to watch it run over messages the user
/// can recognise.
class SmsRulePreviewService {
  static final SmsQuery _query = SmsQuery();

  /// Applies [rule] alone — ignoring priority and every other rule — to the
  /// most recent [queryCount] messages.
  static Future<RulePreview> preview(
    SmsRule rule, {
    int queryCount = 200,
  }) async {
    if (!(await Permission.sms.status).isGranted) {
      return const RulePreview(
          scanned: 0, matches: [], permissionDenied: true);
    }

    final messages = await _query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: queryCount,
    );

    final matches = <RulePreviewMatch>[];
    for (final message in messages) {
      final body = (message.body ?? '').trim();
      if (body.isEmpty) continue;
      final match = SmsRuleEngine.evaluateRule(
        rule,
        body,
        sender: message.sender,
        builtinParsers: SmsParserService.builtinRuleParsers,
      );
      if (match == null) continue;
      matches.add(RulePreviewMatch(
        sender: message.sender ?? '',
        body: body,
        date: message.date ?? DateTime.now(),
        data: match.data,
      ));
    }

    matches.sort((a, b) => b.date.compareTo(a.date));
    return RulePreview(scanned: messages.length, matches: matches);
  }
}
