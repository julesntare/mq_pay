import '../models/sms_rule.dart';
import 'sms_rule_service.dart';

/// A proven imperative parser a rule can delegate to. Supplied by the caller
/// (see `SmsParserService.builtinRuleParsers`) so the engine stays free of
/// bank-specific knowledge.
typedef BuiltinRuleParser = Map<String, dynamic>? Function(String sms);

/// A rule that fired, with what it pulled out of the message.
class RuleMatch {
  final SmsRule rule;

  /// Normalised result, in the same shape the existing pipelines consume:
  /// `amount`, `fee`, `recipient`, `status`, `confirmationCode`, `refId`,
  /// `serviceKey`, `extraDetails`, `rawText`.
  final Map<String, dynamic> data;

  /// Raw captures, keyed by field name — what the rule preview screen shows.
  final Map<String, String> captures;

  const RuleMatch({
    required this.rule,
    required this.data,
    this.captures = const {},
  });

  RuleDirection get direction => rule.direction;
  bool get needsConfirmation => rule.needsConfirmation;
}

/// Runs detection rules against a message.
///
/// Rules are tried highest-priority first and the first one that both passes
/// its gates *and* extracts what it needs wins. A rule whose gates pass but
/// whose extraction comes up empty falls through to the next one, so a
/// half-matching user rule can't shadow a working built-in.
class SmsRuleEngine {
  /// Evaluates [smsBody] against the active rules.
  ///
  /// [where] narrows the candidate set (e.g. enrichment rules only).
  /// [builtinParsers] resolves rules that delegate to imperative code; a rule
  /// naming a parser that isn't supplied is skipped.
  static RuleMatch? evaluate(
    String smsBody, {
    String? sender,
    Map<String, BuiltinRuleParser> builtinParsers = const {},
    bool Function(SmsRule rule)? where,
  }) {
    final sms = smsBody.trim();
    if (sms.isEmpty) return null;
    final lower = sms.toLowerCase();
    final senderId = sender ?? '';

    for (final rule in SmsRuleService.config.rules) {
      if (where != null && !where(rule)) continue;
      if (!rule.gatesPass(senderId, lower)) continue;

      final match = rule.builtinParser != null
          ? _runBuiltin(rule, sms, builtinParsers)
          : _runDeclarative(rule, sms);
      if (match != null) return match;
    }
    return null;
  }

  /// Every rule whose gates and extraction both succeed — for the "what would
  /// this rule do to my inbox?" preview, where shadowing must stay visible.
  static List<RuleMatch> evaluateAll(
    String smsBody, {
    String? sender,
    Map<String, BuiltinRuleParser> builtinParsers = const {},
    bool Function(SmsRule rule)? where,
  }) {
    final sms = smsBody.trim();
    if (sms.isEmpty) return const [];
    final lower = sms.toLowerCase();
    final senderId = sender ?? '';

    final matches = <RuleMatch>[];
    for (final rule in SmsRuleService.config.rules) {
      if (where != null && !where(rule)) continue;
      if (!rule.gatesPass(senderId, lower)) continue;
      final match = rule.builtinParser != null
          ? _runBuiltin(rule, sms, builtinParsers)
          : _runDeclarative(rule, sms);
      if (match != null) matches.add(match);
    }
    return matches;
  }

  /// Runs one specific rule, ignoring priority and the rest of the rule set.
  /// Used when previewing a rule the user is still editing and hasn't saved.
  static RuleMatch? evaluateRule(
    SmsRule rule,
    String smsBody, {
    String? sender,
    Map<String, BuiltinRuleParser> builtinParsers = const {},
  }) {
    final sms = smsBody.trim();
    if (sms.isEmpty) return null;
    if (!rule.gatesPass(sender ?? '', sms.toLowerCase())) return null;
    return rule.builtinParser != null
        ? _runBuiltin(rule, sms, builtinParsers)
        : _runDeclarative(rule, sms);
  }

  static RuleMatch? _runBuiltin(
    SmsRule rule,
    String sms,
    Map<String, BuiltinRuleParser> builtinParsers,
  ) {
    final parser = builtinParsers[rule.builtinParser];
    if (parser == null) return null;
    final result = parser(sms);
    if (result == null) return null;
    return RuleMatch(
      rule: rule,
      data: {
        ...result,
        'ruleId': rule.id,
        'direction': rule.direction.toJson(),
        'rawText': result['rawText'] ?? sms,
      },
    );
  }

  static RuleMatch? _runDeclarative(SmsRule rule, String sms) {
    final captures = extractCaptures(rule, sms);

    for (final required in rule.requiredFields) {
      if (!captures.containsKey(required)) return null;
    }

    final amount = _toNumber(captures['amount']);
    final fee = _toNumber(captures['fee']) ??
        _toNumber(captures['charge']) ??
        rule.fixedFee;

    // A rule that claims to record spending but found no amount hasn't
    // matched — recording a payment of "unknown" is worse than missing it.
    if (amount == null &&
        (rule.direction == RuleDirection.spend ||
            rule.direction == RuleDirection.moneyIn)) {
      return null;
    }

    // Nothing extracted and nothing to say: the rule fired on keywords alone
    // and would produce an empty record.
    final details = renderDetails(rule, captures);
    if (captures.isEmpty &&
        details == null &&
        rule.direction != RuleDirection.ignore) {
      return null;
    }

    final eventKey = rule.eventKeyField != null
        ? captures[rule.eventKeyField]
        : (captures['ref'] ?? captures['refId'] ?? captures['txid']);

    final recipient = captures['recipient'] ??
        captures['name'] ??
        captures['phone'] ??
        rule.recipientLabel;

    return RuleMatch(
      rule: rule,
      captures: captures,
      data: {
        'ruleId': rule.id,
        'direction': rule.direction.toJson(),
        'status': 'success',
        'serviceKey': rule.serviceKey,
        'amount': rule.direction == RuleDirection.feeOnly ? 0.0 : amount,
        'fee': fee,
        'recipient': recipient,
        'confirmationCode': eventKey,
        'refId': eventKey,
        'eventKey': eventKey,
        'extraDetails': details,
        'needsConfirmation': rule.needsConfirmation,
        'rawText': sms,
      },
    );
  }

  /// Pulls every field a rule defines out of [sms]. Template captures come
  /// first; independently anchored fields override them, since a labelled
  /// pattern is the more specific statement of where a value lives.
  static Map<String, String> extractCaptures(SmsRule rule, String sms) {
    final captures = <String, String>{};

    final compiled = rule.compileTemplate();
    if (compiled != null) {
      final match = compiled.regex.firstMatch(sms);
      if (match != null) {
        for (var i = 0; i < compiled.groups.length; i++) {
          final value = match.group(i + 1)?.trim();
          if (value != null && value.isNotEmpty) {
            captures[compiled.groups[i]] = value;
          }
        }
      }
    }

    for (final field in rule.fields) {
      final regex = field.compile();
      if (regex == null) continue;
      final match = regex.firstMatch(sms);
      if (match == null || match.groupCount < 1) continue;
      final value = match.group(1)?.trim();
      if (value != null && value.isNotEmpty) captures[field.name] = value;
    }

    return captures;
  }

  /// Renders `detailsTemplate`, dropping any ` · ` segment whose placeholders
  /// didn't resolve — so "Token: X · Units: Y KWh · Meter: Z" degrades to
  /// just the parts the message actually carried.
  static String? renderDetails(SmsRule rule, Map<String, String> captures) {
    final template = rule.detailsTemplate;
    if (template == null || template.isEmpty) return null;

    final kept = <String>[];
    for (final segment in template.split(' · ')) {
      var complete = true;
      final rendered = segment.replaceAllMapped(
        SmsRule.placeholderPattern,
        (m) {
          final name = m.group(1)!;
          final value = captures[name];
          if (value == null) {
            complete = false;
            return '';
          }
          return _formatValue(rule.typeForPlaceholder(name), value);
        },
      );
      if (complete && rendered.trim().isNotEmpty) kept.add(rendered.trim());
    }
    return kept.isEmpty ? null : kept.join(' · ');
  }

  static String _formatValue(FieldType type, String raw) {
    if (type == FieldType.decimal) {
      final n = _toNumber(raw);
      if (n != null) return n.toStringAsFixed(2);
    }
    return raw;
  }

  static double? _toNumber(String? raw) {
    if (raw == null) return null;
    return double.tryParse(raw.replaceAll(',', ''));
  }
}
