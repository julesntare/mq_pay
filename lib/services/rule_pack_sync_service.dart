import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sms_rule_pack.dart';
import 'sms_rule_service.dart';
import 'supabase_backup_service.dart';

/// What a pack fetch turned up.
class RulePackInfo {
  final int version;
  final int ruleCount;
  final DateTime fetchedAt;

  const RulePackInfo({
    required this.version,
    required this.ruleCount,
    required this.fetchedAt,
  });
}

/// Pulls an updated detection pack from Supabase.
///
/// Message formats change on the bank's schedule, not the app's. When a bank
/// rewords its receipts, everyone's detection breaks at once — this is the way
/// to fix it for them the same day instead of waiting on a store release.
///
/// The pack replaces only the built-in layer. The user's own rules and their
/// disabled-rule choices sit above it and are never touched by a sync.
class RulePackSyncService {
  static const String bucket = 'mq-pay-rule-packs';
  static const String objectPath = 'latest.json';
  static const String fetchedAtKey = 'sms_rule_pack_fetched_at';
  static const String versionKey = 'sms_rule_pack_version';

  static bool get isAvailable => SupabaseBackupService.isConfigured();

  /// Version of the pack currently in force, and when it was fetched.
  /// Falls back to the compiled-in pack when nothing has been downloaded.
  static Future<RulePackInfo?> currentPack() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(SmsRuleService.packOverrideKey);
      if (stored == null || stored.isEmpty) return null;
      return RulePackInfo(
        version: prefs.getInt(versionKey) ?? 0,
        ruleCount: SmsRuleService.parseRules(stored).length,
        fetchedAt:
            DateTime.tryParse(prefs.getString(fetchedAtKey) ?? '') ??
                DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Downloads the published pack and puts it in force.
  ///
  /// A pack that doesn't parse, or that carries no rules, is rejected before
  /// it is stored — a bad download must never leave detection worse than the
  /// compiled-in pack it would replace.
  static Future<RulePackInfo> fetchLatest() async {
    if (!isAvailable) {
      throw Exception(
          'Cloud sync is not set up. Add your Supabase keys to .env first.');
    }

    await SupabaseBackupService.initialize();
    final bytes = await Supabase.instance.client.storage
        .from(bucket)
        .download(objectPath);
    final text = utf8.decode(bytes);

    final Map<String, dynamic> pack;
    try {
      pack = Map<String, dynamic>.from(jsonDecode(text) as Map);
    } catch (_) {
      throw const FormatException('The downloaded pack is not valid JSON.');
    }

    final rules = SmsRuleService.parseRules(text);
    if (rules.isEmpty) {
      throw const FormatException('The downloaded pack contains no rules.');
    }

    final version = (pack['version'] as num?)?.toInt() ?? 0;
    if (version < builtinRulePackVersion) {
      throw FormatException(
        'That pack (v$version) is older than the one built into this app '
        '(v$builtinRulePackVersion).',
      );
    }

    await SmsRuleService.setPackOverride(text);

    final now = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(versionKey, version);
      await prefs.setString(fetchedAtKey, now.toIso8601String());
    } catch (_) {}

    return RulePackInfo(
      version: version,
      ruleCount: rules.length,
      fetchedAt: now,
    );
  }

  /// Drops back to the pack compiled into this build.
  static Future<void> resetToBuiltIn() async {
    await SmsRuleService.setPackOverride(null);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(versionKey);
      await prefs.remove(fetchedAtKey);
    } catch (_) {}
  }
}
