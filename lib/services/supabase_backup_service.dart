import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/ussd_record.dart';
import 'ussd_record_service.dart';

class SupabaseBackupService {
  static const String _backupVersion = '1.0';
  static const int _maxBackups = 3;

  // Supabase credentials from environment variables
  static String get _supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get _supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Optional authentication credentials for private buckets
  static String get _authEmail => dotenv.env['SUPABASE_AUTH_EMAIL'] ?? '';
  static String get _authPassword => dotenv.env['SUPABASE_AUTH_PASSWORD'] ?? '';

  static SupabaseClient get _supabase => Supabase.instance.client;

  /// Initialize Supabase with credentials from environment variables
  static Future<void> initialize() async {
    try {
      // Only initialize if configured
      if (!isConfigured()) {
        throw Exception(
            'Supabase is not configured. Please set SUPABASE_URL and SUPABASE_ANON_KEY in .env file');
      }

      // Try to initialize - will throw if already initialized
      await Supabase.initialize(
        url: _supabaseUrl,
        anonKey: _supabaseAnonKey,
      );
    } catch (e) {
      // If already initialized, that's fine - ignore the error
      // If it's a different error, it will be caught by the caller
      if (!e.toString().contains('already initialized')) {
        rethrow;
      }
    }
  }

  /// Check if Supabase is configured (credentials are set in .env)
  static bool isConfigured() {
    return _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;
  }

  /// Authenticate with Supabase to access private bucket
  /// Uses anonymous sign-in if email/password not configured
  static Future<void> _ensureAuthenticated() async {
    // Check if already signed in
    if (_supabase.auth.currentUser != null) {
      return;
    }

    // Try to sign in anonymously first (recommended for backup use case)
    try {
      await _supabase.auth.signInAnonymously();
      return;
    } catch (e) {
      // If anonymous sign-in fails, try email/password if configured
      if (_authEmail.isNotEmpty && _authPassword.isNotEmpty) {
        try {
          await _supabase.auth.signInWithPassword(
            email: _authEmail,
            password: _authPassword,
          );
          return;
        } catch (emailAuthError) {
          throw Exception(
              'Failed to authenticate with Supabase. Anonymous sign-in failed: $e. Email sign-in failed: $emailAuthError');
        }
      } else {
        throw Exception(
            'Failed to authenticate with Supabase anonymously: $e. Please enable anonymous sign-in in your Supabase project or configure email/password credentials.');
      }
    }
  }

  /// Upload a backup to Supabase Storage
  /// Automatically maintains only the 3 most recent backups
  static Future<Map<String, dynamic>> uploadBackup({
    String? deviceId,
  }) async {
    try {
      if (!isConfigured()) {
        throw Exception(
            'Supabase is not configured. Please set SUPABASE_URL and SUPABASE_ANON_KEY in .env file');
      }

      // Ensure user is authenticated before accessing private bucket
      await _ensureAuthenticated();

      final prefs = await SharedPreferences.getInstance();

      // Get device ID (use a unique identifier for this device)
      final actualDeviceId = deviceId ??
          prefs.getString('deviceId') ??
          DateTime.now().millisecondsSinceEpoch.toString();

      if (deviceId == null) {
        await prefs.setString('deviceId', actualDeviceId);
      }

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
        'deviceId': actualDeviceId,
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

      // Convert to JSON bytes
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      final bytes = utf8.encode(jsonString);

      // Generate filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'backup_${actualDeviceId}_$timestamp.json';
      final filePath = 'backups/$actualDeviceId/$fileName';

      // Upload to Supabase Storage
      await _supabase.storage.from('mq-pay-backups').uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/json',
              upsert: false,
            ),
          );

      // Clean up old backups (keep only 3 most recent)
      await _cleanupOldBackups(actualDeviceId);

      // Save last backup timestamp
      await prefs.setInt(
          'lastSupabaseBackupTimestamp', DateTime.now().millisecondsSinceEpoch);

      return {
        'success': true,
        'fileName': fileName,
        'timestamp': DateTime.now().toIso8601String(),
        'recordsCount': ussdRecords.length,
        'paymentMethodsCount': paymentMethodsList.length,
      };
    } catch (e) {
      throw Exception('Failed to upload backup to Supabase: $e');
    }
  }

  /// List all backups for this device from Supabase Storage
  static Future<List<Map<String, dynamic>>> listBackups({
    String? deviceId,
  }) async {
    try {
      if (!isConfigured()) {
        throw Exception('Supabase is not configured');
      }

      // Ensure user is authenticated before accessing private bucket
      await _ensureAuthenticated();

      final prefs = await SharedPreferences.getInstance();
      final actualDeviceId =
          deviceId ?? prefs.getString('deviceId') ?? 'unknown';

      // List files in the device's backup folder
      final files = await _supabase.storage
          .from('mq-pay-backups')
          .list(path: 'backups/$actualDeviceId');

      // Sort by created_at (newest first)
      files.sort((a, b) {
        final aTime = DateTime.parse(a.createdAt ?? '1970-01-01');
        final bTime = DateTime.parse(b.createdAt ?? '1970-01-01');
        return bTime.compareTo(aTime);
      });

      return files.map((file) {
        return {
          'name': file.name,
          'path': 'backups/$actualDeviceId/${file.name}',
          'created': DateTime.parse(file.createdAt ?? '1970-01-01'),
          'size': file.metadata?['size'] ?? 0,
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to list backups: $e');
    }
  }

  /// Download and restore a backup from Supabase Storage
  static Future<Map<String, dynamic>> restoreBackup({
    required String backupPath,
  }) async {
    try {
      if (!isConfigured()) {
        throw Exception('Supabase is not configured');
      }

      // Ensure user is authenticated before accessing private bucket
      await _ensureAuthenticated();

      // Download the backup file
      final bytes =
          await _supabase.storage.from('mq-pay-backups').download(backupPath);

      // Parse JSON
      final jsonString = utf8.decode(bytes);
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
        final backupRecords =
            backupRecordsList.map((json) => UssdRecord.fromJson(json)).toList();

        // Get existing records
        final existingRecords = await UssdRecordService.getUssdRecords();

        // Create a set of existing record identifiers
        final existingRecordIds = existingRecords
            .map((r) =>
                '${r.timestamp.millisecondsSinceEpoch}_${r.recipient}_${r.amount}')
            .toSet();

        // Filter out duplicates
        final newRecords = <UssdRecord>[];
        for (final record in backupRecords) {
          final recordId =
              '${record.timestamp.millisecondsSinceEpoch}_${record.recipient}_${record.amount}';
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
        final recordsJson =
            jsonEncode(allRecords.map((r) => r.toJson()).toList());
        await prefs.setString('ussd_records', recordsJson);
      }

      // Restore payment methods with duplicate prevention
      if (data.containsKey('paymentMethods')) {
        final List<dynamic> backupPaymentMethods =
            data['paymentMethods'] as List;

        // Get existing payment methods
        final existingPaymentMethodsJson =
            prefs.getString('paymentMethods') ?? '[]';
        final List<dynamic> existingPaymentMethods =
            jsonDecode(existingPaymentMethodsJson);

        // Create a set of existing payment method identifiers
        final existingPaymentIds = existingPaymentMethods
            .map((pm) => '${pm['type']}_${pm['value']}')
            .toSet();

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
        final allPaymentMethods = [
          ...existingPaymentMethods,
          ...newPaymentMethods
        ];

        // Save merged payment methods
        final paymentMethodsJson = jsonEncode(allPaymentMethods);
        await prefs.setString('paymentMethods', paymentMethodsJson);
      }

      // Restore settings (optional - don't overwrite if user doesn't want to)
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
      throw Exception('Failed to restore backup from Supabase: $e');
    }
  }

  /// Clean up old backups, keeping only the 3 most recent
  static Future<void> _cleanupOldBackups(String deviceId) async {
    try {
      // List all backups for this device
      final backups = await listBackups(deviceId: deviceId);

      // If more than 3 backups exist, delete the oldest ones
      if (backups.length > _maxBackups) {
        final backupsToDelete = backups.sublist(_maxBackups);

        for (final backup in backupsToDelete) {
          try {
            await _supabase.storage
                .from('mq-pay-backups')
                .remove([backup['path'] as String]);
          } catch (e) {
            // Continue even if deletion fails
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Delete a specific backup
  static Future<void> deleteBackup(String backupPath) async {
    try {
      if (!isConfigured()) {
        throw Exception('Supabase is not configured');
      }

      // Ensure user is authenticated before accessing private bucket
      await _ensureAuthenticated();

      await _supabase.storage.from('mq-pay-backups').remove([backupPath]);
    } catch (e) {
      throw Exception('Failed to delete backup: $e');
    }
  }

  /// Get the last backup timestamp
  static Future<DateTime?> getLastBackupTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('lastSupabaseBackupTimestamp');

      if (timestamp == null) return null;

      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      return null;
    }
  }

  /// Check if auto-backup should be triggered
  /// Uses the same settings as local backup (autoBackupEnabled and autoBackupFrequency)
  static Future<bool> shouldTriggerAutoBackup() async {
    try {
      if (!isConfigured()) return false;

      final prefs = await SharedPreferences.getInstance();

      // Use the same auto-backup enabled setting as local backup
      final isEnabled = prefs.getBool('autoBackupEnabled') ?? false;
      if (!isEnabled) return false;

      // Get last backup timestamp for Supabase
      final lastBackupTimestamp =
          prefs.getInt('lastSupabaseBackupTimestamp') ?? 0;
      final lastBackupTime =
          DateTime.fromMillisecondsSinceEpoch(lastBackupTimestamp);

      // Use the same frequency setting as local backup
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
        await uploadBackup();
      }
    } catch (e) {
      // Silently fail - auto-backup is not critical
    }
  }
}
