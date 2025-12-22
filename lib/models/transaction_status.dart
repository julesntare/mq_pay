enum TransactionStatus {
  pending,
  success,
  failed,
}

extension TransactionStatusExtension on TransactionStatus {
  String get displayName {
    switch (this) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.success:
        return 'Success';
      case TransactionStatus.failed:
        return 'Failed';
    }
  }

  String toJson() {
    return name;
  }

  static TransactionStatus fromJson(String value) {
    return TransactionStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TransactionStatus.pending,
    );
  }
}
