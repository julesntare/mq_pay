import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/store.dart';

class StoreService {
  static const String _storesKey = 'cached_stores';
  static const String _favoritesKey = 'favorite_stores';
  static const String _lastUpdateKey = 'stores_last_update';
  static const String _userLocationKey = 'user_location';

  // Cache duration in hours
  static const int _cacheValidityHours = 6;

  // Singleton pattern
  static final StoreService _instance = StoreService._internal();
  factory StoreService() => _instance;
  StoreService._internal();

  List<Store> _cachedStores = [];
  Set<String> _favoriteStoreIds = {};

  // Get stores with local storage caching
  Future<List<Store>> getStores({
    double? userLatitude,
    double? userLongitude,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Check if we need to refresh
    final lastUpdate = prefs.getString(_lastUpdateKey);
    final now = DateTime.now();
    bool shouldRefresh = forceRefresh;

    if (lastUpdate != null) {
      final lastUpdateTime = DateTime.parse(lastUpdate);
      final hoursSinceUpdate = now.difference(lastUpdateTime).inHours;
      shouldRefresh = shouldRefresh || hoursSinceUpdate >= _cacheValidityHours;
    } else {
      shouldRefresh = true;
    }

    // Load cached stores first
    if (_cachedStores.isEmpty) {
      await _loadCachedStores();
      await _loadFavorites();
    }

    // Try to refresh if needed and online
    if (shouldRefresh) {
      bool isOnline = true;
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        isOnline = connectivityResult != ConnectivityResult.none;
      } catch (e) {
        print('Connectivity check failed: $e');
        // Assume online and try to fetch anyway
        isOnline = true;
      }

      if (isOnline) {
        try {
          await _refreshStoresFromRemote();
          await prefs.setString(_lastUpdateKey, now.toIso8601String());
        } catch (e) {
          print('Failed to refresh stores from remote: $e');
          // Continue with cached data
        }
      }
    }

    // Calculate distances if user location is provided
    if (userLatitude != null && userLongitude != null) {
      for (var store in _cachedStores) {
        store.distance = _calculateDistance(
            userLatitude, userLongitude, store.latitude, store.longitude);
      }

      // Sort by distance
      _cachedStores
          .sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));

      // Save user location for offline use
      await prefs.setString(
          _userLocationKey,
          jsonEncode({
            'latitude': userLatitude,
            'longitude': userLongitude,
            'timestamp': now.toIso8601String(),
          }));
    }

    // Update favorite status
    for (var store in _cachedStores) {
      store.isFavorite = _favoriteStoreIds.contains(store.id);
    }

    return List.from(_cachedStores);
  }

  // Load cached stores from local storage
  Future<void> _loadCachedStores() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_storesKey);

    if (cachedData != null) {
      final List<dynamic> storeList = jsonDecode(cachedData);
      _cachedStores = storeList.map((json) => Store.fromJson(json)).toList();
    } else {
      await _saveCachedStores();
    }
  }

  // Load favorite stores from local storage
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_favoritesKey) ?? [];
    _favoriteStoreIds = favorites.toSet();
  }

  // Refresh stores from remote source (Firebase or API)
  Future<void> _refreshStoresFromRemote() async {
    List<Store> stores = [];

    try {
      // Try Firebase first
      final querySnapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('isActive', isEqualTo: true)
          .get();

      stores = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Store.fromJson({
          'id': doc.id,
          ...data,
        });
      }).toList();
    } catch (e) {
      print('Firebase fetch failed, trying fallback API: $e');

      // Fallback to standard HTTP API if available
      try {
        stores = await _fetchFromStandardAPI();
      } catch (apiError) {
        print('Standard API fetch failed: $apiError');

        // Fallback to sample data if both Firebase and API fail
        print('Using sample data as fallback');
      }
    }

    if (stores.isNotEmpty) {
      _cachedStores = stores;
      await _saveCachedStores();
    }
  }

  // Fetch from a standard HTTP API (implement based on your backend)
  Future<List<Store>> _fetchFromStandardAPI() async {
    // Replace with your actual API endpoint
    const String apiUrl = 'https://your-api.com/stores';

    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> storeList = data['stores'] ?? [];

      return storeList.map((json) => Store.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch stores: ${response.statusCode}');
    }
  }

  // Save stores to local storage
  Future<void> _saveCachedStores() async {
    final prefs = await SharedPreferences.getInstance();
    final storeList = _cachedStores.map((store) => store.toJson()).toList();
    await prefs.setString(_storesKey, jsonEncode(storeList));
  }

  // Calculate distance between two coordinates
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Radius of Earth in km
    double dLat = _degToRad(lat2 - lat1);
    double dLon = _degToRad(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) {
    return deg * (pi / 180);
  }

  // Search stores by name or payment type
  List<Store> searchStores(String query) {
    if (query.isEmpty) return _cachedStores;

    final lowercaseQuery = query.toLowerCase();
    return _cachedStores.where((store) {
      return store.name.toLowerCase().contains(lowercaseQuery) ||
          store.paymentType.toLowerCase().contains(lowercaseQuery) ||
          (store.categories
                  ?.any((cat) => cat.toLowerCase().contains(lowercaseQuery)) ??
              false) ||
          (store.address?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  // Toggle favorite status
  Future<void> toggleFavorite(String storeId) async {
    if (_favoriteStoreIds.contains(storeId)) {
      _favoriteStoreIds.remove(storeId);
    } else {
      _favoriteStoreIds.add(storeId);
    }

    // Update in cached stores
    final storeIndex = _cachedStores.indexWhere((s) => s.id == storeId);
    if (storeIndex != -1) {
      _cachedStores[storeIndex] = _cachedStores[storeIndex]
          .copyWith(isFavorite: _favoriteStoreIds.contains(storeId));
    }

    // Save to local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favoriteStoreIds.toList());
  }

  // Get favorite stores
  List<Store> getFavoriteStores() {
    return _cachedStores.where((store) => store.isFavorite).toList();
  }

  // Get stores by category
  List<Store> getStoresByCategory(String category) {
    return _cachedStores.where((store) {
      return store.categories?.contains(category) ?? false;
    }).toList();
  }

  // Get last known user location
  Future<Map<String, double>?> getLastKnownLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final locationData = prefs.getString(_userLocationKey);

    if (locationData != null) {
      final Map<String, dynamic> data = jsonDecode(locationData);
      return {
        'latitude': data['latitude'],
        'longitude': data['longitude'],
      };
    }

    return null;
  }

  // Force refresh stores
  Future<void> forceRefresh({
    double? userLatitude,
    double? userLongitude,
  }) async {
    await getStores(
      userLatitude: userLatitude,
      userLongitude: userLongitude,
      forceRefresh: true,
    );
  }

  // Clear cache
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storesKey);
    await prefs.remove(_lastUpdateKey);
    _cachedStores.clear();
  }

  // Get store by ID
  Store? getStoreById(String id) {
    try {
      return _cachedStores.firstWhere((store) => store.id == id);
    } catch (e) {
      return null;
    }
  }
}
