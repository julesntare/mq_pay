import 'package:flutter/foundation.dart';

/// Service to detect keywords in USSD responses and determine transaction validity
class UssdKeywordDetector {
  // Success keywords - transaction should be saved
  static const List<String> _successKeywords = [
    'you have sent',
    'thank you for using mtn mobile money',
    'ekash',
    'successful',
    'completed',
    'transferred',
    'confirmed',
    'payment of',
    'transaction completed',
  ];

  // Failure keywords - transaction should NOT be saved
  static const List<String> _failureKeywords = [
    'not enough funds to perform transaction',
    'insufficient funds',
    'insufficient balance',
    'failed',
    'cancelled',
    'rejected',
    'invalid',
    'error',
    'unable to',
    'transaction failed',
  ];

  /// Validates if a USSD response text should trigger saving a transaction
  ///
  /// Returns:
  /// - true: Response contains success keywords, save transaction
  /// - false: Response contains failure keywords or no success keywords, DO NOT save
  static bool shouldSaveTransaction(String ussdResponse) {
    if (ussdResponse.isEmpty) {
      debugPrint('[UssdKeywordDetector] Empty USSD response - NOT saving');
      return false;
    }

    final lowerResponse = ussdResponse.toLowerCase();

    // First check for failure keywords - these take priority
    for (final keyword in _failureKeywords) {
      if (lowerResponse.contains(keyword)) {
        debugPrint('[UssdKeywordDetector] Failure keyword detected: "$keyword" - NOT saving');
        return false;
      }
    }

    // Then check for success keywords
    for (final keyword in _successKeywords) {
      if (lowerResponse.contains(keyword)) {
        debugPrint('[UssdKeywordDetector] Success keyword detected: "$keyword" - SAVING transaction');
        return true;
      }
    }

    // No success keywords found - treat as failed transaction
    debugPrint('[UssdKeywordDetector] No success keywords found - NOT saving');
    return false;
  }

  /// Checks if the response indicates a successful transaction
  static bool isSuccessResponse(String ussdResponse) {
    final lowerResponse = ussdResponse.toLowerCase();

    return _successKeywords.any((keyword) => lowerResponse.contains(keyword)) &&
           !_failureKeywords.any((keyword) => lowerResponse.contains(keyword));
  }

  /// Checks if the response indicates a failed transaction
  static bool isFailureResponse(String ussdResponse) {
    final lowerResponse = ussdResponse.toLowerCase();

    return _failureKeywords.any((keyword) => lowerResponse.contains(keyword));
  }

  /// Extracts the failure reason from a USSD response (if any)
  static String? extractFailureReason(String ussdResponse) {
    final lowerResponse = ussdResponse.toLowerCase();

    for (final keyword in _failureKeywords) {
      if (lowerResponse.contains(keyword)) {
        return keyword;
      }
    }

    return null;
  }

  /// Logs the validation result for debugging
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
