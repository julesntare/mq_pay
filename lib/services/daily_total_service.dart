import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:workmanager/workmanager.dart';
import '../models/daily_total.dart';
import '../services/ussd_record_service.dart';

class DailyTotalService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'daily_totals';
  static const String _taskName = 'dailyTotalTask';

  /// Send daily total to Firestore
  /// If a record for today already exists, it will be updated instead of creating a new one
  /// [overrideAmount] - Optional parameter to override the calculated total amount
  static Future<void> sendDailyTotal({double? overrideAmount}) async {
    try {
      // Get today's date in yyyy-MM-dd format
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);

      // Get start and end of today
      final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Get today's records only
      final todayRecords = await UssdRecordService.getRecordsByDateRange(
        startOfDay,
        endOfDay,
      );

      // Calculate totals for today's records only
      final calculatedAmount = todayRecords.fold<double>(
        0.0,
        (sum, record) => sum + record.amount,
      );

      // Use override amount if provided, otherwise use calculated amount
      final totalAmount = overrideAmount ?? calculatedAmount;

      // Calculate total with fees for today's records only
      final totalWithFees = todayRecords.fold<double>(
        0.0,
        (sum, record) => sum + record.amount + record.calculateFee(),
      );

      final dailyTotal = DailyTotal(
        date: today,
        total: totalAmount,
        sentAt: DateTime.now(),
        totalWithFees: totalWithFees,
        recordCount: todayRecords.length,
      );

      // Use document ID as date to ensure update instead of insert
      await _firestore
          .collection(_collectionName)
          .doc(today)
          .set(dailyTotal.toJson(), SetOptions(merge: true));
    } catch (e) {
      // Log error but don't throw to prevent background task failure
      print('Error sending daily total: $e');
    }
  }

  /// Schedule daily task to run at 11:59 PM CAT (UTC+2)
  static Future<void> scheduleDailyTask() async {
    try {
      // Cancel any existing task first
      await Workmanager().cancelByUniqueName(_taskName);

      // Calculate time until 11:59 PM CAT
      final now = DateTime.now().toUtc().add(const Duration(hours: 2)); // Convert to CAT
      final todayAt2359 = DateTime(now.year, now.month, now.day, 23, 59);

      DateTime targetTime;
      if (now.isBefore(todayAt2359)) {
        targetTime = todayAt2359;
      } else {
        // Schedule for tomorrow
        targetTime = todayAt2359.add(const Duration(days: 1));
      }

      final delay = targetTime.difference(now);

      // Register periodic task (runs every 24 hours)
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        frequency: const Duration(hours: 24),
        initialDelay: delay,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
    } catch (e) {
      print('Error scheduling daily task: $e');
    }
  }

  /// Get daily total for a specific date
  static Future<DailyTotal?> getDailyTotal(String date) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(date).get();
      if (doc.exists) {
        return DailyTotal.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting daily total: $e');
      return null;
    }
  }

  /// Get all daily totals (optional: for viewing history)
  static Future<List<DailyTotal>> getAllDailyTotals() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => DailyTotal.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting all daily totals: $e');
      return [];
    }
  }
}
