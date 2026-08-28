import 'dart:convert';

/// A transaction a rule detected but didn't record.
///
/// A rule taught from a single message has been tested against a single
/// message, so its first matches wait here for a yes or no instead of landing
/// in the ledger. Approving one records it; the rule graduates once the user
/// says it can be trusted.
class TransactionSuggestion {
  final String id;
  final String ruleId;
  final String ruleLabel;
  final String sender;
  final String smsBody;
  final DateTime smsDate;

  /// The engine's parsed output, kept whole so accepting builds exactly the
  /// record an auto-detected transaction would have produced.
  final Map<String, dynamic> parsed;

  const TransactionSuggestion({
    required this.id,
    required this.ruleId,
    required this.ruleLabel,
    required this.sender,
    required this.smsBody,
    required this.smsDate,
    required this.parsed,
  });

  double? get amount => (parsed['amount'] as num?)?.toDouble();
  double? get fee => (parsed['fee'] as num?)?.toDouble();
  String? get recipient => parsed['recipient'] as String?;
  String? get confirmationCode => parsed['confirmationCode'] as String?;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ruleId': ruleId,
        'ruleLabel': ruleLabel,
        'sender': sender,
        'smsBody': smsBody,
        'smsDate': smsDate.toIso8601String(),
        'parsed': parsed,
      };

  factory TransactionSuggestion.fromJson(Map<String, dynamic> json) {
    return TransactionSuggestion(
      id: json['id'] as String,
      ruleId: json['ruleId'] as String? ?? '',
      ruleLabel: json['ruleLabel'] as String? ?? '',
      sender: json['sender'] as String? ?? '',
      smsBody: json['smsBody'] as String? ?? '',
      smsDate: DateTime.tryParse(json['smsDate'] as String? ?? '') ??
          DateTime.now(),
      parsed: Map<String, dynamic>.from(
        (json['parsed'] as Map?) ?? const {},
      ),
    );
  }

  String encode() => jsonEncode(toJson());
}
