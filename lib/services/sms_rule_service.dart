import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/sms_rule.dart';
import 'sms_rule_pack.dart';

/// The sender IDs and keyword gates that decide *whether* a message is worth
/// parsing at all. Built-in values come from the shipped pack; a user pack can
/// extend them without a release.
class SmsRuleConfig {
  final List<String> mobileMoneySenders;
  final List<String> bankSenders;
  final List<String> successKeywords;
  final List<String> successExclude;
  final List<String> failureKeywords;

  /// Enabled rules only, highest priority first.
  final List<SmsRule> rules;

  const SmsRuleConfig({
    required this.mobileMoneySenders,
    required this.bankSenders,
    required this.successKeywords,
    required this.successExclude,
    required this.failureKeywords,
    required this.rules,
  });
}

/// Loads, merges and persists detection rules.
///
/// Three layers, lowest first:
///  1. the compiled-in built-in pack — always present, so a fresh install and
///     a background isolate that never called [load] still detect everything
///     the app shipped with;
///  2. an optional downloaded pack (`sms_rule_pack` in prefs), for pushing new
///     bank formats without an app update;
///  3. the user's own rules, which win ties by carrying a higher priority.
///
/// Built-in rules are never deleted, only suppressed by id, so disabling one
/// is always reversible.
class SmsRuleService {
  static const String userRulesKey = 'sms_rules';
  static const String disabledIdsKey = 'sms_rules_disabled';
  static const String packOverrideKey = 'sms_rule_pack';

  static SmsRuleConfig? _cache;
  static List<SmsRule> _userRules = const [];
  static Set<String> _disabledIds = const {};

  /// Current configuration. Falls back to the built-in pack alone when
  /// [load] hasn't run yet in this isolate — detection degrades to shipped
  /// behaviour rather than to nothing.
  static SmsRuleConfig get config => _cache ??= _build();

  /// Re-reads user rules and the pack override from settings.
  ///
  /// Must be awaited in every isolate that parses SMS — WorkManager runs the
  /// background scan in its own isolate, where static state doesn't carry
  /// over — and after the user edits rules.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final rulesJson = prefs.getString(userRulesKey);
      _userRules = rulesJson == null || rulesJson.isEmpty
          ? const []
          : parseRules(rulesJson);

      final disabledJson = prefs.getString(disabledIdsKey);
      _disabledIds = disabledJson == null || disabledJson.isEmpty
          ? const {}
          : {
              for (final id in jsonDecode(disabledJson) as List) id as String,
            };

      _packOverrideJson = prefs.getString(packOverrideKey);
    } catch (_) {
      // Keep whatever we already had; the built-in pack still applies.
    }
    _cache = null;
  }

  static String? _packOverrideJson;

  /// Every rule the user can see, including disabled ones and built-ins,
  /// highest priority first. For the rules screen.
  static List<SmsRule> allRules() {
    final byId = <String, SmsRule>{};
    for (final rule in _packRules()) {
      byId[rule.id] = rule.copyWith(enabled: !_disabledIds.contains(rule.id));
    }
    for (final rule in _userRules) {
      byId[rule.id] = rule;
    }
    final list = byId.values.toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    return list;
  }

  static List<SmsRule> userRules() => List.unmodifiable(_userRules);

  /// Adds or replaces a user rule (matched by id) and persists it.
  static Future<void> saveUserRule(SmsRule rule) async {
    final next = [..._userRules.where((r) => r.id != rule.id), rule];
    await _persistUserRules(next);
  }

  static Future<void> deleteUserRule(String id) async {
    await _persistUserRules(_userRules.where((r) => r.id != id).toList());
  }

  /// Enables/disables any rule. User rules store the flag on themselves;
  /// built-ins are suppressed by id so the shipped rule stays intact.
  static Future<void> setEnabled(String id, bool enabled) async {
    final existing = _userRules.where((r) => r.id == id).toList();
    if (existing.isNotEmpty) {
      await saveUserRule(existing.first.copyWith(enabled: enabled));
      return;
    }
    final next = {..._disabledIds};
    if (enabled) {
      next.remove(id);
    } else {
      next.add(id);
    }
    _disabledIds = next;
    _cache = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(disabledIdsKey, jsonEncode(next.toList()));
    } catch (_) {}
  }

  /// The user's own rules as a shareable JSON document. Built-ins are left
  /// out — the recipient already has them.
  static String exportUserRules() => jsonEncode({
        'version': builtinRulePackVersion,
        'rules': _userRules.map((r) => r.toJson()).toList(),
      });

  /// Merges an exported document (or a raw rule array) into the user's rules,
  /// replacing any rule with the same id. Returns how many were imported.
  static Future<int> importUserRules(String json) async {
    final incoming = parseRules(json);
    if (incoming.isEmpty) return 0;
    final incomingIds = incoming.map((r) => r.id).toSet();
    final next = [
      ..._userRules.where((r) => !incomingIds.contains(r.id)),
      ...incoming,
    ];
    await _persistUserRules(next);
    return incoming.length;
  }

  /// Replaces the downloaded pack layer. Pass null to fall back to built-ins.
  static Future<void> setPackOverride(String? packJson) async {
    _packOverrideJson = packJson;
    _cache = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (packJson == null) {
        await prefs.remove(packOverrideKey);
      } else {
        await prefs.setString(packOverrideKey, packJson);
      }
    } catch (_) {}
  }

  /// The rule state a backup should carry: the user's own rules, and which
  /// built-ins they switched off. Without the second list a restore would
  /// silently switch a disabled built-in back on.
  static Future<Map<String, dynamic>> backupPayload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'smsRules': jsonDecode(prefs.getString(userRulesKey) ?? '[]'),
        'disabledSmsRules':
            jsonDecode(prefs.getString(disabledIdsKey) ?? '[]'),
      };
    } catch (_) {
      return {'smsRules': const [], 'disabledSmsRules': const []};
    }
  }

  /// Merges [backupPayload] output back in. Rules merge by id — an incoming
  /// rule replaces the local one sharing its id, anything only present
  /// locally survives — and suppressed built-ins are unioned, so a restore
  /// never re-enables a rule the user turned off on either device.
  static Future<void> restoreFromBackup(Map<String, dynamic> data) async {
    if (data['smsRules'] != null) {
      await importUserRules(jsonEncode(data['smsRules']));
    }
    if (data['disabledSmsRules'] != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final disabled = <String>{
          for (final id in jsonDecode(prefs.getString(disabledIdsKey) ?? '[]')
              as List)
            id as String,
          for (final id in data['disabledSmsRules'] as List) id as String,
        };
        await prefs.setString(disabledIdsKey, jsonEncode(disabled.toList()));
      } catch (_) {}
    }
    await load();
  }

  /// Parses either `{"rules": [...]}` or a bare `[...]` array, skipping
  /// entries that don't parse rather than losing the whole document.
  static List<SmsRule> parseRules(String json) {
    try {
      final decoded = jsonDecode(json);
      final list = decoded is Map ? decoded['rules'] as List? : decoded as List?;
      if (list == null) return const [];
      final rules = <SmsRule>[];
      for (final entry in list) {
        try {
          rules.add(SmsRule.fromJson(Map<String, dynamic>.from(entry as Map)));
        } catch (_) {}
      }
      return rules;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _persistUserRules(List<SmsRule> rules) async {
    _userRules = rules;
    _cache = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        userRulesKey,
        jsonEncode(rules.map((r) => r.toJson()).toList()),
      );
    } catch (_) {}
  }

  static Map<String, dynamic> _packJson() {
    final override = _packOverrideJson;
    if (override != null && override.isNotEmpty) {
      try {
        return Map<String, dynamic>.from(jsonDecode(override) as Map);
      } catch (_) {}
    }
    return Map<String, dynamic>.from(
      jsonDecode(builtinRulePackJson) as Map,
    );
  }

  static List<SmsRule> _packRules() => parseRules(jsonEncode(_packJson()));

  static SmsRuleConfig _build() {
    final pack = _packJson();
    final senders = Map<String, dynamic>.from(
      (pack['senders'] as Map?) ?? const {},
    );
    final keywords = Map<String, dynamic>.from(
      (pack['keywords'] as Map?) ?? const {},
    );

    final rules = <String, SmsRule>{};
    for (final rule in _packRules()) {
      if (_disabledIds.contains(rule.id)) continue;
      rules[rule.id] = rule;
    }
    for (final rule in _userRules) {
      if (!rule.enabled) {
        rules.remove(rule.id);
        continue;
      }
      rules[rule.id] = rule;
    }

    final ordered = rules.values.toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    return SmsRuleConfig(
      mobileMoneySenders: _lowerList(senders['mobileMoney']),
      bankSenders: _lowerList(senders['bank']),
      successKeywords: _lowerList(keywords['success']),
      successExclude: _lowerList(keywords['successExclude']),
      failureKeywords: _lowerList(keywords['failure']),
      rules: ordered,
    );
  }

  static List<String> _lowerList(dynamic raw) => [
        for (final v in (raw as List?) ?? const [])
          (v as String).toLowerCase(),
      ];
}
