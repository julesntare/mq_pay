import 'package:flutter/foundation.dart';
import '../models/ussd_record.dart';
import '../models/transaction_status.dart';
import 'ussd_record_service.dart';
import 'ussd_keyword_detector.dart';
import 'dart:async';

/// Manages USSD transactions with keyword validation
/// Transactions are saved as pending and only confirmed after USSD response validation
class UssdTransactionManager {
  static final Map<String, UssdRecord> _pendingTransactions = {};
  static Timer? _cleanupTimer;

  /// Initialize the transaction manager
  static void initialize() {
    // Start cleanup timer to remove old pending transactions after 2 minutes
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _cleanupExpiredPendingTransactions();
    });

    debugPrint('[UssdTransactionManager] Initialized');
  }

  /// Save a transaction as pending (before USSD response)
  static Future<String> savePendingTransaction(UssdRecord record) async {
    final transactionId = record.id;

    // Store in pending transactions map
    _pendingTransactions[transactionId] = record;

    debugPrint(
        '[UssdTransactionManager] Pending transaction saved: $transactionId');
    debugPrint(
        '[UssdTransactionManager] Amount: ${record.amount}, Recipient: ${record.recipient}');

    return transactionId;
  }

  /// Validate USSD response and confirm/reject transaction
  /// Returns true if success, false if failure, null if unknown (left pending)
  static Future<bool?> validateUssdResponse(String ussdResponse) async {
    debugPrint(
        '[UssdTransactionManager] Validating USSD response: $ussdResponse');

    final result = UssdKeywordDetector.detectTransactionResult(ussdResponse);

    if (result == 'success') {
      // Success - confirm the most recent pending transaction
      await _confirmMostRecentTransaction(ussdResponse);
      return true;
    } else if (result == 'failure') {
      // Explicit failure - mark the most recent pending transaction as failed
      await _rejectMostRecentTransaction(ussdResponse);
      return false;
    } else {
      // Unknown - leave the transaction as pending for manual resolution
      debugPrint(
          '[UssdTransactionManager] No success/failure keywords detected - leaving transaction as pending for manual resolution');
      return null;
    }
  }

  /// Confirm the most recent pending transaction
  static Future<void> _confirmMostRecentTransaction(String ussdResponse) async {
    if (_pendingTransactions.isEmpty) {
      debugPrint('[UssdTransactionManager] No pending transactions to confirm');
      return;
    }

    // Get the most recent transaction (last added)
    final entries = _pendingTransactions.entries.toList();
    entries.sort((a, b) => b.value.timestamp.compareTo(a.value.timestamp));
    final mostRecent = entries.first;

    final transactionId = mostRecent.key;
    final record = mostRecent.value;

    // Update the transaction to success status in permanent storage
    await UssdRecordService.updateUssdRecord(
      record.copyWith(
        status: TransactionStatus.success,
        statusUpdatedAt: DateTime.now(),
      ),
    );

    // Remove from pending
    _pendingTransactions.remove(transactionId);

    debugPrint(
        '[UssdTransactionManager] ✅ Transaction CONFIRMED and updated to success: $transactionId');
    debugPrint(
        '[UssdTransactionManager] Amount: ${record.amount}, Recipient: ${record.recipient}');
  }

  /// Reject the most recent pending transaction
  static Future<void> _rejectMostRecentTransaction(String ussdResponse) async {
    if (_pendingTransactions.isEmpty) {
      debugPrint('[UssdTransactionManager] No pending transactions to reject');
      return;
    }

    // Get the most recent transaction (last added)
    final entries = _pendingTransactions.entries.toList();
    entries.sort((a, b) => b.value.timestamp.compareTo(a.value.timestamp));
    final mostRecent = entries.first;

    final transactionId = mostRecent.key;
    final record = mostRecent.value;

    final failureReason =
        UssdKeywordDetector.extractFailureReason(ussdResponse);

    // Update the transaction to failed status in permanent storage
    await UssdRecordService.updateUssdRecord(
      record.copyWith(
        status: TransactionStatus.failed,
        statusUpdatedAt: DateTime.now(),
      ),
    );

    // Remove from pending
    _pendingTransactions.remove(transactionId);

    debugPrint(
        '[UssdTransactionManager] ❌ Transaction REJECTED and marked as failed: $transactionId');
    debugPrint(
        '[UssdTransactionManager] Amount: ${record.amount}, Recipient: ${record.recipient}');
    debugPrint(
        '[UssdTransactionManager] Reason: ${failureReason ?? "No success keywords found"}');
  }

  /// Clean up pending transactions older than 2 minutes
  static void _cleanupExpiredPendingTransactions() {
    final now = DateTime.now();
    final expiredIds = <String>[];

    _pendingTransactions.forEach((id, record) {
      final age = now.difference(record.timestamp);
      if (age.inMinutes >= 2) {
        expiredIds.add(id);
      }
    });

    for (final id in expiredIds) {
      final record = _pendingTransactions[id];
      _pendingTransactions.remove(id);
      debugPrint(
          '[UssdTransactionManager] 🗑️ Expired pending transaction removed: $id (Age: ${now.difference(record!.timestamp).inMinutes} min)');
    }
  }

  /// Get count of pending transactions
  static int getPendingCount() {
    return _pendingTransactions.length;
  }

  /// Clear all pending transactions
  static void clearPending() {
    final count = _pendingTransactions.length;
    _pendingTransactions.clear();
    debugPrint('[UssdTransactionManager] Cleared $count pending transactions');
  }

  /// Dispose of the manager
  static void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _pendingTransactions.clear();
    debugPrint('[UssdTransactionManager] Disposed');
  }
}
