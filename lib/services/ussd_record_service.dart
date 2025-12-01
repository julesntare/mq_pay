import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ussd_record.dart';

class UssdRecordService {
  static const String _ussdRecordsKey = 'ussd_records';

  static Future<List<UssdRecord>> getUssdRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getString(_ussdRecordsKey);

    if (recordsJson == null) {
      return [];
    }

    final List<dynamic> recordsList = jsonDecode(recordsJson);
    return recordsList.map((json) => UssdRecord.fromJson(json)).toList();
  }

  static Future<void> saveUssdRecord(UssdRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final existingRecords = await getUssdRecords();

    existingRecords.add(record);

    // Keep only the last 100 records to prevent storage bloat
    if (existingRecords.length > 100) {
      existingRecords.removeRange(0, existingRecords.length - 100);
    }

    final recordsJson =
        jsonEncode(existingRecords.map((r) => r.toJson()).toList());
    await prefs.setString(_ussdRecordsKey, recordsJson);
  }

  static Future<void> clearUssdRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ussdRecordsKey);
  }

  static Future<double> getTotalAmount() async {
    final records = await getUssdRecords();
    return records.fold<double>(0.0, (sum, record) => sum + record.amount);
  }

  static Future<double> getTodayTotalAmount() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final todayRecords = await getRecordsByDateRange(startOfDay, endOfDay);
    return todayRecords.fold<double>(0.0, (sum, record) => sum + record.amount);
  }

  static Future<int> getTotalRecordsCount() async {
    final records = await getUssdRecords();
    return records.length;
  }

  static Future<List<UssdRecord>> getRecordsByDateRange(
      DateTime start, DateTime end) async {
    final records = await getUssdRecords();
    return records.where((record) {
      return record.timestamp.isAfter(start) && record.timestamp.isBefore(end);
    }).toList();
  }

  static Future<Map<String, double>> getAmountByRecipientType() async {
    final records = await getUssdRecords();
    double phoneTotal = 0.0;
    double momoTotal = 0.0;
    double miscTotal = 0.0;

    for (final record in records) {
      if (record.recipientType == 'phone') {
        phoneTotal += record.amount;
      } else if (record.recipientType == 'momo') {
        momoTotal += record.amount;
      } else if (record.recipientType == 'misc') {
        miscTotal += record.amount;
      }
    }

    return {
      'phone': phoneTotal,
      'momo': momoTotal,
      'misc': miscTotal,
    };
  }

  static Future<void> updateUssdRecord(UssdRecord updatedRecord) async {
    final prefs = await SharedPreferences.getInstance();
    final existingRecords = await getUssdRecords();

    final index =
        existingRecords.indexWhere((record) => record.id == updatedRecord.id);
    if (index != -1) {
      existingRecords[index] = updatedRecord;
      final recordsJson =
          jsonEncode(existingRecords.map((r) => r.toJson()).toList());
      await prefs.setString(_ussdRecordsKey, recordsJson);
    }
  }

  static Future<void> deleteUssdRecord(String recordId) async {
    final prefs = await SharedPreferences.getInstance();
    final existingRecords = await getUssdRecords();

    existingRecords.removeWhere((record) => record.id == recordId);
    final recordsJson =
        jsonEncode(existingRecords.map((r) => r.toJson()).toList());
    await prefs.setString(_ussdRecordsKey, recordsJson);
  }

  static Future<UssdRecord?> getUssdRecordById(String recordId) async {
    final records = await getUssdRecords();
    try {
      return records.firstWhere((record) => record.id == recordId);
    } catch (e) {
      return null;
    }
  }

  // Return a sorted list of unique non-empty reasons (most recent first)
  static Future<List<String>> getUniqueReasons() async {
    final records = await getUssdRecords();
    final Set<String> reasons = {};
    // iterate newest first
    for (final r in records.reversed) {
      if (r.reason != null && r.reason!.trim().isNotEmpty) {
        reasons.add(r.reason!.trim());
      }
    }
    return reasons.toList();
  }

  // Get total amount for a given reason across all records
  static Future<double> getTotalByReason(String reason) async {
    final records = await getUssdRecords();
    return records
        .where((r) => r.reason != null && r.reason!.trim() == reason.trim())
        .fold<double>(0.0, (double sum, r) => sum + r.amount);
  }

  // Get total amount for a given reason in a specific month (year, month)
  static Future<double> getTotalByReasonForMonth(
      String reason, int year, int month) async {
    final records = await getUssdRecords();
    return records
        .where((r) => r.reason != null && r.reason!.trim() == reason.trim())
        .where((r) => r.timestamp.year == year && r.timestamp.month == month)
        .fold<double>(0.0, (double sum, r) => sum + r.amount);
  }

  // Get all unique dates (yyyy-MM-dd format) that have transactions
  static Future<List<String>> getAllUniqueDates() async {
    final records = await getUssdRecords();
    final Set<String> dates = {};

    for (final record in records) {
      final date = DateTime(
        record.timestamp.year,
        record.timestamp.month,
        record.timestamp.day,
      );
      final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dates.add(dateString);
    }

    return dates.toList()..sort();
  }

  // Get total amount (with fees) for a specific date (yyyy-MM-dd format)
  static Future<Map<String, dynamic>> getTotalForDate(String dateString) async {
    final dateParts = dateString.split('-');
    final year = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final day = int.parse(dateParts[2]);

    final startOfDay = DateTime(year, month, day, 0, 0, 0);
    final endOfDay = DateTime(year, month, day, 23, 59, 59);

    final records = await getRecordsByDateRange(startOfDay, endOfDay);

    final totalWithFees = records.fold<double>(
      0.0,
      (sum, record) => sum + record.amount + record.calculateFee(),
    );

    return {
      'total': totalWithFees,
      'recordCount': records.length,
    };
  }
}
