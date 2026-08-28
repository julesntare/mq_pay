import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mq_pay/models/sms_rule.dart';
import 'package:mq_pay/services/sms_parser_service.dart';
import 'package:mq_pay/services/sms_rule_engine.dart';
import 'package:mq_pay/services/sms_rule_service.dart';

/// These tests pin the behaviour the hardcoded parsers had before detection
/// moved into the rule pack. Every expectation here is what the old
/// imperative code produced for the same message.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> loadWith(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    await SmsParserService.loadSettings();
  }

  setUp(() async {
    await loadWith({});
  });

  group('sender and keyword gates come from the pack', () {
    test('built-in mobile-money and bank sender IDs still match', () {
      expect(SmsParserService.isFromMobileMoney('M-Money'), isTrue);
      expect(SmsParserService.isFromMobileMoney('MTN Rwanda'), isTrue);
      expect(SmsParserService.isFromMobileMoney('AirtelMoney'), isTrue);
      expect(SmsParserService.isFromBank('BKeBANK'), isTrue);
      expect(SmsParserService.isFromBank('M-Money'), isFalse);
      expect(SmsParserService.isFromMobileMoney(''), isFalse);
    });

    test('"unsuccessful" never reads as a success', () {
      final failed = SmsParserService.parseSms(
        'Your payment of 5,000 RWF was unsuccessful.',
      );
      expect(failed, isNotNull);
      expect(failed!['status'], 'failed');
      expect(failed['amount'], 5000.0);
    });

    test('"SUCCESSFUL" alone still reads as a success', () {
      final ok = SmsParserService.parseSms(
        'Your transfer of 2,000 RWF to 0788123456 ET Id: TX99 SUCCESSFUL at '
        '2026-08-20 10:00:00.',
      );
      expect(ok, isNotNull);
      expect(ok!['status'], 'success');
      expect(ok['amount'], 2000.0);
    });

    test('a standard MoMo merchant receipt parses unchanged', () {
      final parsed = SmsParserService.parseSms(
        '*S*Your payment of 5,000 RWF to CITY OF KIGALI 123456 was completed. '
        'Fee: 100 RWF. New balance: 20,000 RWF. TxId: 987654321.',
      );
      expect(parsed, isNotNull);
      expect(parsed!['amount'], 5000.0);
      expect(parsed['fee'], 100.0);
      expect(parsed['recipient'], 'CITY OF KIGALI');
      expect(parsed['confirmationCode'], '987654321');
    });
  });

  group('migrated enrichment rules', () {
    test('Cash Power token', () {
      final result = SmsParserService.detectServiceEnrichment(
        'Meter#: 12345678 Token: 1234-5678-9012-3456 Units: 10.5 KWh '
        'Amount: 5000',
        sender: 'EFASHE',
      );
      expect(result, isNotNull);
      expect(result!['serviceKey'], 'efashe');
      expect(result['amount'], 5000.0);
      expect(
        result['extraDetails'],
        'Token: 1234-5678-9012-3456 · Units: 10.50 KWh · Meter: 12345678',
      );
      expect(result['refId'], isNull);
    });

    test('Cash Power SMS without a token is not a match', () {
      final result = SmsParserService.detectServiceEnrichment(
        'Meter#: 12345678 token request received, please wait.',
        sender: 'EFASHE',
      );
      expect(result, isNull);
    });

    test('a body signature from the wrong sender is rejected', () {
      final result = SmsParserService.detectServiceEnrichment(
        'Meter#: 12345678 Token: 1111-2222-3333-4444 Units: 3 KWh',
        sender: 'SomeoneElse',
      );
      expect(result, isNull);
    });

    test('an unknown sender falls back to the content signature', () {
      final result = SmsParserService.detectServiceEnrichment(
        'Meter#: 12345678 Token: 1111-2222-3333-4444 Units: 3 KWh',
      );
      expect(result, isNotNull);
      expect(result!['serviceKey'], 'efashe');
    });

    test('Canalbox renewal', () {
      final result = SmsParserService.detectServiceEnrichment(
        'Your CANALBOX subscription is renewed, valid until 2026-09-30. '
        'Amount paid: 25,000 RWF',
        sender: 'CANALBOX',
      );
      expect(result, isNotNull);
      expect(result!['serviceKey'], 'canalbox');
      expect(result['amount'], 25000.0);
      expect(result['extraDetails'],
          'Subscription renewed · Valid until 2026-09-30');
    });

    test('Canalbox message with no expiry keeps the leading segment', () {
      final result = SmsParserService.detectServiceEnrichment(
        'Your CANALBOX subscription has been activated.',
        sender: 'CANALBOX',
      );
      expect(result, isNotNull);
      expect(result!['extraDetails'], 'Subscription renewed');
    });

    test('Umutekano confirmation carries the TRID as the reference', () {
      final result = SmsParserService.detectServiceEnrichment(
        'You paid Umutekano 3,000F. TRID ABC123XYZ',
        sender: 'UMUTEKANO',
      );
      expect(result, isNotNull);
      expect(result!['serviceKey'], 'umutekano');
      expect(result['amount'], 3000.0);
      expect(result['refId'], 'ABC123XYZ');
      expect(result['extraDetails'], 'Confirmed via Umutekano · TRID ABC123XYZ');
    });

    test('BK debit alert', () {
      final result = SmsParserService.detectServiceEnrichment(
        'Your account has been debited RWF 12,000. Txn Charge: RWF 0. '
        'Txn Description: POS PURCHASE AT XYZ. Ref: BK123456. '
        'Available Balance: RWF 88,000',
      );
      expect(result, isNotNull);
      expect(result!['serviceKey'], 'bk');
      expect(result['amount'], 12000.0);
      expect(result['fee'], 0.0);
      expect(result['refId'], 'BK123456');
      expect(result['extraDetails'], 'POS PURCHASE AT XYZ · Ref: BK123456');
    });

    test('BK debit alert for an eKash move stays fee-only', () {
      final result = SmsParserService.detectServiceEnrichment(
        'Your account has been debited RWF 50,000. Txn Charge: RWF 20. '
        'Txn Description: EKASH P2P-NEW APP. Ref: FTCM26001.',
      );
      expect(result, isNotNull);
      expect(result!['serviceKey'], 'bk-pull');
      expect(result['amount'], isNull);
      expect(result['fee'], 20.0);
      expect(result['extraDetails'], isNull);
    });
  });

  group('migrated bank-pull rules', () {
    const walletSide = 'You have received 50,000 RWF from JULES NTARE. '
        'Message from sender: fund-transfer to 250780674459. '
        'Your new balance: 60,000 RWF. FT Id: 123456789.';

    String bankSide(String credited) =>
        'TRANSFER - EKASH Beneficiary: JULES NTARE Credited account: $credited '
        'Debited account: 00040012345 Amount:RWF 50,000 '
        'Event #:FTCM26001 Status: COMPLETED Date: 2026-08-20 Channel:MOBILE';

    test('wallet-side pull records the fee only', () {
      final result = SmsParserService.parseBankPull(walletSide);
      expect(result, isNotNull);
      expect(result!['amount'], 0.0);
      expect(result['fee'], SmsParserService.bkTransactionFee);
      expect(result['recipient'], 'Bank of Kigali');
      expect(result['serviceKey'], 'bk-pull');
      expect(result['confirmationCode'], '123456789');
      expect(result['extraDetails'], 'Pulled 50,000 RWF from bank');
    });

    test('a plain P2P receipt is not mistaken for a pull', () {
      final result = SmsParserService.parseBankPull(
        'You have received 5,000 RWF from JULES NTARE. Your new balance is '
        '9,000 RWF.',
      );
      expect(result, isNull);
    });

    test('bank-side transfer into my own wallet is fee-only', () async {
      await loadWith({'mobileNumber': '0780674459'});
      final result = SmsParserService.parseBankPull(bankSide('250780674459'));
      expect(result, isNotNull);
      expect(result!['amount'], 0.0);
      expect(result['serviceKey'], 'bk-pull');
    });

    test('bank-side transfer to someone else is real spending', () async {
      await loadWith({'mobileNumber': '0780674459'});
      final result = SmsParserService.parseBankPull(bankSide('250788123456'));
      expect(result, isNotNull);
      expect(result!['amount'], 50000.0);
      expect(result['recipient'], '0788123456');
      expect(result['serviceKey'], 'bk-ekash-send');
      expect(result['fee'], SmsParserService.bkTransactionFee);
      expect(result['extraDetails'], 'eKash transfer to JULES NTARE');
    });

    test('with no own number configured it stays fee-only', () {
      final result = SmsParserService.parseBankPull(bankSide('250788123456'));
      expect(result, isNotNull);
      expect(result!['amount'], 0.0);
    });
  });

  group('disabling a built-in rule', () {
    test('turns its detection off without touching the others', () async {
      await loadWith({
        SmsRuleService.disabledIdsKey: jsonEncode(['builtin.umutekano']),
      });

      expect(
        SmsParserService.detectServiceEnrichment(
          'You paid Umutekano 3,000F. TRID ABC123XYZ',
          sender: 'UMUTEKANO',
        ),
        isNull,
      );
      expect(
        SmsParserService.detectServiceEnrichment(
          'Your CANALBOX subscription is renewed, valid until 2026-09-30.',
          sender: 'CANALBOX',
        ),
        isNotNull,
      );
    });
  });

  group('user rules', () {
    const equityRule = {
      'id': 'user.equity',
      'label': 'Equity card purchase',
      'direction': 'spend',
      'senderMatch': ['equity'],
      'mustContain': ['debited'],
      'template': 'Your account has been debited RWF {amount} at {name}.',
      'eventKeyField': 'ref',
      'fields': [
        {'name': 'ref', 'type': 'ref', 'pattern': r'Ref\s*:\s*([A-Za-z0-9]+)'},
      ],
    };

    const purchase = 'Your account has been debited RWF 7,500 at '
        'SIMBA SUPERMARKET. Ref: EQ998877';

    test('a taught template extracts amount, payee and reference', () async {
      await loadWith({
        SmsRuleService.userRulesKey: jsonEncode([equityRule]),
      });

      final result =
          SmsParserService.detectRuleTransaction(purchase, sender: 'Equity');
      expect(result, isNotNull);
      expect(result!['amount'], 7500.0);
      expect(result['recipient'], 'SIMBA SUPERMARKET');
      expect(result['confirmationCode'], 'EQ998877');
      expect(result['status'], 'success');
      expect(result['ruleId'], 'user.equity');
    });

    test('its sender becomes worth scanning', () async {
      expect(SmsParserService.isKnownFinancialSender('Equity'), isFalse);
      await loadWith({
        SmsRuleService.userRulesKey: jsonEncode([equityRule]),
      });
      expect(SmsParserService.isKnownFinancialSender('Equity'), isTrue);
    });

    test('a rule that finds no amount does not claim the message', () async {
      await loadWith({
        SmsRuleService.userRulesKey: jsonEncode([equityRule]),
      });
      final result = SmsParserService.detectRuleTransaction(
        'Your account has been debited but the amount is missing.',
        sender: 'Equity',
      );
      expect(result, isNull);
    });

    test('a new rule awaiting confirmation is flagged, not silent', () async {
      await loadWith({
        SmsRuleService.userRulesKey: jsonEncode([
          {...equityRule, 'needsConfirmation': true},
        ]),
      });
      final result =
          SmsParserService.detectRuleTransaction(purchase, sender: 'Equity');
      expect(result, isNotNull);
      expect(result!['needsConfirmation'], isTrue);
    });

    test('an ignore rule silences a sender', () async {
      await loadWith({
        SmsRuleService.userRulesKey: jsonEncode([
          {
            'id': 'user.mute-promos',
            'label': 'Mute promos',
            'direction': 'ignore',
            'senderMatch': ['equity'],
            'mustContain': ['promotion'],
          },
        ]),
      });
      expect(
        SmsParserService.isIgnoredByRule('Big promotion this week!',
            sender: 'Equity'),
        isTrue,
      );
      expect(
        SmsParserService.isIgnoredByRule(purchase, sender: 'Equity'),
        isFalse,
      );
    });

    test('a user rule outranks a built-in when it carries a higher priority',
        () async {
      await loadWith({
        SmsRuleService.userRulesKey: jsonEncode([
          {
            'id': 'user.umutekano-mine',
            'label': 'My Umutekano',
            'priority': 50,
            'direction': 'enrichment',
            'mustContain': ['umutekano'],
            'serviceKey': 'umutekano',
            'detailsTemplate': 'Sector security fee',
          },
        ]),
      });
      final result = SmsParserService.detectServiceEnrichment(
        'You paid Umutekano 3,000F. TRID ABC123XYZ',
        sender: 'UMUTEKANO',
      );
      expect(result, isNotNull);
      expect(result!['ruleId'], 'user.umutekano-mine');
      expect(result['extraDetails'], 'Sector security fee');
    });

    test('rules survive a JSON round trip', () {
      final rule = SmsRule.fromJson(Map<String, dynamic>.from(equityRule));
      final again = SmsRule.fromJson(jsonDecode(rule.encode()));
      expect(again.id, rule.id);
      expect(again.template, rule.template);
      expect(again.senderMatch, rule.senderMatch);
      expect(again.fields.single.pattern, rule.fields.single.pattern);
      expect(again.eventKeyField, 'ref');
    });
  });

  group('backup', () {
    test('carries user rules and disabled built-ins across a restore',
        () async {
      await loadWith({
        SmsRuleService.userRulesKey: jsonEncode([
          {
            'id': 'user.equity',
            'label': 'Equity',
            'direction': 'spend',
            'template': 'debited RWF {amount}',
          },
        ]),
        SmsRuleService.disabledIdsKey: jsonEncode(['builtin.umutekano']),
      });
      final payload = await SmsRuleService.backupPayload();

      // A fresh device: nothing taught, nothing disabled.
      await loadWith({});
      expect(SmsRuleService.userRules(), isEmpty);

      await SmsRuleService.restoreFromBackup(payload);

      expect(SmsRuleService.userRules().single.id, 'user.equity');
      expect(
        SmsRuleService.allRules()
            .firstWhere((r) => r.id == 'builtin.umutekano')
            .enabled,
        isFalse,
      );
      expect(
        SmsParserService.detectServiceEnrichment(
          'You paid Umutekano 3,000F. TRID ABC123XYZ',
          sender: 'UMUTEKANO',
        ),
        isNull,
      );
    });

    test('a restore does not drop rules that only exist locally', () async {
      await loadWith({
        SmsRuleService.userRulesKey: jsonEncode([
          {'id': 'user.local', 'label': 'Local only', 'direction': 'spend'},
        ]),
      });
      await SmsRuleService.restoreFromBackup({
        'smsRules': [
          {'id': 'user.remote', 'label': 'From backup', 'direction': 'spend'},
        ],
      });
      expect(
        SmsRuleService.userRules().map((r) => r.id),
        containsAll(<String>['user.local', 'user.remote']),
      );
    });
  });

  group('template compilation', () {
    test('tolerates whitespace differences around the captured value', () {
      const rule = SmsRule(
        id: 'test',
        label: 'test',
        template: 'paid {amount} RWF to {name} today',
      );
      final tight = SmsRuleEngine.extractCaptures(
          rule, 'You paid 1,200RWF  to   MAMA SHOP today.');
      expect(tight['amount'], '1,200');
      expect(tight['name'], 'MAMA SHOP');
    });

    test('a trailing placeholder captures to the end of the line', () {
      const rule = SmsRule(
        id: 'test',
        label: 'test',
        template: 'Paid to {name}',
      );
      final captures =
          SmsRuleEngine.extractCaptures(rule, 'Paid to KIGALI WATER LTD');
      expect(captures['name'], 'KIGALI WATER LTD');
    });

    test('literal text is escaped, not treated as a pattern', () {
      const rule = SmsRule(
        id: 'test',
        label: 'test',
        template: 'Amount (RWF): {amount}',
      );
      expect(
        SmsRuleEngine.extractCaptures(rule, 'Amount (RWF): 900')['amount'],
        '900',
      );
      expect(
        SmsRuleEngine.extractCaptures(rule, 'Amount XRWFY: 900'),
        isEmpty,
      );
    });
  });
}
