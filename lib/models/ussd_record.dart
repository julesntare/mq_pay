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
  final bool failed;

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
    this.failed = false,
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
      'failed': failed,
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
      failed: json['failed'] == null ? false : (json['failed'] as bool),
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
    bool? failed,
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
      failed: failed ?? this.failed,
    );
  }
}
