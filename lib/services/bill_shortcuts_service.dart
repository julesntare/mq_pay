import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bill_shortcut.dart';

class BillShortcutsService {
  static const String key = 'bill_shortcuts';

  static Future<List<BillShortcut>> getShortcuts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key) ?? '[]';
    final List<dynamic> list = jsonDecode(raw);
    return list
        .map((e) => BillShortcut.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> addShortcut(BillShortcut shortcut) async {
    final shortcuts = await getShortcuts();
    shortcuts.add(shortcut);
    await _save(shortcuts);
  }

  static Future<void> removeShortcut(String id) async {
    final shortcuts = await getShortcuts();
    shortcuts.removeWhere((s) => s.id == id);
    await _save(shortcuts);
  }

  static Future<void> _save(List<BillShortcut> shortcuts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        key, jsonEncode(shortcuts.map((s) => s.toJson()).toList()));
  }
}
