import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/store.dart';

class SimpleStoreService {
  static const String _storesKey = 'cached_stores';
  static const String _favoritesKey = 'favorite_stores';
  static const String _lastUpdateKey = 'stores_last_update';
  static const String _userLocationKey = 'user_location';

  // Cache duration in hours
  static const int _cacheValidityHours = 6;

  // Singleton pattern
  static final SimpleStoreService _instance = SimpleStoreService._internal();
  factory SimpleStoreService() => _instance;
  SimpleStoreService._internal();

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
    if (_cachedStores.isEmpty || shouldRefresh) {
      await _loadCachedStores();
      await _loadFavorites();

      // Try to refresh from Firestore if needed
      if (shouldRefresh) {
        try {
          await _refreshFromFirestore();
        } catch (e) {
          print('Failed to refresh from Firestore: $e');
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
            'timestamp': DateTime.now().toIso8601String(),
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
      try {
        final List<dynamic> storeList = jsonDecode(cachedData);
        _cachedStores = storeList.map((json) => Store.fromJson(json)).toList();
      } catch (e) {
        print('Error loading cached stores: $e');
        _cachedStores = [];
      }
    } else {
      _cachedStores = [];
    }
  }

  // Load favorite stores from local storage
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList(_favoritesKey) ?? [];
      _favoriteStoreIds = favorites.toSet();
    } catch (e) {
      print('Error loading favorites: $e');
      _favoriteStoreIds = {};
    }
  }

  // Save stores to local storage
  Future<void> _saveCachedStores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storeList = _cachedStores.map((store) => store.toJson()).toList();
      await prefs.setString(_storesKey, jsonEncode(storeList));
    } catch (e) {
      print('Error saving stores: $e');
    }
  }

  // Refresh stores from Firestore
  Future<void> _refreshFromFirestore() async {
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('No internet connection');
      }

      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore.collection('stores').get();

      final stores = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Store.fromJson({
          'id': doc.id,
          ...data,
        });
      }).toList();

      _cachedStores = stores;
      await _saveCachedStores();

      // Update last refresh time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());

      print('Refreshed ${stores.length} stores from Firestore');
    } catch (e) {
      print('Error refreshing from Firestore: $e');
      rethrow;
    }
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

  // Toggle favorite status
  Future<void> toggleFavorite(String storeId) async {
    try {
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
    } catch (e) {
      print('Error toggling favorite: $e');
    }
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationData = prefs.getString(_userLocationKey);

      if (locationData != null) {
        final Map<String, dynamic> data = jsonDecode(locationData);
        return {
          'latitude': data['latitude'],
          'longitude': data['longitude'],
        };
      }
    } catch (e) {
      print('Error getting last known location: $e');
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storesKey);
      _cachedStores.clear();
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  // Get store by ID
  Store? getStoreById(String id) {
    try {
      return _cachedStores.firstWhere((store) => store.id == id);
    } catch (e) {
      return null;
    }
  }

  // Delete store by ID
  Future<bool> deleteStore(String storeId) async {
    try {
      print('Deleting store: $storeId');
      
      // Check connectivity before attempting Firestore operation
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        try {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('stores').doc(storeId).delete();
          print('✅ Store deleted from Firestore successfully: $storeId');
        } catch (e) {
          print('❌ Failed to delete store from Firestore: $e');
          // Continue with local storage even if Firestore fails
        }
      } else {
        print('⚠️ No internet connection, deleting from local cache only');
      }

      // Update local cache
      final index = _cachedStores.indexWhere((store) => store.id == storeId);
      if (index != -1) {
        _cachedStores.removeAt(index);

        // Remove from favorites if it was favorited
        _favoriteStoreIds.remove(storeId);

        // Save updated data to local storage
        await _saveCachedStores();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_favoritesKey, _favoriteStoreIds.toList());

        print('✅ Store deleted from local cache');
        return true;
      } else {
        print('❌ Store not found in local cache: $storeId');
        return false;
      }
    } catch (e) {
      print('❌ Error deleting store: $e');
      return false;
    }
  }

  // Delete multiple stores
  Future<int> deleteStores(List<String> storeIds) async {
    int deletedCount = 0;
    try {
      for (String storeId in storeIds) {
        if (await deleteStore(storeId)) {
          deletedCount++;
        }
      }
    } catch (e) {
      print('Error deleting multiple stores: $e');
    }
    return deletedCount;
  }

  // Add a new store
  Future<bool> addStore(Store store) async {
    try {
      print('Adding store: ${store.name} (ID: ${store.id})');
      
      // Check connectivity before attempting Firestore operation
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        try {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('stores').doc(store.id).set(store.toJson());
          print('✅ Store added to Firestore successfully: ${store.id}');
        } catch (e) {
          print('❌ Failed to add store to Firestore: $e');
          // Continue with local storage even if Firestore fails
        }
      } else {
        print('⚠️ No internet connection, saving to local cache only');
      }

      // Update local cache
      final existingIndex = _cachedStores.indexWhere((s) => s.id == store.id);
      if (existingIndex != -1) {
        // Update existing store
        _cachedStores[existingIndex] = store;
        print('Updated existing store in cache');
      } else {
        // Add new store
        _cachedStores.add(store);
        print('Added new store to cache');
      }

      await _saveCachedStores();
      print('✅ Store saved to local cache');
      return true;
    } catch (e) {
      print('❌ Error adding store: $e');
      return false;
    }
  }

  // Update existing store
  Future<bool> updateStore(Store updatedStore) async {
    try {
      print('Updating store: ${updatedStore.name} (ID: ${updatedStore.id})');
      
      // Check connectivity before attempting Firestore operation
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        try {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('stores').doc(updatedStore.id).update(updatedStore.toJson());
          print('✅ Store updated in Firestore successfully: ${updatedStore.id}');
        } catch (e) {
          print('❌ Failed to update store in Firestore: $e');
          // Continue with local storage even if Firestore fails
        }
      } else {
        print('⚠️ No internet connection, updating local cache only');
      }

      // Update local cache
      final index =
          _cachedStores.indexWhere((store) => store.id == updatedStore.id);
      if (index != -1) {
        _cachedStores[index] = updatedStore;
        await _saveCachedStores();
        print('✅ Store updated in local cache');
        return true;
      } else {
        print('❌ Store not found in local cache: ${updatedStore.id}');
        return false;
      }
    } catch (e) {
      print('❌ Error updating store: $e');
      return false;
    }
  }

  // Search stores based on query
  Future<List<Store>> searchStores(
    String query, {
    double? userLatitude,
    double? userLongitude,
  }) async {
    if (query.isEmpty) {
      return await getStores(
        userLatitude: userLatitude,
        userLongitude: userLongitude,
      );
    }

    // Ensure we have stores loaded
    if (_cachedStores.isEmpty) {
      await getStores(
        userLatitude: userLatitude,
        userLongitude: userLongitude,
      );
    }

    final lowercaseQuery = query.toLowerCase();

    final filteredStores = _cachedStores.where((store) {
      return store.name.toLowerCase().contains(lowercaseQuery) ||
          store.paymentCode.toLowerCase().contains(lowercaseQuery) ||
          store.paymentType.toLowerCase().contains(lowercaseQuery) ||
          (store.categories?.any((category) =>
                  category.toLowerCase().contains(lowercaseQuery)) ??
              false) ||
          (store.description?.toLowerCase().contains(lowercaseQuery) ??
              false) ||
          (store.address?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();

    // Calculate distances if user location is provided
    if (userLatitude != null && userLongitude != null) {
      for (var store in filteredStores) {
        store.distance = _calculateDistance(
            userLatitude, userLongitude, store.latitude, store.longitude);
      }

      // Sort by distance
      filteredStores
          .sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
    }

    // Update favorite status
    for (var store in filteredStores) {
      store.isFavorite = _favoriteStoreIds.contains(store.id);
    }

    return filteredStores;
  }
}
