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
    final merchantName = parsedSms['merchantName'] as String?;

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

      final hasRecipient = (recipient != null &&
              (SmsParserService.recipientMatches(recipient, record.recipient) ||
               (record.contactName != null &&
                SmsParserService.recipientMatches(recipient, record.contactName!)))) ||
          _merchantNameMatches(merchantName, record.recipient);

      // Manual-trigger service records (e.g. Yego Cab) can be saved with an
      // unknown amount (sentinel <= 0), to be filled in from whichever SMS
      // matches. Since there's no amount to compare, a recipient/merchant
      // signal is required instead — otherwise any SMS in the time window
      // would match.
      final amountUnknown =
          record.recipientType == 'misc' && record.serviceKey != null && record.amount <= 0;
      final amountMatches = amountUnknown
          ? hasRecipient
          : (_amountMatches(record.amount, amount) ||
              _feeInclusiveMatch(record.amount, record.fee, amount, smsFee));
      if (!amountMatches) continue;

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
      amount: bestMatch.amount <= 0 ? amount : bestMatch.amount,
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

  /// Loose match between a merchant name extracted from a "by X was
  /// completed" SMS and the pending record's recipient/service label.
  /// Best-effort tie-breaker only — merchant names in these receipts are
  /// often the settlement bank/processor rather than the consumer brand,
  /// so this is never required for a match, only used to prefer one.
  static bool _merchantNameMatches(String? merchantName, String recordRecipient) {
    if (merchantName == null || merchantName.isEmpty) return false;
    final m = merchantName.toLowerCase().trim();
    final r = recordRecipient.toLowerCase().trim();
    if (r.isEmpty) return false;
    if (m.contains(r) || r.contains(m)) return true;

    // Word-level overlap fallback — full-string containment is too strict
    // when a service's display label differs from the SMS's registered
    // company name (e.g. "Yego Cab" vs "Yego Innovision Ltd").
    final mWords = m.split(RegExp(r'\s+')).where((w) => w.length >= 4).toSet();
    final rWords = r.split(RegExp(r'\s+')).where((w) => w.length >= 4).toSet();
    return mWords.intersection(rWords).isNotEmpty;
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

  /// Try to match a delayed, service-specific enrichment SMS (Cash Power
  /// token, Canalbox renewal, Umutekano confirmation) against a record —
  /// pending or already-success — and attach the enrichment text.
  /// Not sender-gated: called for any SMS the standard debit-receipt parser
  /// (`processSms`) didn't already resolve.
  static Future<UssdRecord?> tryMatchServiceEnrichment(
    String smsBody, {
    DateTime? smsTimestamp,
    String? sender,
  }) async {
    final enrichment =
        SmsParserService.detectServiceEnrichment(smsBody, sender: sender);
    if (enrichment == null) return null;

    final serviceKey = enrichment['serviceKey'] as String;
    final extraDetails = enrichment['extraDetails'] as String?;
    final refId = enrichment['refId'] as String?;
    final enrichedAmount = enrichment['amount'] as double?;
    final enrichedFee = enrichment['fee'] as double?;

    final allRecords = await UssdRecordService.getUssdRecords();
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 24));
    final candidates = allRecords
        .where((r) => r.timestamp.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    UssdRecord? target;

    // Highest confidence: exact reference-ID cross-match (e.g. Umutekano's
    // TRID equals the ET Id already captured from the stage-1 SMS).
    if (refId != null) {
      target = candidates.cast<UssdRecord?>().firstWhere(
            (r) => r!.confirmationCode == refId,
            orElse: () => null,
          );
    }

    // Fall back to the most recent record tagged with this service.
    target ??= candidates.cast<UssdRecord?>().firstWhere(
          (r) => r!.serviceKey == serviceKey,
          orElse: () => null,
        );

    if (target == null) return null;

    // Fill in amount/fee only where the record doesn't already have them —
    // manual-trigger services (e.g. Yego Cab, BK) may have been saved with
    // an unknown amount (sentinel <= 0) or no fee, to be completed here.
    final newAmount =
        (target.amount <= 0 && enrichedAmount != null) ? enrichedAmount : target.amount;
    final newFee = enrichedFee ?? target.fee;
    final newConfirmationCode = target.confirmationCode ?? refId;
    final newExtraDetails = extraDetails ?? target.extraDetails;
    final newStatus = target.status == TransactionStatus.pending
        ? TransactionStatus.success
        : target.status;

    // Nothing would actually change — avoid re-matching the same SMS on
    // every subsequent scan (would otherwise re-fire a notification and
    // rewrite the record on every app resume within the 24h lookback).
    final noChange = newAmount == target.amount &&
        newFee == target.fee &&
        newConfirmationCode == target.confirmationCode &&
        newExtraDetails == target.extraDetails &&
        newStatus == target.status;
    if (noChange) return null;

    final updated = target.copyWith(
      amount: newAmount,
      fee: newFee,
      applyFee: enrichedFee != null ? true : target.applyFee,
      confirmationCode: newConfirmationCode,
      extraDetails: newExtraDetails,
      status: newStatus,
      statusUpdatedAt: now,
    );

    await UssdRecordService.updateUssdRecord(updated);
    return updated;
  }

  static bool _isFromMobileMoney(String sender) =>
      SmsParserService.isFromMobileMoney(sender);
}
