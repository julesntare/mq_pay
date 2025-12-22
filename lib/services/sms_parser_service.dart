class SmsParserService {
  /// Parse SMS from Mobile Money and extract transaction details
  static Map<String, dynamic>? parseSms(String smsBody) {
    // Clean up the SMS text
    final cleanedSms = smsBody.trim();

    // Try to determine if it's a success or failure message
    final bool isSuccess = _isSuccessMessage(cleanedSms);
    final bool isFailure = _isFailureMessage(cleanedSms);

    if (!isSuccess && !isFailure) {
      // Not a transaction SMS we care about
      return null;
    }

    // Extract data based on message type
    if (isSuccess) {
      return _parseSuccessMessage(cleanedSms);
    } else {
      return _parseFailureMessage(cleanedSms);
    }
  }

  /// Check if SMS indicates success
  static bool _isSuccessMessage(String sms) {
    return sms.contains('*S*') ||
        sms.contains('transferred to') ||
        sms.contains('was completed');
  }

  /// Check if SMS indicates failure
  static bool _isFailureMessage(String sms) {
    return sms.contains('*R*') || sms.contains('failed');
  }

  /// Parse success message and extract details
  static Map<String, dynamic>? _parseSuccessMessage(String sms) {
    double? amount;
    String? recipient;
    String? confirmationCode;
    double? fee;

    // Extract amount (handles both "5000 RWF" and "41,831 RWF")
    final amountPattern = RegExp(r'(\d{1,3}(?:,\d{3})*|\d+)\s*RWF');
    final amountMatches = amountPattern.allMatches(sms).toList();

    if (amountMatches.isNotEmpty) {
      // First match is usually the transaction amount
      final amountStr = amountMatches[0].group(1)!.replaceAll(',', '');
      amount = double.tryParse(amountStr);
    }

    // Extract fee
    // Patterns: "Fee : 100 RWF" or "Fee 0 RWF" or "Fee: 100"
    final feePattern = RegExp(r'Fee\s*:?\s*(\d+)\s*RWF', caseSensitive: false);
    final feeMatch = feePattern.firstMatch(sms);
    if (feeMatch != null) {
      fee = double.tryParse(feeMatch.group(1)!);
    }

    // Extract recipient - multiple patterns
    // Pattern 1: "transferred to NAME (PHONE)"
    final recipientPattern1 = RegExp(r'transferred to ([^(]+)\s*\((\d+)\)');
    final recipientMatch1 = recipientPattern1.firstMatch(sms);
    if (recipientMatch1 != null) {
      final name = recipientMatch1.group(1)!.trim();
      final phone = recipientMatch1.group(2)!.trim();
      recipient = '$name ($phone)';
    }

    // Pattern 2: "payment of X RWF to MERCHANT_NAME CODE"
    if (recipient == null) {
      final recipientPattern2 = RegExp(
        r'payment of.*?to\s+([A-Z][A-Za-z\s&.]+?)(?:\s+\d{6}|\s+was)',
      );
      final recipientMatch2 = recipientPattern2.firstMatch(sms);
      if (recipientMatch2 != null) {
        recipient = recipientMatch2.group(1)!.trim();
      }
    }

    // Pattern 3: "to eKash"
    if (recipient == null && sms.contains('eKash')) {
      recipient = 'eKash';
    }

    // Extract confirmation/transaction code
    // Pattern: "TxId:12345678"
    final txIdPattern = RegExp(r'TxId:(\d+)');
    final txIdMatch = txIdPattern.firstMatch(sms);
    if (txIdMatch != null) {
      confirmationCode = txIdMatch.group(1);
    }

    // Pattern: "ET Id: 12345678"
    if (confirmationCode == null) {
      final etIdPattern = RegExp(r'ET Id:\s*(\d+)');
      final etIdMatch = etIdPattern.firstMatch(sms);
      if (etIdMatch != null) {
        confirmationCode = etIdMatch.group(1);
      }
    }

    // Return parsed data
    if (amount != null) {
      return {
        'amount': amount,
        'recipient': recipient,
        'status': 'success',
        'confirmationCode': confirmationCode,
        'fee': fee,
        'rawText': sms,
      };
    }

    return null;
  }

  /// Parse failure message and extract details
  static Map<String, dynamic>? _parseFailureMessage(String sms) {
    double? amount;
    String? recipient;
    String? failureReason;

    // Extract amount
    final amountPattern = RegExp(r'(\d{1,3}(?:,\d{3})*|\d+)\s*RWF');
    final amountMatch = amountPattern.firstMatch(sms);
    if (amountMatch != null) {
      final amountStr = amountMatch.group(1)!.replaceAll(',', '');
      amount = double.tryParse(amountStr);
    }

    // Extract recipient
    // Pattern: "for RECIPIENT with message:"
    final recipientPattern = RegExp(r'for\s+(.+?)\s+with message:');
    final recipientMatch = recipientPattern.firstMatch(sms);
    if (recipientMatch != null) {
      recipient = recipientMatch.group(1)!.trim();
    }

    // Extract failure reason
    // Pattern: "with message: REASON failed"
    final reasonPattern = RegExp(r'with message:\s*(.+?)\s+failed');
    final reasonMatch = reasonPattern.firstMatch(sms);
    if (reasonMatch != null) {
      failureReason = reasonMatch.group(1)!.trim();
    }

    // Return parsed data
    if (amount != null) {
      return {
        'amount': amount,
        'recipient': recipient,
        'status': 'failed',
        'failureReason': failureReason,
        'rawText': sms,
      };
    }

    return null;
  }

  /// Normalize phone number for comparison (remove country code prefix if present)
  static String normalizePhoneNumber(String phone) {
    // Remove spaces, dashes, parentheses
    String normalized = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Remove country code if present (250 for Rwanda)
    if (normalized.startsWith('250') && normalized.length > 10) {
      normalized = normalized.substring(3);
    }

    return normalized;
  }

  /// Check if recipient matches (handles partial matching)
  static bool recipientMatches(String? smsRecipient, String transactionRecipient) {
    if (smsRecipient == null) return false;

    // Normalize both strings for comparison
    final smsNormalized = smsRecipient.toLowerCase().trim();
    final transactionNormalized = transactionRecipient.toLowerCase().trim();

    // Exact match
    if (smsNormalized == transactionNormalized) return true;

    // Check if SMS recipient contains transaction recipient or vice versa
    if (smsNormalized.contains(transactionNormalized) ||
        transactionNormalized.contains(smsNormalized)) {
      return true;
    }

    // Extract and compare phone numbers if present
    final phonePattern = RegExp(r'\d{9,12}');
    final smsPhone = phonePattern.firstMatch(smsRecipient);
    final transactionPhone = phonePattern.firstMatch(transactionRecipient);

    if (smsPhone != null && transactionPhone != null) {
      final smsPhoneNormalized = normalizePhoneNumber(smsPhone.group(0)!);
      final transactionPhoneNormalized = normalizePhoneNumber(transactionPhone.group(0)!);

      return smsPhoneNormalized == transactionPhoneNormalized;
    }

    return false;
  }
}
