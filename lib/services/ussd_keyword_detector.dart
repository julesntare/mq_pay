import 'package:flutter/foundation.dart';

class UssdKeywordDetector {
  static const List<String> _successKeywords = [
    // English
    'you have sent',
    'you have transferred',
    'has been sent',
    'has been transferred',
    'thank you for using mtn mobile money',
    'ekash',
    'successful',
    'completed',
    'transferred',
    'confirmed',
    'payment of',
    'transaction completed',
    'transaction id',  // confirmation reference shown on success
    'please keep',    // "Please keep this as proof of payment"
    'your payment',
    // French (MTN Rwanda bilingual SMS)
    'avez transféré',
    'effectué',
    'confirmé',
    'réussi',
  ];

  static const List<String> _failureKeywords = [
    // English
    'not enough funds to perform transaction',
    'insufficient funds',
    'insufficient balance',
    'insufficient',
    'failed',
    'cancelled',
    'rejected',
    'invalid',
    'error',
    'unable to',
    'transaction failed',
    'account not found',
    'not registered',
    'does not exist',
    'session expired',
    'service unavailable',
    'try again later',
    'wrong pin',
    'incorrect pin',
    // French
    'fonds insuffisants',
    'refusé',
    'échec',
  ];

  /// Returns true if the USSD response indicates a successful transaction.
  static bool shouldSaveTransaction(String ussdResponse) {
    if (ussdResponse.isEmpty) {
      debugPrint('[UssdKeywordDetector] Empty USSD response - NOT saving');
      return false;
    }

    final lower = ussdResponse.toLowerCase();

    for (final keyword in _failureKeywords) {
      if (lower.contains(keyword)) {
        debugPrint('[UssdKeywordDetector] Failure keyword detected: "$keyword" - NOT saving');
        return false;
      }
    }

    for (final keyword in _successKeywords) {
      if (lower.contains(keyword)) {
        debugPrint('[UssdKeywordDetector] Success keyword detected: "$keyword" - SAVING transaction');
        return true;
      }
    }

    debugPrint('[UssdKeywordDetector] No success keywords found - NOT saving');
    return false;
  }

  /// Tri-state detection: 'success', 'failure', or 'unknown'.
  static String detectTransactionResult(String ussdResponse) {
    if (ussdResponse.isEmpty) {
      debugPrint('[UssdKeywordDetector] Empty USSD response - unknown');
      return 'unknown';
    }

    final lower = ussdResponse.toLowerCase();

    for (final keyword in _failureKeywords) {
      if (lower.contains(keyword)) {
        debugPrint('[UssdKeywordDetector] Failure keyword detected: "$keyword"');
        return 'failure';
      }
    }

    for (final keyword in _successKeywords) {
      if (lower.contains(keyword)) {
        debugPrint('[UssdKeywordDetector] Success keyword detected: "$keyword"');
        return 'success';
      }
    }

    debugPrint('[UssdKeywordDetector] No keywords found - unknown');
    return 'unknown';
  }

  static bool isSuccessResponse(String ussdResponse) {
    final lower = ussdResponse.toLowerCase();
    return _successKeywords.any((k) => lower.contains(k)) &&
        !_failureKeywords.any((k) => lower.contains(k));
  }

  static bool isFailureResponse(String ussdResponse) {
    final lower = ussdResponse.toLowerCase();
    return _failureKeywords.any((k) => lower.contains(k));
  }

  static String? extractFailureReason(String ussdResponse) {
    final lower = ussdResponse.toLowerCase();
    for (final keyword in _failureKeywords) {
      if (lower.contains(keyword)) return keyword;
    }
    return null;
  }

  static void logValidation(String ussdResponse, bool shouldSave) {
    debugPrint('=== USSD Keyword Validation ===');
    debugPrint('Response: $ussdResponse');
    debugPrint('Should Save: $shouldSave');
    debugPrint('Is Success: ${isSuccessResponse(ussdResponse)}');
    debugPrint('Is Failure: ${isFailureResponse(ussdResponse)}');
    if (isFailureResponse(ussdResponse)) {
      debugPrint('Failure Reason: ${extractFailureReason(ussdResponse)}');
    }
    debugPrint('==============================');
  }
}
