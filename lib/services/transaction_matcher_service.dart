import '../models/ussd_record.dart';
import '../models/transaction_status.dart';
import 'sms_parser_service.dart';
import 'ussd_record_service.dart';

class TransactionMatcherService {
  /// Match SMS to pending transactions within a time window
  /// Returns the updated transaction if matched, null otherwise
  static Future<UssdRecord?> matchSmsToTransaction(
    Map<String, dynamic> parsedSms,
  ) async {
    final amount = parsedSms['amount'] as double?;
    final recipient = parsedSms['recipient'] as String?;
    final status = parsedSms['status'] as String;

    if (amount == null) {
      return null;
    }

    // Get all pending transactions from today only
    final allRecords = await UssdRecordService.getUssdRecords();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final pendingRecords = allRecords
        .where((record) =>
          record.status == TransactionStatus.pending &&
          record.timestamp.isAfter(today)
        )
        .toList();

    // Sort by timestamp (most recent first)
    pendingRecords.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Find matching transaction within 60 seconds
    for (final record in pendingRecords) {
      final timeDifference = now.difference(record.timestamp).inSeconds;

      // Skip if outside time window
      if (timeDifference > 60) {
        continue;
      }

      // Check if amount matches
      final amountMatches = _amountMatches(record.amount, amount);

      // Check if recipient matches (partial match)
      final recipientMatches = recipient == null ||
          SmsParserService.recipientMatches(recipient, record.recipient) ||
          (record.contactName != null &&
              SmsParserService.recipientMatches(recipient, record.contactName!));

      if (amountMatches && recipientMatches) {
        // Match found! Update the transaction
        final updatedRecord = record.copyWith(
          status: status == 'success'
              ? TransactionStatus.success
              : TransactionStatus.failed,
          confirmationCode: parsedSms['confirmationCode'] as String?,
          smsRawText: parsedSms['rawText'] as String?,
          statusUpdatedAt: DateTime.now(),
          // Update fee if provided in SMS (for verification)
          fee: parsedSms['fee'] as double? ?? record.fee,
        );

        return updatedRecord;
      }
    }

    return null;
  }

  /// Check if amounts match (allowing small rounding differences)
  static bool _amountMatches(double transactionAmount, double smsAmount) {
    // Exact match
    if (transactionAmount == smsAmount) {
      return true;
    }

    // Allow for small rounding errors (within 1 RWF)
    final difference = (transactionAmount - smsAmount).abs();
    return difference <= 1.0;
  }

  /// Process SMS and update matching transaction
  static Future<bool> processSms(String smsBody, String sender) async {
    // Only process SMS from Mobile Money
    if (!_isFromMobileMoney(sender)) {
      return false;
    }

    // Parse the SMS
    final parsedSms = SmsParserService.parseSms(smsBody);
    if (parsedSms == null) {
      return false;
    }

    // Match to a pending transaction
    final matchedRecord = await matchSmsToTransaction(parsedSms);
    if (matchedRecord == null) {
      return false;
    }

    // Update the transaction in storage
    await UssdRecordService.updateUssdRecord(matchedRecord);

    return true;
  }

  /// Check if sender is Mobile Money
  static bool _isFromMobileMoney(String sender) {
    final normalizedSender = sender.toLowerCase().trim();
    return normalizedSender.contains('m-money') ||
        normalizedSender.contains('mmoney') ||
        normalizedSender.contains('mtn');
  }
}
