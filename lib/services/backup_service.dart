import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
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

  /// Restore data from auto-backup file with duplicate prevention
  static Future<Map<String, dynamic>> restoreAutoBackup(String backupPath) async {
    try {
      // Read the backup file
      final file = File(backupPath);
      if (!await file.exists()) {
        throw Exception('Backup file not found');
      }

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

      int newRecordsAdded = 0;
      int duplicateRecordsSkipped = 0;
      int newPaymentMethodsAdded = 0;
      int duplicatePaymentMethodsSkipped = 0;

      // Restore USSD records with duplicate prevention
      if (data.containsKey('ussdRecords')) {
        final List<dynamic> backupRecordsList = data['ussdRecords'] as List;
        final backupRecords = backupRecordsList
            .map((json) => UssdRecord.fromJson(json))
            .toList();

        // Get existing records
        final existingRecords = await UssdRecordService.getUssdRecords();

        // Create a set of existing record identifiers (timestamp + recipient + amount)
        final existingRecordIds = existingRecords.map((r) =>
          '${r.timestamp.millisecondsSinceEpoch}_${r.recipient}_${r.amount}'
        ).toSet();

        // Filter out duplicates
        final newRecords = <UssdRecord>[];
        for (final record in backupRecords) {
          final recordId = '${record.timestamp.millisecondsSinceEpoch}_${record.recipient}_${record.amount}';
          if (!existingRecordIds.contains(recordId)) {
            newRecords.add(record);
            newRecordsAdded++;
          } else {
            duplicateRecordsSkipped++;
          }
        }

        // Merge records (existing + new)
        final allRecords = [...existingRecords, ...newRecords];

        // Sort by timestamp (newest first)
        allRecords.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // Save merged records
        final recordsJson = jsonEncode(allRecords.map((r) => r.toJson()).toList());
        await prefs.setString('ussd_records', recordsJson);
      }

      // Restore payment methods with duplicate prevention
      if (data.containsKey('paymentMethods')) {
        final List<dynamic> backupPaymentMethods = data['paymentMethods'] as List;

        // Get existing payment methods
        final existingPaymentMethodsJson = prefs.getString('paymentMethods') ?? '[]';
        final List<dynamic> existingPaymentMethods = jsonDecode(existingPaymentMethodsJson);

        // Create a set of existing payment method identifiers (type + value)
        final existingPaymentIds = existingPaymentMethods.map((pm) =>
          '${pm['type']}_${pm['value']}'
        ).toSet();

        // Filter out duplicates
        final newPaymentMethods = <Map<String, dynamic>>[];
        for (final pm in backupPaymentMethods) {
          final pmId = '${pm['type']}_${pm['value']}';
          if (!existingPaymentIds.contains(pmId)) {
            newPaymentMethods.add(pm as Map<String, dynamic>);
            newPaymentMethodsAdded++;
          } else {
            duplicatePaymentMethodsSkipped++;
          }
        }

        // Merge payment methods
        final allPaymentMethods = [...existingPaymentMethods, ...newPaymentMethods];

        // Save merged payment methods
        final paymentMethodsJson = jsonEncode(allPaymentMethods);
        await prefs.setString('paymentMethods', paymentMethodsJson);
      }

      // Restore settings (overwrite existing)
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

      // Return detailed summary
      return {
        'success': true,
        'backupVersion': backupData['version'],
        'backupTimestamp': backupData['timestamp'],
        'newRecordsAdded': newRecordsAdded,
        'duplicateRecordsSkipped': duplicateRecordsSkipped,
        'newPaymentMethodsAdded': newPaymentMethodsAdded,
        'duplicatePaymentMethodsSkipped': duplicatePaymentMethodsSkipped,
      };
    } catch (e) {
      throw Exception('Failed to restore auto-backup: $e');
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

      // Check if user has set a custom backup location
      final customLocation = prefs.getString('autoBackupLocation');

      Directory backupDir;
      if (customLocation != null && customLocation.isNotEmpty) {
        // Use custom location
        backupDir = Directory('$customLocation/mq_pay_backups');
      } else {
        // Use default app documents directory
        final directory = await getApplicationDocumentsDirectory();
        backupDir = Directory('${directory.path}/backups');
      }

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
      final prefs = await SharedPreferences.getInstance();
      final customLocation = prefs.getString('autoBackupLocation');

      Directory backupDir;
      if (customLocation != null && customLocation.isNotEmpty) {
        // Use custom location
        backupDir = Directory('$customLocation/mq_pay_backups');
      } else {
        // Use default app documents directory
        final directory = await getApplicationDocumentsDirectory();
        backupDir = Directory('${directory.path}/backups');
      }

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

  /// Export transactions to Excel format for analysis
  static Future<String?> exportToExcel() async {
    try {
      // Get all USSD records
      final ussdRecords = await UssdRecordService.getUssdRecords();

      if (ussdRecords.isEmpty) {
        throw Exception('No transactions to export');
      }

      // Create Excel workbook
      final excel = Excel.createExcel();

      // Remove default sheet
      excel.delete('Sheet1');

      // Create Transactions sheet
      final transactionsSheet = excel['Transactions'];

      // Define header style
      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
      );

      // Add headers
      final headers = [
        'Date',
        'Time',
        'Recipient',
        'Recipient Type',
        'Amount',
        'Contact Name',
        'Reason',
        'USSD Code',
      ];

      for (var i = 0; i < headers.length; i++) {
        final cell = transactionsSheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // Add data rows
      for (var i = 0; i < ussdRecords.length; i++) {
        final record = ussdRecords[i];
        final rowIndex = i + 1;

        // Format date and time
        final dateFormat = DateFormat('yyyy-MM-dd');
        final timeFormat = DateFormat('HH:mm:ss');

        final rowData = [
          dateFormat.format(record.timestamp),
          timeFormat.format(record.timestamp),
          record.maskedRecipient ?? record.recipient,
          record.recipientType,
          record.amount.toString(),
          record.contactName ?? '',
          record.reason ?? '',
          record.ussdCode,
        ];

        for (var j = 0; j < rowData.length; j++) {
          final cell = transactionsSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: rowIndex));
          cell.value = TextCellValue(rowData[j]);
        }
      }

      // Auto-fit columns (set reasonable width)
      transactionsSheet.setColumnWidth(0, 12); // Date
      transactionsSheet.setColumnWidth(1, 10); // Time
      transactionsSheet.setColumnWidth(2, 15); // Recipient
      transactionsSheet.setColumnWidth(3, 14); // Recipient Type
      transactionsSheet.setColumnWidth(4, 12); // Amount
      transactionsSheet.setColumnWidth(5, 20); // Contact Name
      transactionsSheet.setColumnWidth(6, 20); // Reason
      transactionsSheet.setColumnWidth(7, 12); // USSD Code

      // Create Summary sheet
      final summarySheet = excel['Summary'];

      // Add summary headers
      summarySheet
          .cell(CellIndex.indexByString('A1'))
          .value = TextCellValue('Summary Statistics');
      summarySheet.cell(CellIndex.indexByString('A1')).cellStyle = headerStyle;

      // Calculate statistics
      final totalAmount =
          ussdRecords.fold<double>(0.0, (sum, record) => sum + record.amount);
      final totalTransactions = ussdRecords.length;

      final amountByType = <String, double>{};
      for (final record in ussdRecords) {
        amountByType[record.recipientType] =
            (amountByType[record.recipientType] ?? 0) + record.amount;
      }

      // Add summary data
      var row = 2;
      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue('Total Transactions:');
      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = IntCellValue(totalTransactions);
      row++;

      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue('Total Amount:');
      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = DoubleCellValue(totalAmount);
      row++;

      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue('Average Amount:');
      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = DoubleCellValue(totalAmount / totalTransactions);
      row += 2;

      // Add breakdown by type
      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue('Amount by Type:');
      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .cellStyle = headerStyle;
      row++;

      for (final entry in amountByType.entries) {
        summarySheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = TextCellValue('  ${entry.key}:');
        summarySheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = DoubleCellValue(entry.value);
        row++;
      }

      // Set column widths for summary
      summarySheet.setColumnWidth(0, 20);
      summarySheet.setColumnWidth(1, 15);

      // Encode to bytes
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      // Generate filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final fileName = 'mq_pay_transactions_$timestamp.xlsx';

      // Save file
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Excel File',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );

      if (outputFile == null) {
        // User cancelled
        return null;
      }

      return outputFile;
    } catch (e) {
      throw Exception('Failed to export to Excel: $e');
    }
  }

  /// Check if auto-backup should be triggered based on settings
  static Future<bool> shouldTriggerAutoBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if auto-backup is enabled
      final isEnabled = prefs.getBool('autoBackupEnabled') ?? false;
      if (!isEnabled) return false;

      // Get last backup timestamp
      final lastBackupTimestamp =
          prefs.getInt('lastAutoBackupTimestamp') ?? 0;
      final lastBackupTime =
          DateTime.fromMillisecondsSinceEpoch(lastBackupTimestamp);

      // Get frequency setting
      final frequency = prefs.getString('autoBackupFrequency') ?? 'daily';

      // Calculate if backup is due
      final now = DateTime.now();
      final timeSinceLastBackup = now.difference(lastBackupTime);

      switch (frequency) {
        case 'daily':
          return timeSinceLastBackup.inHours >= 24;
        case 'weekly':
          return timeSinceLastBackup.inDays >= 7;
        case 'monthly':
          return timeSinceLastBackup.inDays >= 30;
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Perform auto-backup if needed
  static Future<void> performAutoBackupIfNeeded() async {
    try {
      final shouldBackup = await shouldTriggerAutoBackup();

      if (shouldBackup) {
        await createAutoBackup();

        // Update last backup timestamp
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
            'lastAutoBackupTimestamp', DateTime.now().millisecondsSinceEpoch);
      }
    } catch (e) {
      // Silently fail - auto-backup is not critical
    }
  }
}
