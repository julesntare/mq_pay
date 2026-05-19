class SmsParserService {
  static Map<String, dynamic>? parseSms(String smsBody) {
    final cleaned = smsBody.trim();
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
        lower.contains('successfully') ||
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

    // Pattern 4: merchant / MoCode payment
    final p4 = RegExp(
      r'payment of.*?to\s+([A-Z][A-Za-z\s&.]+?)(?:\s+\d{6}|\s+was)',
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
      RegExp(r'ET\s*Id\s*:\s*(\d+)', caseSensitive: false),
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
