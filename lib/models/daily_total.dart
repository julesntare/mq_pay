import 'package:cloud_firestore/cloud_firestore.dart';

class DailyTotal {
  final String date;
  final double total;
  final DateTime sentAt;
  final double? totalWithFees;
  final int? recordCount;

  DailyTotal({
    required this.date,
    required this.total,
    required this.sentAt,
    this.totalWithFees,
    this.recordCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'total': total,
      'sent_at': Timestamp.fromDate(sentAt),
    };
  }

  factory DailyTotal.fromJson(Map<String, dynamic> json) {
    return DailyTotal(
      date: json['date'] as String,
      total: (json['total'] as num).toDouble(),
      sentAt: (json['sent_at'] as Timestamp).toDate(),
    );
  }
}
