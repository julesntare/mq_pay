import '../services/tariff_service.dart';
import 'transaction_status.dart';

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
  final bool applyFee; // Whether to apply fee to this transaction
  final TransactionStatus status; // Transaction status
  final String? confirmationCode; // Reference/Transaction ID from SMS
  final String? smsRawText; // Raw SMS text for debugging
  final DateTime? statusUpdatedAt; // When status was last updated

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
    this.applyFee = true, // Default to true for backward compatibility
    this.status = TransactionStatus.pending, // Default to pending
    this.confirmationCode,
    this.smsRawText,
    this.statusUpdatedAt,
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
      'applyFee': applyFee,
      'status': status.toJson(),
      'confirmationCode': confirmationCode,
      'smsRawText': smsRawText,
      'statusUpdatedAt': statusUpdatedAt?.toIso8601String(),
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
      applyFee:
          json['applyFee'] as bool? ?? true, // Default to true for old records
      status: json['status'] != null
          ? TransactionStatusExtension.fromJson(json['status'] as String)
          : TransactionStatus.pending,
      confirmationCode: json['confirmationCode'] as String?,
      smsRawText: json['smsRawText'] as String?,
      statusUpdatedAt: json['statusUpdatedAt'] != null
          ? DateTime.parse(json['statusUpdatedAt'] as String)
          : null,
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
    bool? applyFee,
    TransactionStatus? status,
    String? confirmationCode,
    String? smsRawText,
    DateTime? statusUpdatedAt,
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
      applyFee: applyFee ?? this.applyFee,
      status: status ?? this.status,
      confirmationCode: confirmationCode ?? this.confirmationCode,
      smsRawText: smsRawText ?? this.smsRawText,
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
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
  /// Returns 0 if applyFee is false
  double calculateFee() {
    // If user chose not to apply fee, return 0
    if (!applyFee) {
      return 0.0;
    }

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
