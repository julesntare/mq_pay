import '../models/tariff.dart';

class TariffService {
  /// Determine tariff type based on recipient type and service type
  ///
  /// For phone numbers:
  /// - serviceType '1' = MTN MoMo Phone (*182*1*1*...) -> momoPhone tariffs
  /// - serviceType '2' = Airtel MoMo eKash (*182*1*2*...) -> momoEkash tariffs
  ///
  /// For MoMo codes:
  /// - No fee applied (*182*8*1*...) -> 0 RWF
  static TariffType getTariffType({
    required String recipientType,
    String? serviceType,
  }) {
    if (recipientType == 'phone') {
      // Phone transactions depend on service type
      if (serviceType == '1') {
        // MTN MoMo Phone
        return TariffType.momoPhone;
      } else if (serviceType == '2') {
        // Airtel MoMo eKash
        return TariffType.momoEkash;
      }
    }

    // Default to phone tariffs for unknown types
    return TariffType.momoPhone;
  }

  /// Calculate fee for a transaction
  static double calculateTransactionFee({
    required double amount,
    required String recipientType,
    String? serviceType,
  }) {
    // MoMo code transactions have no fee
    if (recipientType == 'momo') {
      return 0.0;
    }

    final tariffType = getTariffType(
      recipientType: recipientType,
      serviceType: serviceType,
    );

    return MomoTariff.calculateFee(amount, tariffType);
  }

  /// Get total amount including fee
  static double getTotalTransactionAmount({
    required double amount,
    required String recipientType,
    String? serviceType,
  }) {
    // MoMo code transactions have no fee
    if (recipientType == 'momo') {
      return amount;
    }

    final tariffType = getTariffType(
      recipientType: recipientType,
      serviceType: serviceType,
    );

    return MomoTariff.getTotalAmount(amount, tariffType);
  }

  /// Get formatted fee breakdown for display
  static Map<String, dynamic> getFeeBreakdown({
    required double amount,
    required String recipientType,
    String? serviceType,
  }) {
    // MoMo code transactions have no fee
    if (recipientType == 'momo') {
      return {
        'amount': amount,
        'fee': 0.0,
        'total': amount,
        'tariffType': 'MoMo Code (No Fee)',
        'bracketMin': null,
        'bracketMax': null,
        'formattedAmount': 'RWF ${amount.toStringAsFixed(0)}',
        'formattedFee': 'RWF 0',
        'formattedTotal': 'RWF ${amount.toStringAsFixed(0)}',
      };
    }

    final tariffType = getTariffType(
      recipientType: recipientType,
      serviceType: serviceType,
    );

    final fee = MomoTariff.calculateFee(amount, tariffType);
    final total = amount + fee;
    final bracket = MomoTariff.getTariffBracket(amount, tariffType);

    return {
      'amount': amount,
      'fee': fee,
      'total': total,
      'tariffType': tariffType == TariffType.momoPhone ? 'MoMo Phone' : 'MoMo eKash',
      'bracketMin': bracket?.min,
      'bracketMax': bracket?.max,
      'formattedAmount': 'RWF ${amount.toStringAsFixed(0)}',
      'formattedFee': 'RWF ${fee.toStringAsFixed(0)}',
      'formattedTotal': 'RWF ${total.toStringAsFixed(0)}',
    };
  }

  /// Check if amount is within valid range
  static bool isValidAmount(double amount) {
    return amount >= 1 && amount <= 10000000;
  }

  /// Get minimum transaction amount
  static double getMinAmount() {
    return MomoTariff.phoneTariffs.first.min;
  }

  /// Get maximum transaction amount
  static double getMaxAmount() {
    return MomoTariff.phoneTariffs.last.max;
  }
}
