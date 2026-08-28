import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mq_pay/models/sms_rule.dart';
import 'package:mq_pay/models/transaction_suggestion.dart';
import 'package:mq_pay/services/sms_rule_builder.dart';
import 'package:mq_pay/services/sms_rule_engine.dart';
import 'package:mq_pay/services/sms_rule_service.dart';
import 'package:mq_pay/services/suggestion_service.dart';
import 'package:mq_pay/services/unrecognized_sms_service.dart';
import 'package:mq_pay/services/ussd_record_service.dart';

/// The message a user would teach from, and its siblings — same wording,
/// different amounts, payees, dates and balances.
const _taught = 'Dear JULES, your account has been debited RWF 7,500 at '
    'SIMBA SUPERMARKET on 20/08/2026. Ref: EQ998877. Balance: RWF 42,000';
const _sibling = 'Dear JULES, your account has been debited RWF 12,000 at '
    'KIGALI PHARMACY on 22/08/2026. Ref: EQ441122. Balance: RWF 30,000';
const _unrelated = 'Your MTN airtime balance is 350 RWF. Dial *345# to top up.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SmsRuleService.load();
  });

  /// Assigns [role] to the first occurrence of [word] in [body], the way
  /// tapping that word in the teach screen does.
  FieldSelection tap(String body, String word, String role) {
    final tokens = SmsRuleBuilder.tokenize(body);
    final token = tokens.firstWhere((t) => t.text == word,
        orElse: () => throw StateError('no token "$word" in message'));
    return FieldSelection(role: role, start: token.start, end: token.end);
  }

  SmsRule teachFrom(
    String body, {
    String sender = 'Equity',
    RuleDirection direction = RuleDirection.spend,
  }) {
    return SmsRuleBuilder.build(
      body: body,
      sender: sender,
      direction: direction,
      label: 'Equity card purchase',
      selections: [
        tap(body, '7,500', 'amount'),
        tap(body, 'SIMBA', 'recipient'),
        tap(body, 'SUPERMARKET', 'recipient'),
        tap(body, 'EQ998877', 'ref'),
      ],
    );
  }

  group('tokenizer', () {
    test('selectable spans exclude surrounding punctuation', () {
      final tokens = SmsRuleBuilder.tokenize('paid 7,500. Ref: EQ99!');
      final ref = tokens.firstWhere((t) => t.text == 'EQ99');
      expect(ref.raw, 'EQ99!');
      expect('paid 7,500. Ref: EQ99!'.substring(ref.start, ref.end), 'EQ99');

      final amount = tokens.firstWhere((t) => t.text == '7,500');
      expect(amount.raw, '7,500.');
    });

    test('punctuation-only tokens carry no selectable text', () {
      final tokens = SmsRuleBuilder.tokenize('paid — 500 RWF');
      expect(tokens.any((t) => t.raw == '—' && t.isEmpty), isTrue);
    });
  });

  group('teaching a rule', () {
    test('the rule reads back the message it was taught from', () {
      final rule = teachFrom(_taught);
      final match = SmsRuleEngine.evaluateRule(rule, _taught, sender: 'Equity');

      expect(match, isNotNull, reason: 'a rule must match its own example');
      expect(match!.data['amount'], 7500.0);
      expect(match.data['recipient'], 'SIMBA SUPERMARKET');
      expect(match.data['confirmationCode'], 'EQ998877');
    });

    test('and reads the next message worded the same way', () {
      final rule = teachFrom(_taught);
      final match =
          SmsRuleEngine.evaluateRule(rule, _sibling, sender: 'Equity');

      expect(match, isNotNull);
      expect(match!.data['amount'], 12000.0);
      expect(match.data['recipient'], 'KIGALI PHARMACY');
      expect(match.data['confirmationCode'], 'EQ441122');
    });

    test('an unrelated message from the same sender is left alone', () {
      final rule = teachFrom(_taught);
      expect(
        SmsRuleEngine.evaluateRule(rule, _unrelated, sender: 'Equity'),
        isNull,
      );
    });

    test('the same wording from another sender is left alone', () {
      final rule = teachFrom(_taught);
      expect(
        SmsRuleEngine.evaluateRule(rule, _sibling, sender: 'RandomPromo'),
        isNull,
      );
    });

    test('anchors skip dates and balances that change per message', () {
      final rule = teachFrom(_taught);
      final ref = rule.fields.firstWhere((f) => f.name == 'ref');
      expect(ref.after, isNotNull);
      expect(RegExp(r'\d').hasMatch(ref.after!), isFalse,
          reason: 'an anchor containing a date only ever matches once');
    });

    test('a payee is bounded, not swallowed to the end of the line', () {
      final rule = teachFrom(_taught);
      final recipient = rule.fields.firstWhere((f) => f.name == 'recipient');
      expect(recipient.before, isNotNull,
          reason: 'free text needs a word to stop at');
    });

    test('a payee containing the closing anchor word still resolves', () {
      final rule = teachFrom(_taught);
      final match = SmsRuleEngine.evaluateRule(
        rule,
        'Dear JULES, your account has been debited RWF 900 at LONDON CAFE '
        'on 23/08/2026. Ref: EQ7. Balance: RWF 100',
        sender: 'Equity',
      );
      expect(match, isNotNull);
      expect(match!.data['recipient'], 'LONDON CAFE');
    });

    test('adjacent words of the same role become one value', () {
      final rule = teachFrom(_taught);
      expect(rule.fields.where((f) => f.name == 'recipient').length, 1);
    });

    test('a new rule waits for approval and outranks the built-ins', () {
      final rule = teachFrom(_taught);
      expect(rule.needsConfirmation, isTrue);
      expect(rule.priority, greaterThan(100));
      expect(rule.source, RuleSource.user);
    });

    test('gate phrases are stored lower-cased, as gate matching expects', () {
      final rule = teachFrom(_taught);
      expect(rule.mustContain, isNotEmpty);
      for (final phrase in rule.mustContain) {
        expect(phrase, phrase.toLowerCase());
      }
      expect(rule.gatesPass('Equity', _taught.toLowerCase()), isTrue);
    });

    test('an ignore rule needs no amount to be useful', () {
      final rule = SmsRuleBuilder.build(
        body: _unrelated,
        sender: 'MTN',
        selections: const [],
        direction: RuleDirection.ignore,
        label: 'Airtime noise',
      );
      expect(rule.direction, RuleDirection.ignore);
      expect(rule.mustContain, isNotEmpty);
    });

    test('a saved rule survives the round trip through storage', () async {
      final rule = teachFrom(_taught);
      await SmsRuleService.saveUserRule(rule);
      await SmsRuleService.load();

      final reloaded =
          SmsRuleService.userRules().firstWhere((r) => r.id == rule.id);
      final match =
          SmsRuleEngine.evaluateRule(reloaded, _sibling, sender: 'Equity');
      expect(match, isNotNull);
      expect(match!.data['amount'], 12000.0);
    });
  });

  group('unrecognised message grouping', () {
    test('messages differing only in numbers share a shape', () {
      const sameMerchant = 'Dear JULES, your account has been debited RWF '
          '12,000 at SIMBA SUPERMARKET on 22/08/2026. Ref: EQ441122. '
          'Balance: RWF 30,000';
      expect(
        UnrecognizedSmsService.shapeOf(_taught),
        UnrecognizedSmsService.shapeOf(sameMerchant),
      );
    });

    test('a different payee forms its own group', () {
      // Grouping blanks numbers only. Two receipts naming different shops
      // are listed separately, which is the safe way round: teaching from
      // one message must never hide a differently worded one behind it.
      expect(
        UnrecognizedSmsService.shapeOf(_taught),
        isNot(UnrecognizedSmsService.shapeOf(_sibling)),
      );
    });

    test('differently worded messages do not share a shape', () {
      expect(
        UnrecognizedSmsService.shapeOf(_taught),
        isNot(UnrecognizedSmsService.shapeOf(_unrelated)),
      );
    });
  });

  group('searching unrecognised messages', () {
    final found = [
      UnrecognizedSms(
          sender: 'Equity', body: _taught, date: DateTime(2026, 8, 20)),
      UnrecognizedSms(
          sender: 'Equity', body: _sibling, date: DateTime(2026, 8, 22)),
      UnrecognizedSms(
          sender: 'MTN', body: _unrelated, date: DateTime(2026, 8, 23)),
    ];

    test('an empty query leaves the list alone', () {
      expect(UnrecognizedSmsService.search(found, '   ').length, 3);
    });

    test('matches on the sender', () {
      final results = UnrecognizedSmsService.search(found, 'equity');
      expect(results.length, 2);
    });

    test('matches on any word in the body, whatever the case', () {
      final results = UnrecognizedSmsService.search(found, 'PHARMACY');
      expect(results.single.body, _sibling);
    });

    test('extra terms narrow the list rather than widening it', () {
      expect(UnrecognizedSmsService.search(found, 'equity').length, 2);
      expect(
        UnrecognizedSmsService.search(found, 'equity simba').single.body,
        _taught,
      );
    });

    test('terms may appear in any order and across sender and body', () {
      expect(
        UnrecognizedSmsService.search(found, 'simba equity').single.body,
        _taught,
      );
    });

    test('a query nothing matches returns empty, not everything', () {
      expect(UnrecognizedSmsService.search(found, 'zzzz'), isEmpty);
    });
  });

  group('suggestion queue', () {
    TransactionSuggestion suggestion({
      String id = 's1',
      String body = _taught,
      double amount = 7500,
    }) {
      return TransactionSuggestion(
        id: id,
        ruleId: 'user.equity',
        ruleLabel: 'Equity card purchase',
        sender: 'Equity',
        smsBody: body,
        smsDate: DateTime(2026, 8, 20, 10),
        parsed: {
          'amount': amount,
          'recipient': 'SIMBA SUPERMARKET',
          'confirmationCode': 'EQ998877',
          'rawText': body,
        },
      );
    }

    test('holds a match without touching the ledger', () async {
      await SuggestionService.add(suggestion());
      expect(await SuggestionService.count(), 1);
      expect(await UssdRecordService.getUssdRecords(), isEmpty);
    });

    test('the same message never queues twice', () async {
      expect(await SuggestionService.add(suggestion()), isTrue);
      expect(await SuggestionService.add(suggestion(id: 's2')), isFalse);
      expect(await SuggestionService.count(), 1);
    });

    test('approving records it and clears the queue', () async {
      await SuggestionService.add(suggestion());
      final record = await SuggestionService.accept('s1');

      expect(record, isNotNull);
      expect(record!.amount, 7500.0);
      expect(record.recipient, 'SIMBA SUPERMARKET');
      expect(record.autoDetected, isTrue);
      expect(await SuggestionService.count(), 0);

      final saved = await UssdRecordService.getUssdRecords();
      expect(saved.single.confirmationCode, 'EQ998877');
    });

    test('discarding records nothing', () async {
      await SuggestionService.add(suggestion());
      await SuggestionService.dismiss('s1');
      expect(await SuggestionService.count(), 0);
      expect(await UssdRecordService.getUssdRecords(), isEmpty);
    });
  });

  group('sharing rules', () {
    test('export and import round trip through JSON', () async {
      await SmsRuleService.saveUserRule(teachFrom(_taught));
      final exported = SmsRuleService.exportUserRules();

      SharedPreferences.setMockInitialValues({});
      await SmsRuleService.load();
      expect(SmsRuleService.userRules(), isEmpty);

      final imported = await SmsRuleService.importUserRules(exported);
      expect(imported, 1);

      final match = SmsRuleEngine.evaluateRule(
        SmsRuleService.userRules().single,
        _sibling,
        sender: 'Equity',
      );
      expect(match, isNotNull);
      expect(match!.data['recipient'], 'KIGALI PHARMACY');
    });

    test('importing the same rule twice does not duplicate it', () async {
      final exported = jsonEncode({
        'rules': [teachFrom(_taught).toJson()],
      });
      await SmsRuleService.importUserRules(exported);
      await SmsRuleService.importUserRules(exported);
      expect(SmsRuleService.userRules().length, 1);
    });
  });
}
