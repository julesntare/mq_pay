import '../services/tariff_service.dart';

class UssdRecord {
  final String id;
  final String ussdCode;
  final String recipient;
  final String recipientType; // 'phone' or 'momo'
  final double amount;
  final DateTime timestamp;
  final String? maskedRecipient;
  final String? contactName;
  final String? reason;
  final double? fee; // Transaction fee

  UssdRecord({
    required this.id,
    required this.ussdCode,
    required this.recipient,
    required this.recipientType,
    required this.amount,
    required this.timestamp,
    this.maskedRecipient,
    this.contactName,
    this.reason,
    this.fee,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ussdCode': ussdCode,
      'recipient': recipient,
      'recipientType': recipientType,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'maskedRecipient': maskedRecipient,
      'contactName': contactName,
      'reason': reason,
      'fee': fee,
    };
  }

  factory UssdRecord.fromJson(Map<String, dynamic> json) {
    return UssdRecord(
      id: json['id'] as String,
      ussdCode: json['ussdCode'] as String,
      recipient: json['recipient'] as String,
      recipientType: json['recipientType'] as String,
      amount: (json['amount'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      maskedRecipient: json['maskedRecipient'] as String?,
      contactName: json['contactName'] as String?,
      reason: json['reason'] as String?,
      fee: json['fee'] != null ? (json['fee'] as num).toDouble() : null,
    );
  }

  UssdRecord copyWith({
    String? id,
    String? ussdCode,
    String? recipient,
    String? recipientType,
    double? amount,
    DateTime? timestamp,
    String? maskedRecipient,
    String? contactName,
    String? reason,
    double? fee,
  }) {
    return UssdRecord(
      id: id ?? this.id,
      ussdCode: ussdCode ?? this.ussdCode,
      recipient: recipient ?? this.recipient,
      recipientType: recipientType ?? this.recipientType,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      maskedRecipient: maskedRecipient ?? this.maskedRecipient,
      contactName: contactName ?? this.contactName,
      reason: reason ?? this.reason,
      fee: fee ?? this.fee,
    );
  }

  /// Extract service type from USSD code
  /// Returns '1' for MoMo Phone, '2' for MoMo eKash, null for MoMo codes or unknown
  String? _extractServiceTypeFromUssdCode() {
    // Pattern: *182*1*{serviceType}*{phone}*{amount}#
    final phonePattern = RegExp(r'\*182\*1\*(\d+)\*');
    final match = phonePattern.firstMatch(ussdCode);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }

  /// Calculate the transaction fee dynamically based on tariff rules
  /// If fee is already saved, returns that; otherwise calculates from tariff rules
  double calculateFee() {
    // If fee is already saved, use it
    if (fee != null) {
      return fee!;
    }

    // For MoMo code transactions, fee is always 0
    if (recipientType == 'momo') {
      return 0.0;
    }

    // For phone transactions, extract service type from USSD code
    final serviceType = _extractServiceTypeFromUssdCode();

    return TariffService.calculateTransactionFee(
      amount: amount,
      recipientType: recipientType,
      serviceType: serviceType,
    );
  }
}
