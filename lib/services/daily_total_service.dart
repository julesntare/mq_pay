import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:workmanager/workmanager.dart';
import '../models/daily_total.dart';
import '../services/ussd_record_service.dart';

class DailyTotalService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'daily_totals';
  static const String _taskName = 'dailyTotalTask';

  /// Get month key from date (format: yyyy-MM)
  static String _getMonthKey(DateTime date) {
    return DateFormat('yyyy-MM').format(date);
  }

  /// Get month key from date string (format: yyyy-MM-dd -> yyyy-MM)
  static String _getMonthKeyFromString(String dateString) {
    return dateString.substring(0, 7); // Get first 7 chars: "yyyy-MM"
  }

  /// Send daily total to Firestore using monthly document structure
  /// If a record for today already exists, it will be updated instead of creating a new one
  /// [overrideAmount] - Optional parameter to override the calculated total amount
  static Future<void> sendDailyTotal({double? overrideAmount}) async {
    try {
      // Get today's date in yyyy-MM-dd format
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final monthKey = _getMonthKey(now);

      // Get start and end of today
      final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Get today's records only
      final todayRecords = await UssdRecordService.getRecordsByDateRange(
        startOfDay,
        endOfDay,
      );

      // Calculate total with fees for today's records only
      final calculatedTotalWithFees = todayRecords.fold<double>(
        0.0,
        (sum, record) => sum + record.amount + record.calculateFee(),
      );

      // Use override amount if provided, otherwise use calculated total with fees
      final totalAmount = overrideAmount ?? calculatedTotalWithFees;

      final dailyTotal = DailyTotal(
        date: today,
        total: totalAmount,
        sentAt: DateTime.now(),
        totalWithFees: totalAmount, // Use the same value as total
        recordCount: todayRecords.length,
      );

      // Store in monthly document: daily_totals/yyyy-MM
      // Update the specific date field within the month document
      await _firestore.collection(_collectionName).doc(monthKey).set({
        today: dailyTotal.toJson(),
      }, SetOptions(merge: true));
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
      final now = DateTime.now()
          .toUtc()
          .add(const Duration(hours: 2)); // Convert to CAT
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

  /// Get daily total for a specific date from monthly document
  static Future<DailyTotal?> getDailyTotal(String date) async {
    try {
      final monthKey = _getMonthKeyFromString(date);
      final doc =
          await _firestore.collection(_collectionName).doc(monthKey).get();

      if (doc.exists && doc.data() != null) {
        final monthData = doc.data()!;
        if (monthData.containsKey(date)) {
          return DailyTotal.fromJson(monthData[date] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      print('Error getting daily total: $e');
      return null;
    }
  }

  /// Get all daily totals from all monthly documents (optional: for viewing history)
  static Future<List<DailyTotal>> getAllDailyTotals() async {
    try {
      final querySnapshot = await _firestore.collection(_collectionName).get();

      final List<DailyTotal> allTotals = [];

      for (final doc in querySnapshot.docs) {
        if (doc.exists && doc.data().isNotEmpty) {
          final monthData = doc.data();

          // Each month document contains date keys (yyyy-MM-dd) with daily total data
          for (final entry in monthData.entries) {
            final dateKey = entry.key;
            final dailyData = entry.value;

            // Ensure it's a map and looks like a daily total entry
            if (dailyData is Map<String, dynamic> &&
                dailyData.containsKey('date')) {
              try {
                allTotals.add(DailyTotal.fromJson(dailyData));
              } catch (e) {
                print('Error parsing daily total for date $dateKey: $e');
              }
            }
          }
        }
      }

      // Sort by date descending
      allTotals.sort((a, b) => b.date.compareTo(a.date));

      return allTotals;
    } catch (e) {
      print('Error getting all daily totals: $e');
      return [];
    }
  }

  /// Sync all dates with transactions to Firebase using monthly document structure
  /// This ensures that all dates that have transactions are synced to Firebase
  static Future<Map<String, dynamic>> syncAllDateTotals() async {
    try {
      // Get all unique dates from transactions
      final allDates = await UssdRecordService.getAllUniqueDates();

      int syncedCount = 0;
      int errorCount = 0;
      final List<String> syncedDates = [];
      final List<String> errorDates = [];

      // Group dates by month
      final Map<String, Map<String, DailyTotal>> monthlyData = {};

      // Prepare data grouped by month
      for (final dateString in allDates) {
        try {
          // Get total for this date
          final dateData = await UssdRecordService.getTotalForDate(dateString);
          final total = dateData['total'] as double;
          final recordCount = dateData['recordCount'] as int;

          // Create daily total object
          final dailyTotal = DailyTotal(
            date: dateString,
            total: total,
            sentAt: DateTime.now(),
            totalWithFees: total,
            recordCount: recordCount,
          );

          // Group by month
          final monthKey = _getMonthKeyFromString(dateString);
          if (!monthlyData.containsKey(monthKey)) {
            monthlyData[monthKey] = {};
          }
          monthlyData[monthKey]![dateString] = dailyTotal;
        } catch (e) {
          print('Error preparing date $dateString: $e');
          errorCount++;
          errorDates.add(dateString);
        }
      }

      // Save each month's data to Firebase
      for (final monthEntry in monthlyData.entries) {
        final monthKey = monthEntry.key;
        final datesData = monthEntry.value;

        try {
          // Convert DailyTotal objects to JSON
          final Map<String, dynamic> monthDataJson = {};
          for (final dateEntry in datesData.entries) {
            monthDataJson[dateEntry.key] = dateEntry.value.toJson();
          }

          // Save to Firebase (merge to avoid overwriting existing data)
          await _firestore
              .collection(_collectionName)
              .doc(monthKey)
              .set(monthDataJson, SetOptions(merge: true));

          // Count synced dates for this month
          syncedCount += datesData.length;
          syncedDates.addAll(datesData.keys);
        } catch (e) {
          print('Error syncing month $monthKey: $e');
          errorCount += datesData.length;
          errorDates.addAll(datesData.keys);
        }
      }

      return {
        'totalDates': allDates.length,
        'syncedCount': syncedCount,
        'errorCount': errorCount,
        'syncedDates': syncedDates,
        'errorDates': errorDates,
        'monthsProcessed': monthlyData.length,
      };
    } catch (e) {
      print('Error syncing all date totals: $e');
      throw Exception('Failed to sync all date totals: $e');
    }
  }
}
