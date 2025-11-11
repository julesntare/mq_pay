import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/ussd_record.dart';
import 'ussd_record_service.dart';

class BackupService {
  // Version for backup format - increment if structure changes
  static const String _backupVersion = '1.0';

  /// Export all app data to a JSON file
  static Future<String?> exportBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get all USSD records
      final ussdRecords = await UssdRecordService.getUssdRecords();

      // Get payment methods
      final paymentMethodsJson = prefs.getString('paymentMethods') ?? '[]';
      final List<dynamic> paymentMethodsList = jsonDecode(paymentMethodsJson);

      // Get user settings
      final mobileNumber = prefs.getString('mobileNumber') ?? '';
      final momoCode = prefs.getString('momoCode') ?? '';
      final language = prefs.getString('language') ?? 'en';
      final selectedLanguage = prefs.getString('selectedLanguage') ?? 'en';
      final isDarkMode = prefs.getBool('isDarkMode') ?? false;

      // Create backup object with timestamp
      final backupData = {
        'version': _backupVersion,
        'timestamp': DateTime.now().toIso8601String(),
        'data': {
          'ussdRecords': ussdRecords.map((r) => r.toJson()).toList(),
          'paymentMethods': paymentMethodsList,
          'settings': {
            'mobileNumber': mobileNumber,
            'momoCode': momoCode,
            'language': language,
            'selectedLanguage': selectedLanguage,
            'isDarkMode': isDarkMode,
          }
        }
      };

      // Convert to pretty JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);

      // Convert to bytes for Android/iOS
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      // Generate filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final fileName = 'mq_pay_backup_$timestamp.json';

      // Get directory to save file
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

      if (outputFile == null) {
        // User cancelled the save dialog
        return null;
      }

      return outputFile;
    } catch (e) {
      throw Exception('Failed to export backup: $e');
    }
  }

  /// Import and restore data from a JSON backup file
  static Future<Map<String, dynamic>> importBackup() async {
    try {
      // Pick a file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select Backup File',
      );

      if (result == null || result.files.single.path == null) {
        throw Exception('No file selected');
      }

      // Read the file
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final Map<String, dynamic> backupData = jsonDecode(jsonString);

      // Validate backup format
      if (!backupData.containsKey('version') ||
          !backupData.containsKey('data')) {
        throw Exception('Invalid backup file format');
      }

      // Extract data
      final data = backupData['data'] as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();

      // Restore USSD records
      if (data.containsKey('ussdRecords')) {
        final List<dynamic> ussdRecordsList = data['ussdRecords'] as List;
        final records =
            ussdRecordsList.map((json) => UssdRecord.fromJson(json)).toList();

        // Save to SharedPreferences
        final recordsJson = jsonEncode(records.map((r) => r.toJson()).toList());
        await prefs.setString('ussd_records', recordsJson);
      }

      // Restore payment methods
      if (data.containsKey('paymentMethods')) {
        final paymentMethodsJson = jsonEncode(data['paymentMethods']);
        await prefs.setString('paymentMethods', paymentMethodsJson);
      }

      // Restore settings
      if (data.containsKey('settings')) {
        final settings = data['settings'] as Map<String, dynamic>;

        if (settings.containsKey('mobileNumber')) {
          await prefs.setString('mobileNumber', settings['mobileNumber']);
        }
        if (settings.containsKey('momoCode')) {
          await prefs.setString('momoCode', settings['momoCode']);
        }
        if (settings.containsKey('language')) {
          await prefs.setString('language', settings['language']);
        }
        if (settings.containsKey('selectedLanguage')) {
          await prefs.setString(
              'selectedLanguage', settings['selectedLanguage']);
        }
        if (settings.containsKey('isDarkMode')) {
          await prefs.setBool('isDarkMode', settings['isDarkMode']);
        }
      }

      // Return summary
      return {
        'success': true,
        'backupVersion': backupData['version'],
        'backupTimestamp': backupData['timestamp'],
        'recordsCount': (data['ussdRecords'] as List?)?.length ?? 0,
        'paymentMethodsCount': (data['paymentMethods'] as List?)?.length ?? 0,
      };
    } catch (e) {
      throw Exception('Failed to import backup: $e');
    }
  }

  /// Create a quick backup in app's documents directory (for auto-backup feature)
  static Future<String> createAutoBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get all USSD records
      final ussdRecords = await UssdRecordService.getUssdRecords();

      // Get payment methods
      final paymentMethodsJson = prefs.getString('paymentMethods') ?? '[]';
      final List<dynamic> paymentMethodsList = jsonDecode(paymentMethodsJson);

      // Get user settings
      final mobileNumber = prefs.getString('mobileNumber') ?? '';
      final momoCode = prefs.getString('momoCode') ?? '';
      final language = prefs.getString('language') ?? 'en';
      final selectedLanguage = prefs.getString('selectedLanguage') ?? 'en';
      final isDarkMode = prefs.getBool('isDarkMode') ?? false;

      // Create backup object
      final backupData = {
        'version': _backupVersion,
        'timestamp': DateTime.now().toIso8601String(),
        'data': {
          'ussdRecords': ussdRecords.map((r) => r.toJson()).toList(),
          'paymentMethods': paymentMethodsList,
          'settings': {
            'mobileNumber': mobileNumber,
            'momoCode': momoCode,
            'language': language,
            'selectedLanguage': selectedLanguage,
            'isDarkMode': isDarkMode,
          }
        }
      };

      // Convert to JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);

      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/backups');

      // Create backups directory if it doesn't exist
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // Generate filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'auto_backup_$timestamp.json';
      final file = File('${backupDir.path}/$fileName');

      // Write the file
      await file.writeAsString(jsonString);

      // Keep only last 5 auto-backups
      await _cleanOldAutoBackups(backupDir);

      return file.path;
    } catch (e) {
      throw Exception('Failed to create auto backup: $e');
    }
  }

  /// Clean up old auto-backup files, keeping only the most recent 5
  static Future<void> _cleanOldAutoBackups(Directory backupDir) async {
    try {
      final files = await backupDir.list().toList();
      final backupFiles = files
          .whereType<File>()
          .where((f) => f.path.contains('auto_backup_'))
          .toList();

      // Sort by modification time (newest first)
      backupFiles.sort((a, b) => b
          .statSync()
          .modified
          .compareTo(a.statSync().modified));

      // Delete old backups (keep only 5 most recent)
      if (backupFiles.length > 5) {
        for (var i = 5; i < backupFiles.length; i++) {
          await backupFiles[i].delete();
        }
      }
    } catch (e) {
      // Ignore errors in cleanup
    }
  }

  /// Get list of auto-backup files
  static Future<List<Map<String, dynamic>>> getAutoBackups() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/backups');

      if (!await backupDir.exists()) {
        return [];
      }

      final files = await backupDir.list().toList();
      final backupFiles = files
          .whereType<File>()
          .where((f) => f.path.contains('auto_backup_'))
          .toList();

      // Sort by modification time (newest first)
      backupFiles.sort((a, b) => b
          .statSync()
          .modified
          .compareTo(a.statSync().modified));

      return backupFiles.map((file) {
        final stat = file.statSync();
        return {
          'path': file.path,
          'name': file.path.split('/').last,
          'modified': stat.modified,
          'size': stat.size,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
