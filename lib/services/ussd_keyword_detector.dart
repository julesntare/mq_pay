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
    'transaction id',
    'please keep',
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

  static bool shouldSaveTransaction(String ussdResponse) {
    if (ussdResponse.isEmpty) return false;
    final lower = ussdResponse.toLowerCase();
    if (_failureKeywords.any((k) => lower.contains(k))) return false;
    return _successKeywords.any((k) => lower.contains(k));
  }

  static String detectTransactionResult(String ussdResponse) {
    if (ussdResponse.isEmpty) return 'unknown';
    final lower = ussdResponse.toLowerCase();
    if (_failureKeywords.any((k) => lower.contains(k))) return 'failure';
    if (_successKeywords.any((k) => lower.contains(k))) return 'success';
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
}
