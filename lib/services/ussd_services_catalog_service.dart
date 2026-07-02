import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ussd_service_shortcut.dart';

class UssdServicesCatalogService {
  static const String key = 'ussd_services';

  static List<UssdServiceShortcut> get defaultServices => [
        const UssdServiceShortcut(
          id: 'builtin-umutekano',
          label: 'Umutekano',
          serviceKey: 'umutekano',
          ussdCode: '*152#',
          defaultUssdCode: '*152#',
          isBuiltIn: true,
        ),
        const UssdServiceShortcut(
          id: 'builtin-efashe',
          label: 'Cash Power',
          serviceKey: 'efashe',
          ussdCode: '*662*1*3#',
          defaultUssdCode: '*662*1*3#',
          isBuiltIn: true,
        ),
        const UssdServiceShortcut(
          id: 'builtin-canalbox',
          label: 'Canalbox',
          serviceKey: 'canalbox',
          ussdCode: '*860#',
          defaultUssdCode: '*860#',
          isBuiltIn: true,
        ),
        const UssdServiceShortcut(
          id: 'builtin-yego',
          label: 'Yego Cab',
          serviceKey: 'yego',
          ussdCode: null,
          defaultUssdCode: null,
          isBuiltIn: true,
        ),
        const UssdServiceShortcut(
          id: 'builtin-bk',
          label: 'BK Bank',
          serviceKey: 'bk',
          ussdCode: null,
          defaultUssdCode: null,
          isBuiltIn: true,
        ),
      ];

  static Future<List<UssdServiceShortcut>> getServices() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(key)) {
      await _save(prefs, defaultServices);
      return defaultServices;
    }
    final raw = prefs.getString(key) ?? '[]';
    final List<dynamic> list = jsonDecode(raw);
    return list
        .map((e) => UssdServiceShortcut.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> addService(UssdServiceShortcut service) async {
    final services = await getServices();
    services.add(service);
    final prefs = await SharedPreferences.getInstance();
    await _save(prefs, services);
  }

  static Future<void> updateService(UssdServiceShortcut updated) async {
    final services = await getServices();
    final index = services.indexWhere((s) => s.id == updated.id);
    if (index == -1) return;
    services[index] = updated;
    final prefs = await SharedPreferences.getInstance();
    await _save(prefs, services);
  }

  static Future<void> deleteService(String id) async {
    final services = await getServices();
    services.removeWhere((s) => s.id == id);
    final prefs = await SharedPreferences.getInstance();
    await _save(prefs, services);
  }

  /// Re-adds any built-in service that's missing (deleted or never seeded)
  /// and restores its USSD code to the original default.
  static Future<void> restoreDefaults() async {
    final services = await getServices();
    final existingIds = services.map((s) => s.id).toSet();

    for (final builtin in defaultServices) {
      final index = services.indexWhere((s) => s.id == builtin.id);
      if (index == -1) {
        services.add(builtin);
      } else if (!existingIds.contains(builtin.id)) {
        services.add(builtin);
      } else {
        services[index] = services[index].copyWith(
          ussdCode: builtin.ussdCode,
          clearUssdCode: builtin.ussdCode == null,
        );
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await _save(prefs, services);
  }

  static Future<void> _save(
      SharedPreferences prefs, List<UssdServiceShortcut> services) async {
    await prefs.setString(
        key, jsonEncode(services.map((s) => s.toJson()).toList()));
  }
}
