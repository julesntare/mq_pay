import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'sms_rule_service.dart';

/// Moving rules between people and devices.
///
/// A rule someone worked out for Equity or I&M is useful to everyone banking
/// there, and re-deriving it by hand on each phone is wasted effort. Rules are
/// plain JSON, so sharing one is sharing a small file.
class RuleSharingService {
  /// Writes the user's own rules to a file the user picks. Built-in rules are
  /// left out — whoever opens the file already has them.
  ///
  /// Returns the saved path, or null when the user cancelled.
  static Future<String?> exportToFile() async {
    final json = SmsRuleService.exportUserRules();
    final bytes = Uint8List.fromList(utf8.encode(json));
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');

    return FilePicker.platform.saveFile(
      dialogTitle: 'Save detection rules',
      fileName: 'mq_pay_sms_rules_$stamp.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
  }

  /// Reads rules from a file the user picks and merges them in.
  /// Returns how many were imported; null when the user cancelled.
  static Future<int?> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'Select a rules file',
    );
    final path = result?.files.single.path;
    if (path == null) return null;

    final contents = await File(path).readAsString();
    return importFromText(contents);
  }

  /// Merges rules from raw JSON — a pasted snippet, or the contents of a
  /// shared file. Throws when the text holds no readable rule, so the caller
  /// can say so rather than silently importing nothing.
  static Future<int> importFromText(String json) async {
    final parsed = SmsRuleService.parseRules(json);
    if (parsed.isEmpty) {
      throw const FormatException('No detection rules found in that file.');
    }
    return SmsRuleService.importUserRules(json);
  }
}
