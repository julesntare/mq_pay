import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SmsParserService {
  /// The user's own mobile numbers from settings, each reduced to its last 9
  /// significant digits. Needed to tell a BK eKash *self*-transfer (moving
  /// my own money into my own wallet — fee only) from a real eKash transfer
  /// to somebody else (spending — record the full amount).
  /// Empty until [loadOwnNumber] runs, or when settings hold no number.
  static Set<String> _ownNumberKeys = {};

  /// Re-reads the user's own numbers from settings: every `paymentMethods`
  /// entry of type `mobile`, plus the legacy `mobileNumber` key for installs
  /// that predate that migration.
  ///
  /// Must be awaited before parsing in every isolate that parses SMS —
  /// WorkManager runs the background scan in its own isolate, where static
  /// state doesn't carry over — and it also keeps the cache honest after the
  /// user edits their numbers in settings.
  static Future<void> loadOwnNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = <String>{};

      final legacy = normalizePhone(prefs.getString('mobileNumber'));
      if (legacy != null) keys.add(legacy);

      final methodsJson = prefs.getString('paymentMethods');
      if (methodsJson != null && methodsJson.isNotEmpty) {
        for (final entry in jsonDecode(methodsJson) as List) {
          if (entry is! Map) continue;
          if (entry['type'] != 'mobile') continue;
          final key = normalizePhone(entry['value'] as String?);
          if (key != null) keys.add(key);
        }
      }

      _ownNumberKeys = keys;
    } catch (_) {}
  }

  /// Last 9 digits of [raw], so "250780674459", "+250 780 674 459",
  /// "0780674459" and "780674459" all compare equal. Null when there aren't
  /// 9 digits to compare on.
  static String? normalizePhone(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) return null;
    return digits.substring(digits.length - 9);
  }

  /// Whether [candidate] is one of the user's own numbers, in any format.
  static bool isOwnNumber(String? candidate) {
    final key = normalizePhone(candidate);
    return key != null && _ownNumberKeys.contains(key);
  }

  /// Local 07xx form of [raw] (e.g. "250780674459" → "0780674459"), so the
  /// recipient reads like every other phone record and contact lookup works.
  static String toLocalPhone(String raw) {
    final key = normalizePhone(raw);
    return key == null ? raw.trim() : '0$key';
  }

  /// Whether [sender] looks like a mobile-money / telco sender ID.
  static bool isFromMobileMoney(String sender) {
    final s = sender.toLowerCase().trim();
    return s.contains('m-money') ||
        s.contains('mmoney') ||
        s.contains('mtn') ||
        s.contains('airtel') ||
        s.contains('ekash');
  }

  /// Whether [sender] is Bank of Kigali's eBanking sender ID ("BKeBANK").
  static bool isFromBank(String sender) =>
      sender.toLowerCase().trim().contains('bkebank');

  static Map<String, dynamic>? parseSms(String smsBody) {
    final cleaned = smsBody.trim();
    // A bank↔wallet pull is never spending: short-circuit here so no
    // pipeline can ever record the transferred amount as a payment —
    // only the flat BK fee (amount 0, fee 20) is kept.
    final bankPull = parseBankPull(cleaned);
    if (bankPull != null) return bankPull;
    final isSuccess = _isSuccessMessage(cleaned);
    final isFailure = _isFailureMessage(cleaned);
    if (!isSuccess && !isFailure) return null;
    return isSuccess ? _parseSuccessMessage(cleaned) : _parseFailureMessage(cleaned);
  }

  static bool _isSuccessMessage(String sms) {
    final lower = sms.toLowerCase();
    return lower.contains('*s*') ||
        lower.contains('transferred to') ||
        lower.contains('was completed') ||
        lower.contains('you have transferred') ||
        lower.contains('you have sent') ||
        // "successful" alone (new eKash format: "... SUCCESSFUL at <date>"),
        // guarded so "unsuccessful" never reads as success.
        (lower.contains('successful') && !lower.contains('unsuccessful')) ||
        lower.contains('congratulations') ||
        lower.contains('transaction successful') ||
        lower.contains('payment successful') ||
        lower.contains('sent to') ||
        lower.contains('confirmed.') ||
        lower.contains('please keep') || // "Please keep this as proof of payment"
        lower.contains('has been sent') ||
        lower.contains('has been transferred') ||
        lower.contains('avez transféré') || // French MTN
        lower.contains('effectué'); // French: "opération effectuée"
  }

  static bool _isFailureMessage(String sms) {
    final lower = sms.toLowerCase();
    return lower.contains('*r*') ||
        lower.contains('failed') ||
        lower.contains('transaction declined') ||
        lower.contains('not processed') ||
        lower.contains('unsuccessful') ||
        lower.contains('could not be completed') ||
        lower.contains('declined') ||
        lower.contains('your request was not') ||
        lower.contains('refusé'); // French: refused
  }

  static Map<String, dynamic>? _parseSuccessMessage(String sms) {
    final amount = _extractTransactionAmount(sms);
    if (amount == null) return null;
    return {
      'amount': amount,
      'recipient': _extractRecipient(sms),
      'status': 'success',
      'confirmationCode': _extractConfirmationCode(sms),
      'fee': _extractFee(sms),
      'merchantName': _extractMerchantName(sms),
      'rawText': sms,
    };
  }

  /// Extracts the merchant/biller name from generic MTN completion messages,
  /// e.g. "A transaction of 2000 RWF by CITY OF KIGALI ... was completed".
  static String? _extractMerchantName(String sms) {
    final pattern = RegExp(
      r'by\s+([A-Z][A-Za-z0-9\s&.()]+?)\s+was completed',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(sms);
    if (match != null) return match.group(1)!.trim();
    return null;
  }

  /// Confirmed sender IDs for each service's delayed enrichment SMS.
  static const Map<String, String> _enrichmentSenderIds = {
    'efashe': 'efashe',
    'canalbox': 'canalbox',
    'umutekano': 'umutekano',
  };

  /// Detects a delayed, service-specific enrichment message (Cash Power token,
  /// Canalbox renewal, Umutekano confirmation) that doesn't look like a
  /// standard MoMo debit receipt and would otherwise be silently dropped.
  /// Primarily content-signature based; when [sender] is available it must
  /// also match the confirmed sender ID for that service, as a defense-in-depth
  /// check against an unrelated SMS coincidentally matching the body pattern.
  static Map<String, dynamic>? detectServiceEnrichment(String smsBody, {String? sender}) {
    final sms = smsBody.trim();
    final lower = sms.toLowerCase();

    String? serviceKey;
    if (lower.contains('meter#') && lower.contains('token')) {
      serviceKey = 'efashe';
    } else if (lower.contains('canalbox')) {
      serviceKey = 'canalbox';
    } else if (lower.contains('umutekano')) {
      serviceKey = 'umutekano';
    } else if (lower.contains('has been debited')) {
      serviceKey = 'bk';
    }
    if (serviceKey == null) return null;

    // Sender confirmation is only enforced when we actually know the
    // expected sender ID for this service (e.g. BK's sender wasn't
    // confirmed) — otherwise fall back to content-signature only.
    final expectedSender = _enrichmentSenderIds[serviceKey];
    if (expectedSender != null && sender != null && sender.trim().isNotEmpty) {
      if (!sender.toLowerCase().contains(expectedSender)) return null;
    }

    switch (serviceKey) {
      case 'efashe':
        return _parseEfasheEnrichment(sms);
      case 'canalbox':
        return _parseCanalboxEnrichment(sms);
      case 'umutekano':
        return _parseUmutekanoEnrichment(sms);
      case 'bk':
        return _parseBankDebit(sms);
    }
    return null;
  }

  static Map<String, dynamic>? _parseEfasheEnrichment(String sms) {
    final meterMatch = RegExp(r'Meter#\s*:\s*(\S+)', caseSensitive: false).firstMatch(sms);
    final tokenMatch = RegExp(r'Token\s*:\s*(\S+)', caseSensitive: false).firstMatch(sms);
    final unitsMatch = RegExp(r'Units\s*:\s*([\d.]+)\s*KW', caseSensitive: false).firstMatch(sms);
    final amountMatch = RegExp(r'Amount\s*:\s*([\d.]+)', caseSensitive: false).firstMatch(sms);

    if (tokenMatch == null) return null;

    final parts = <String>['Token: ${tokenMatch.group(1)}'];
    if (unitsMatch != null) {
      final units = double.tryParse(unitsMatch.group(1)!);
      parts.add('Units: ${units != null ? units.toStringAsFixed(2) : unitsMatch.group(1)} KWh');
    }
    if (meterMatch != null) parts.add('Meter: ${meterMatch.group(1)}');

    return {
      'serviceKey': 'efashe',
      'extraDetails': parts.join(' · '),
      'amount': amountMatch != null ? double.tryParse(amountMatch.group(1)!) : null,
      'refId': null,
      'rawText': sms,
    };
  }

  static Map<String, dynamic>? _parseCanalboxEnrichment(String sms) {
    final validMatch =
        RegExp(r'valid until\s*([\d\-\/]+)', caseSensitive: false).firstMatch(sms);
    final amountMatch =
        RegExp(r'Amount paid\s*:?\s*([\d,]+)\s*RWF', caseSensitive: false).firstMatch(sms);

    final parts = <String>['Subscription renewed'];
    if (validMatch != null) parts.add('Valid until ${validMatch.group(1)}');

    return {
      'serviceKey': 'canalbox',
      'extraDetails': parts.join(' · '),
      'amount': amountMatch != null
          ? double.tryParse(amountMatch.group(1)!.replaceAll(',', ''))
          : null,
      'refId': null,
      'rawText': sms,
    };
  }

  static Map<String, dynamic>? _parseUmutekanoEnrichment(String sms) {
    final amountMatch = RegExp(r'Umutekano\s*([\d,]+)F', caseSensitive: false).firstMatch(sms);
    final tridMatch = RegExp(r'TRID\s+([A-Za-z0-9]+)', caseSensitive: false).firstMatch(sms);

    return {
      'serviceKey': 'umutekano',
      'extraDetails': 'Confirmed via Umutekano'
          '${tridMatch != null ? ' · TRID ${tridMatch.group(1)}' : ''}',
      'amount': amountMatch != null
          ? double.tryParse(amountMatch.group(1)!.replaceAll(',', ''))
          : null,
      'refId': tridMatch?.group(1),
      'rawText': sms,
    };
  }

  /// Flat fee BK charges on every bank↔MoMo transaction (introduced July 2026).
  static const double bkTransactionFee = 20.0;

  /// Bank→MoMo pull (BK push & pull). Moving your own money from the bank
  /// into the wallet is not spending, so the record carries only BK's flat
  /// transaction fee (amount 0); the pulled amount is kept in extraDetails.
  /// Two known formats for the same event:
  ///  - MoMo side (sender "M-Money"): "You have received X RWF from NAME
  ///    ... Message from sender: fund-transfer to 2507XXXXXXXX. ... FT Id: N"
  ///  - Bank side (sender "BKeBANK"): "TRANSFER - EKASH Beneficiary: NAME
  ///    Credited account: 2507XXXXXXXX Debited account: N Amount:RWF X
  ///    Event #:FTCM... Status: COMPLETED Date: ... Channel:MOBILE"
  static Map<String, dynamic>? parseBankPull(String smsBody) {
    final sms = smsBody.trim();
    return _parseMoMoSidePull(sms) ?? _parseBankSidePull(sms);
  }

  /// "FT Id" (bank funds-transfer reference) is required so a regular P2P
  /// receipt whose sender note happens to say "fund-transfer" won't match.
  static Map<String, dynamic>? _parseMoMoSidePull(String sms) {
    final lower = sms.toLowerCase();
    if (!lower.contains('you have received') ||
        !lower.contains('fund-transfer') ||
        !(lower.contains('ft id') ||
            lower.contains('financial transaction id'))) {
      return null;
    }

    final amountMatch = RegExp(
      r'received\s+([\d,]+(?:\.\d+)?)\s*RWF',
      caseSensitive: false,
    ).firstMatch(sms);
    final ftMatch = RegExp(
          r'FT\s*Id\s*:\s*([A-Za-z0-9]+)',
          caseSensitive: false,
        ).firstMatch(sms) ??
        RegExp(
          r'Financial\s*Transaction\s*Id\s*:\s*([A-Za-z0-9]+)',
          caseSensitive: false,
        ).firstMatch(sms);

    return _bankPullResult(
      pulledAmountText: amountMatch?.group(1),
      confirmationCode: ftMatch?.group(1),
      rawText: sms,
    );
  }

  /// "Credited account"/"Debited account" are required so a MoMo/eKash
  /// wallet SMS that merely mentions "transfer" and "ekash" won't match.
  /// Only COMPLETED transfers are recorded.
  ///
  /// The same SMS format covers two very different events, told apart by
  /// whose wallet "Credited account" names:
  ///  - my own number → self-pull, not spending: fee-only record.
  ///  - somebody else's number → a real P2P send: record the full amount
  ///    against that number, with BK's transaction charge as the fee.
  static Map<String, dynamic>? _parseBankSidePull(String sms) {
    final lower = sms.toLowerCase();
    if (!lower.contains('transfer') ||
        !lower.contains('ekash') ||
        !lower.contains('credited account') ||
        !lower.contains('debited account') ||
        !lower.contains('completed')) {
      return null;
    }

    final amountMatch = RegExp(
      r'Amount\s*:\s*RWF\s*([\d,]+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(sms);
    final eventMatch = RegExp(r'Event\s*#\s*:\s*([A-Za-z0-9]+)', caseSensitive: false)
        .firstMatch(sms);
    final creditedMatch = RegExp(
      r'Credited\s*account\s*:\s*\+?([\d\s-]{9,})',
      caseSensitive: false,
    ).firstMatch(sms);

    final credited = creditedMatch?.group(1)?.trim();
    final amount = amountMatch != null
        ? double.tryParse(amountMatch.group(1)!.replaceAll(',', ''))
        : null;

    // Fee-only when the money landed in my own wallet — and also whenever
    // we can't prove otherwise (no beneficiary number, no amount, or no
    // number configured in settings): mis-recording a self-pull as spending
    // inflates the totals, which is the worse failure of the two.
    if (credited == null ||
        amount == null ||
        _ownNumberKeys.isEmpty ||
        isOwnNumber(credited)) {
      return _bankPullResult(
        pulledAmountText: amountMatch?.group(1),
        confirmationCode: eventMatch?.group(1),
        rawText: sms,
      );
    }

    final beneficiaryMatch = RegExp(
      r'Beneficiary\s*:\s*(.+?)\s*Credited\s*account',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(sms);
    final chargeMatch = RegExp(
      r'Transaction\s*Charge\s*:\s*RWF\s*([\d,]+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(sms);
    final beneficiary = beneficiaryMatch?.group(1)?.trim();

    return {
      'amount': amount,
      'recipient': toLocalPhone(credited),
      'status': 'success',
      'confirmationCode': eventMatch?.group(1),
      'fee': chargeMatch != null
          ? (double.tryParse(chargeMatch.group(1)!.replaceAll(',', '')) ??
              bkTransactionFee)
          : bkTransactionFee,
      'serviceKey': 'bk-ekash-send',
      'extraDetails': beneficiary != null && beneficiary.isNotEmpty
          ? 'eKash transfer to $beneficiary'
          : 'eKash transfer',
      'rawText': sms,
    };
  }

  static Map<String, dynamic> _bankPullResult({
    required String? pulledAmountText,
    required String? confirmationCode,
    required String rawText,
  }) {
    return {
      'amount': 0.0,
      'recipient': 'Bank of Kigali',
      'status': 'success',
      'confirmationCode': confirmationCode,
      'fee': bkTransactionFee,
      'serviceKey': 'bk-pull',
      'extraDetails': pulledAmountText != null
          ? 'Pulled $pulledAmountText RWF from bank'
          : 'Pull from bank',
      'rawText': rawText,
    };
  }

  /// Bank debit alert (e.g. BK) — a standalone completion message, not a
  /// MoMo transaction at all, so it never goes through `parseSms`/the
  /// generic MTN pipeline. Deliberately ignores "Available Balance" —
  /// only the debited amount and the transaction charge matter here.
  static Map<String, dynamic>? _parseBankDebit(String sms) {
    final amountMatch = RegExp(r'debited\s+RWF\s*([\d,]+(?:\.\d+)?)', caseSensitive: false)
        .firstMatch(sms);
    if (amountMatch == null) return null;

    final refMatch = RegExp(r'Ref:\s*([A-Za-z0-9]+)', caseSensitive: false).firstMatch(sms);
    final chargeMatch =
        RegExp(r'Txn Charge:\s*RWF\s*([\d,]+(?:\.\d+)?)', caseSensitive: false).firstMatch(sms);
    final descMatch =
        RegExp(r'Txn Description:\s*([^.]+)\.', caseSensitive: false).firstMatch(sms);
    final fee = chargeMatch != null
        ? double.tryParse(chargeMatch.group(1)!.replaceAll(',', ''))
        : null;

    // BK also fires this generic "has been debited" alert (from sender
    // "BK BANK") for its own EKASH self-transfer pull/push — e.g.
    // "Txn Description: EKASH P2P-NEW APP" — alongside the dedicated
    // bank-side pull SMS from a *different* sender ("BKeBANK"). Both share
    // the same Ref/Event # value, so tryMatchServiceEnrichment's refId
    // cross-match locks onto the *same* fee-only pull record either way.
    // Without this branch, the fallthrough below would report the full
    // debited amount, and since that record's amount is the "unknown, fill
    // it in" sentinel (0 — used by manual no-code BK Bank triggers), the
    // enrichment matcher would overwrite it with the pulled amount, turning
    // what should stay a fee-only record into a fake spend. Route it
    // through the pull result shape instead, with no amount to fill in.
    //
    // extraDetails is deliberately left null: this alert can't see the
    // beneficiary, so it can't tell a self-pull from a send to someone else.
    // The dedicated BKeBANK SMS owns the description either way ("Pulled X
    // RWF from bank" or "eKash transfer to NAME") and this one must not
    // overwrite it — nulling it also makes the enrichment a no-op for
    // self-pulls, which already carry the same text.
    if (descMatch != null && descMatch.group(1)!.toLowerCase().contains('ekash')) {
      return {
        'serviceKey': 'bk-pull',
        'extraDetails': null,
        'amount': null,
        'fee': fee ?? bkTransactionFee,
        'refId': refMatch?.group(1),
        'rawText': sms,
      };
    }

    final parts = <String>[];
    if (descMatch != null) parts.add(descMatch.group(1)!.trim());
    if (refMatch != null) parts.add('Ref: ${refMatch.group(1)}');

    return {
      'serviceKey': 'bk',
      'extraDetails': parts.isEmpty ? null : parts.join(' · '),
      'amount': double.tryParse(amountMatch.group(1)!.replaceAll(',', '')),
      'fee': fee,
      'refId': refMatch?.group(1),
      'rawText': sms,
    };
  }

  static Map<String, dynamic>? _parseFailureMessage(String sms) {
    final amountPattern = RegExp(r'(\d{1,3}(?:,\d{3})*|\d+)\s*RWF', caseSensitive: false);
    final match = amountPattern.firstMatch(sms);
    if (match == null) return null;
    final amount = double.tryParse(match.group(1)!.replaceAll(',', ''));
    if (amount == null) return null;
    return {
      'amount': amount,
      'recipient': _extractRecipient(sms),
      'status': 'failed',
      'failureReason': _extractFailureReason(sms),
      'rawText': sms,
    };
  }

  /// Returns the primary transaction amount, skipping any value that
  /// immediately follows a fee/balance/solde label.
  static double? _extractTransactionAmount(String sms) {
    final amountPattern = RegExp(r'(\d{1,3}(?:,\d{3})*|\d+)\s*RWF', caseSensitive: false);
    final allMatches = amountPattern.allMatches(sms).toList();
    if (allMatches.isEmpty) return null;

    // Collect positions where a fee/balance label ends.
    final labelPattern = RegExp(
      r'(?:fee|frais|balance|solde|new balance)\s*:?\s*',
      caseSensitive: false,
    );
    final labelEnds = labelPattern.allMatches(sms).map((m) => m.end).toSet();

    for (final match in allMatches) {
      final isAfterLabel = labelEnds.any(
        (end) => match.start >= end && match.start - end <= 15,
      );
      if (!isAfterLabel) {
        return double.tryParse(match.group(1)!.replaceAll(',', ''));
      }
    }
    // All amounts sit after labels — fall back to first.
    return double.tryParse(allMatches.first.group(1)!.replaceAll(',', ''));
  }

  static double? _extractFee(String sms) {
    final pattern = RegExp(
      r'(?:fee|frais)\s*:?\s*(\d{1,3}(?:,\d{3})*|\d+)\s*RWF',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(sms);
    if (match != null) return double.tryParse(match.group(1)!.replaceAll(',', ''));
    return null;
  }

  static String? _extractRecipient(String sms) {
    // Pattern 1: "transferred to NAME (PHONE)" or "sent to NAME (PHONE)"
    final p1 = RegExp(
      r'(?:transferred|sent)\s+to\s+([^(\n]+?)\s*\((\d+)\)',
      caseSensitive: false,
    );
    final m1 = p1.firstMatch(sms);
    if (m1 != null) return '${m1.group(1)!.trim()} (${m1.group(2)!.trim()})';

    // Pattern 2: "sent to NAME on …" / "sent to NAME."  (name, not a digit string)
    final p2 = RegExp(r'sent\s+to\s+([^(\n]{2,40}?)(?:\s+on\s|\s*[\.\n])', caseSensitive: false);
    final m2 = p2.firstMatch(sms);
    if (m2 != null) {
      final candidate = m2.group(1)!.trim();
      if (!RegExp(r'^\d+$').hasMatch(candidate)) return candidate;
    }

    // Pattern 3: bare Rwandan phone number right after "to "
    final p3 = RegExp(r'\bto\s+((?:250)?0?7[2389]\d{7})\b');
    final m3 = p3.firstMatch(sms);
    if (m3 != null) return m3.group(1)!;

    // Pattern 4: merchant / MoCode payment. "with" terminates the new eKash
    // format ("payment of X RWF to NAME with token and ET Id: ...").
    final p4 = RegExp(
      r'payment of.*?to\s+([A-Z][A-Za-z\s&.]+?)(?:\s+\d{6}|\s+was|\s+with\b)',
      caseSensitive: false,
    );
    final m4 = p4.firstMatch(sms);
    if (m4 != null) return m4.group(1)!.trim();

    // Pattern 5: Airtel eKash
    if (sms.toLowerCase().contains('ekash')) return 'eKash';

    return null;
  }

  static String? _extractConfirmationCode(String sms) {
    final patterns = [
      RegExp(r'TxId\s*:\s*(\d+)', caseSensitive: false),
      // ET Id value must contain a digit — the new eKash format can leave it
      // empty ("ET Id:  SUCCESSFUL at ..."), which would otherwise capture
      // the word "SUCCESSFUL" instead of falling through to TransactionId.
      RegExp(r'ET\s*Id\s*:\s*((?=[A-Za-z\-]*\d)[A-Za-z0-9\-]+)',
          caseSensitive: false),
      RegExp(r'Transaction\s*ID\s*:\s*(\d+)', caseSensitive: false),
      RegExp(r'Txn\s*ID\s*:\s*(\d+)', caseSensitive: false),
      RegExp(r'Ref(?:erence)?\s*(?:No\.?)?\s*:\s*([A-Z0-9]{6,})', caseSensitive: false),
      RegExp(r'\bID\s*:\s*(\d{6,})', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(sms);
      if (m != null) return m.group(1);
    }
    return null;
  }

  static String? _extractFailureReason(String sms) {
    final p1 = RegExp(r'with message:\s*(.+?)\s+failed', caseSensitive: false);
    final m1 = p1.firstMatch(sms);
    if (m1 != null) return m1.group(1)!.trim();

    final p2 = RegExp(r'[Rr]eason\s*:\s*(.+?)(?:\.|$)');
    final m2 = p2.firstMatch(sms);
    if (m2 != null) return m2.group(1)!.trim();

    final p3 = RegExp(r'declined[:\s]+(.+?)(?:\.|$)', caseSensitive: false);
    final m3 = p3.firstMatch(sms);
    if (m3 != null) return m3.group(1)!.trim();

    return null;
  }

  static String normalizePhoneNumber(String phone) {
    String normalized = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (normalized.startsWith('250') && normalized.length > 10) {
      normalized = normalized.substring(3);
    }
    return normalized;
  }

  static bool recipientMatches(String? smsRecipient, String transactionRecipient) {
    if (smsRecipient == null) return false;

    final smsN = smsRecipient.toLowerCase().trim();
    final txN = transactionRecipient.toLowerCase().trim();

    if (smsN == txN) return true;
    if (smsN.contains(txN) || txN.contains(smsN)) return true;

    final phonePattern = RegExp(r'\d{9,12}');
    final smsPhone = phonePattern.firstMatch(smsRecipient);
    final txPhone = phonePattern.firstMatch(transactionRecipient);
    if (smsPhone != null && txPhone != null) {
      return normalizePhoneNumber(smsPhone.group(0)!) ==
          normalizePhoneNumber(txPhone.group(0)!);
    }

    return false;
  }
}
