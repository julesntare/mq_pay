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

    final recordsJson = jsonEncode(existingRecords.map((r) => r.toJson()).toList());
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

  static Future<int> getTotalRecordsCount() async {
    final records = await getUssdRecords();
    return records.length;
  }

  static Future<List<UssdRecord>> getRecordsByDateRange(DateTime start, DateTime end) async {
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

    final index = existingRecords.indexWhere((record) => record.id == updatedRecord.id);
    if (index != -1) {
      existingRecords[index] = updatedRecord;
      final recordsJson = jsonEncode(existingRecords.map((r) => r.toJson()).toList());
      await prefs.setString(_ussdRecordsKey, recordsJson);
    }
  }

  static Future<void> deleteUssdRecord(String recordId) async {
    final prefs = await SharedPreferences.getInstance();
    final existingRecords = await getUssdRecords();

    existingRecords.removeWhere((record) => record.id == recordId);
    final recordsJson = jsonEncode(existingRecords.map((r) => r.toJson()).toList());
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
}