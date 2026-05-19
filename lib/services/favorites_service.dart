import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/favorite_contact.dart';

class FavoritesService {
  static const String key = 'favorite_contacts';

  static Future<List<FavoriteContact>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key) ?? '[]';
    final List<dynamic> list = jsonDecode(raw);
    return list.map((e) => FavoriteContact.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> addFavorite(FavoriteContact contact) async {
    final favorites = await getFavorites();
    if (favorites.any((f) => f.phoneNumber == contact.phoneNumber)) return;
    favorites.add(contact);
    await _save(favorites);
  }

  static Future<void> removeFavorite(String phoneNumber) async {
    final favorites = await getFavorites();
    favorites.removeWhere((f) => f.phoneNumber == phoneNumber);
    await _save(favorites);
  }

  static Future<bool> isFavorite(String phoneNumber) async {
    final favorites = await getFavorites();
    return favorites.any((f) => f.phoneNumber == phoneNumber);
  }

  static Future<void> _save(List<FavoriteContact> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        key, jsonEncode(favorites.map((f) => f.toJson()).toList()));
  }
}
