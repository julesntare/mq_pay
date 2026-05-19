import '../models/ussd_record.dart';
import '../models/transaction_status.dart';
import 'sms_parser_service.dart';
import 'ussd_record_service.dart';

class TransactionMatcherService {
  /// Match a parsed SMS to a pending transaction.
  ///
  /// [timeWindowSeconds] — ignored when [requireSmsAfterTransaction] is true.
  /// [smsTimestamp]      — timestamp of the SMS; falls back to now.
  /// [requireSmsAfterTransaction] — when true, the SMS only needs to have
  ///   arrived *after* the transaction (±30 s tolerance), with no upper limit.
  ///   Use this for retry scans so backgrounded delays never block a match.
  static Future<UssdRecord?> matchSmsToTransaction(
    Map<String, dynamic> parsedSms, {
    int timeWindowSeconds = 300, // 5 minutes (was 60 s)
    DateTime? smsTimestamp,
    bool requireSmsAfterTransaction = false,
  }) async {
    final amount = parsedSms['amount'] as double?;
    final recipient = parsedSms['recipient'] as String?;
    final status = parsedSms['status'] as String;
    final smsFee = parsedSms['fee'] as double?;

    if (amount == null) return null;

    final allRecords = await UssdRecordService.getUssdRecords();
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 24));

    // Consider pending transactions from the last 24 hours (not just today).
    final pendingRecords = allRecords
        .where((r) =>
          r.status == TransactionStatus.pending &&
          r.timestamp.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final referenceTime = smsTimestamp ?? now;

    // Two-pass: prefer a match that also confirms the recipient.
    UssdRecord? bestMatch;
    bool bestHasRecipient = false;

    for (final record in pendingRecords) {
      final timeDiff = referenceTime.difference(record.timestamp).inSeconds;

      if (requireSmsAfterTransaction) {
        // SMS must arrive at or after the transaction (30 s tolerance for clock skew).
        if (timeDiff < -30) continue;
      } else {
        if (timeDiff.abs() > timeWindowSeconds) continue;
      }

      final amountMatches = _amountMatches(record.amount, amount) ||
          _feeInclusiveMatch(record.amount, record.fee, amount, smsFee);
      if (!amountMatches) continue;

      final hasRecipient = recipient != null &&
          (SmsParserService.recipientMatches(recipient, record.recipient) ||
           (record.contactName != null &&
            SmsParserService.recipientMatches(recipient, record.contactName!)));

      if (hasRecipient && !bestHasRecipient) {
        bestMatch = record;
        bestHasRecipient = true;
      } else if (bestMatch == null) {
        bestMatch = record;
      }

      if (bestHasRecipient) break; // Can't improve further.
    }

    if (bestMatch == null) return null;

    return bestMatch.copyWith(
      status: status == 'success' ? TransactionStatus.success : TransactionStatus.failed,
      confirmationCode: parsedSms['confirmationCode'] as String?,
      smsRawText: parsedSms['rawText'] as String?,
      statusUpdatedAt: DateTime.now(),
      fee: parsedSms['fee'] as double? ?? bestMatch.fee,
    );
  }

  static bool _amountMatches(double txAmount, double smsAmount) {
    return (txAmount - smsAmount).abs() <= 1.0;
  }

  /// Some operators report the total (amount + fee) in the SMS.
  /// Try that as a fallback before giving up on a match.
  static bool _feeInclusiveMatch(
      double txAmount, double? txFee, double smsAmount, double? smsFee) {
    if (txFee == null) return false;
    return ((txAmount + txFee) - smsAmount).abs() <= 1.0;
  }

  /// Parse sender/body, find a pending transaction, persist the update,
  /// and return the updated record (or null if nothing matched).
  static Future<UssdRecord?> processSms(String smsBody, String sender) async {
    if (!_isFromMobileMoney(sender)) return null;

    final parsedSms = SmsParserService.parseSms(smsBody);
    if (parsedSms == null) return null;

    final matchedRecord = await matchSmsToTransaction(parsedSms);
    if (matchedRecord == null) return null;

    await UssdRecordService.updateUssdRecord(matchedRecord);
    return matchedRecord;
  }

  static bool _isFromMobileMoney(String sender) {
    final s = sender.toLowerCase().trim();
    return s.contains('m-money') ||
        s.contains('mmoney') ||
        s.contains('mtn') ||
        s.contains('airtel') ||
        s.contains('ekash');
  }
}
