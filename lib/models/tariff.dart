class TariffBracket {
  final double min;
  final double max;
  final double fee;

  const TariffBracket({
    required this.min,
    required this.max,
    required this.fee,
  });
}

enum TariffType {
  momoPhone,
  momoEkash,
}

class MomoTariff {
  // MoMo Phone tariffs (*182*1*1*...)
  static const List<TariffBracket> phoneTariffs = [
    TariffBracket(min: 1, max: 1000, fee: 20),
    TariffBracket(min: 1001, max: 10000, fee: 100),
    TariffBracket(min: 10001, max: 150000, fee: 250),
    TariffBracket(min: 150001, max: 2000000, fee: 1500),
    TariffBracket(min: 2000001, max: 5000000, fee: 3000),
    TariffBracket(min: 5000001, max: 10000000, fee: 5000),
  ];

  // MoMo eKash tariffs (*182*1*2*... or MoMo code *182*8*1*...)
  static const List<TariffBracket> ekashTariffs = [
    TariffBracket(min: 1, max: 1000, fee: 100),
    TariffBracket(min: 1001, max: 10000, fee: 200),
    TariffBracket(min: 10001, max: 150000, fee: 350),
    TariffBracket(min: 150001, max: 2000000, fee: 1600),
    TariffBracket(min: 2000001, max: 5000000, fee: 3000),
    TariffBracket(min: 5000001, max: 10000000, fee: 5000),
  ];

  /// Calculate fee based on amount and tariff type
  static double calculateFee(double amount, TariffType type) {
    final tariffs = type == TariffType.momoPhone ? phoneTariffs : ekashTariffs;

    for (final bracket in tariffs) {
      if (amount >= bracket.min && amount <= bracket.max) {
        return bracket.fee;
      }
    }

    // If amount exceeds maximum bracket, return the highest fee
    return tariffs.last.fee;
  }

  /// Get total amount (original amount + fee)
  static double getTotalAmount(double amount, TariffType type) {
    return amount + calculateFee(amount, type);
  }

  /// Get formatted fee string
  static String getFormattedFee(double amount, TariffType type) {
    final fee = calculateFee(amount, type);
    return 'RWF ${fee.toStringAsFixed(0)}';
  }

  /// Get formatted total amount string
  static String getFormattedTotal(double amount, TariffType type) {
    final total = getTotalAmount(amount, type);
    return 'RWF ${total.toStringAsFixed(0)}';
  }

  /// Get tariff bracket for an amount
  static TariffBracket? getTariffBracket(double amount, TariffType type) {
    final tariffs = type == TariffType.momoPhone ? phoneTariffs : ekashTariffs;

    for (final bracket in tariffs) {
      if (amount >= bracket.min && amount <= bracket.max) {
        return bracket;
      }
    }

    return null;
  }
}
