/// Shared validation/formatting helpers for MoMo recipients
/// (phone numbers and merchant momo codes).
///
/// The same logic also lives inline in `home.dart` and
/// `edit_ussd_record_dialog.dart`; new code should use this helper.
class RecipientHelper {
  static bool isValidPhoneNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.startsWith('25078') ||
        cleaned.startsWith('25079') ||
        cleaned.startsWith('25072') ||
        cleaned.startsWith('25073')) {
      return cleaned.length == 12;
    } else if (cleaned.startsWith('078') ||
        cleaned.startsWith('079') ||
        cleaned.startsWith('072') ||
        cleaned.startsWith('073')) {
      return cleaned.length == 10;
    } else if (cleaned.startsWith('78') ||
        cleaned.startsWith('79') ||
        cleaned.startsWith('72') ||
        cleaned.startsWith('73')) {
      return cleaned.length == 9;
    }

    return false;
  }

  static bool isValidMomoCode(String momoCode) {
    String cleaned = momoCode.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.length >= 3;
  }

  /// 'phone' or 'momo' for a valid input, null when it is neither.
  static String? detectRecipientType(String input) {
    final trimmed = input.trim();
    if (isValidPhoneNumber(trimmed)) return 'phone';
    if (isValidMomoCode(trimmed)) return 'momo';
    return null;
  }

  static String formatPhoneNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.startsWith('25078') ||
        cleaned.startsWith('25079') ||
        cleaned.startsWith('25072') ||
        cleaned.startsWith('25073')) {
      cleaned = '0${cleaned.substring(3)}';
    } else if (cleaned.startsWith('2507')) {
      cleaned = '0${cleaned.substring(3)}';
    } else if (cleaned.startsWith('78') ||
        cleaned.startsWith('79') ||
        cleaned.startsWith('72') ||
        cleaned.startsWith('73')) {
      cleaned = '0$cleaned';
    }

    if (cleaned.length == 10 &&
        (cleaned.startsWith('078') ||
            cleaned.startsWith('079') ||
            cleaned.startsWith('072') ||
            cleaned.startsWith('073'))) {
      return cleaned;
    }

    return '';
  }

  /// '1' for MTN (078/079), '2' for Airtel eKash (072/073).
  static String getServiceType(String phoneNumber) {
    final formatted = formatPhoneNumber(phoneNumber);
    final cleaned = formatted.isEmpty
        ? phoneNumber.replaceAll(RegExp(r'[^0-9]'), '')
        : formatted;

    if (cleaned.startsWith('072') || cleaned.startsWith('073')) {
      return '2'; // Airtel eKash
    }
    return '1'; // Default to MTN
  }

  static String maskPhoneNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.length >= 10) {
      String first = cleaned.substring(0, 3);
      String last = cleaned.substring(cleaned.length - 2);
      String masked = '*' * (cleaned.length - 5);
      return '$first$masked$last';
    }
    return phoneNumber;
  }

  /// Builds the dial string for a recipient, returning null when the
  /// recipient is not dialable (invalid, or a non-momo record).
  static String? buildUssdCode({
    required String recipient,
    required String recipientType,
    required String amount,
  }) {
    final input = recipient.trim();

    if (recipientType == 'phone' && isValidPhoneNumber(input)) {
      final formattedPhone = formatPhoneNumber(input);
      if (formattedPhone.isEmpty) return null;
      return '*182*1*${getServiceType(formattedPhone)}*$formattedPhone*$amount#';
    } else if (recipientType == 'momo' && isValidMomoCode(input)) {
      return '*182*8*1*${input.replaceAll(RegExp(r'[^0-9]'), '')}*$amount#';
    }

    return null;
  }

  /// The amount segment of an existing dial string (`*182*...*<amount>#`),
  /// so a rebuilt code keeps the exact amount the user originally dialed.
  static String? amountSegmentOf(String ussdCode) {
    final match = RegExp(r'\*(\d+)#$').firstMatch(ussdCode.trim());
    return match?.group(1);
  }
}
