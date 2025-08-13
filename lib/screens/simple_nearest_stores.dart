import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/store.dart';
import '../services/simple_store_service.dart';
import '../helpers/launcher.dart';
import 'store_details_screen.dart';
import 'store_edit_screen.dart';
import 'store_add_screen.dart';

class SimpleNearestStoresPage extends StatefulWidget {
  @override
  _SimpleNearestStoresPageState createState() =>
      _SimpleNearestStoresPageState();
}

class _SimpleNearestStoresPageState extends State<SimpleNearestStoresPage> {
  final SimpleStoreService _storeService = SimpleStoreService();
  final TextEditingController _searchController = TextEditingController();
  List<Store> _allStores = [];
  List<Store> _filteredStores = [];
  bool _isLoading = true;
  bool _isSearching = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchNearestStores();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _filteredStores = _allStores;
        _isSearching = false;
      });
    } else {
      _performSearch(_searchController.text);
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);

    try {
      final searchResults = await _storeService.searchStores(
        query,
        userLatitude: _currentPosition?.latitude,
        userLongitude: _currentPosition?.longitude,
      );

      setState(() {
        _filteredStores = searchResults;
        _isSearching = false;
      });
    } catch (e) {
      print('Search error: $e');
      setState(() => _isSearching = false);
    }
  }

  Future<void> _fetchNearestStores({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);

    try {
      // Try to get current position
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          if (permission != LocationPermission.denied &&
              permission != LocationPermission.deniedForever) {
            _currentPosition = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            );
          }
        }
      } catch (e) {
        print('Location error: $e');
      }

      // Fetch stores
      final stores = await _storeService.getStores(
        userLatitude: _currentPosition?.latitude,
        userLongitude: _currentPosition?.longitude,
        forceRefresh: forceRefresh,
      );

      setState(() {
        _allStores = stores;
        _filteredStores = stores;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching stores: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error fetching stores: $e"),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteStore(Store store) async {
    final confirmed = await _showDeleteConfirmation(store);
    if (confirmed == true) {
      final success = await _storeService.deleteStore(store.id);
      if (success) {
        setState(() {
          _allStores.removeWhere((s) => s.id == store.id);
          _filteredStores.removeWhere((s) => s.id == store.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${store.name} deleted successfully'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () => _undoDeleteStore(store),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete ${store.name}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool?> _showDeleteConfirmation(Store store) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Store'),
          content: Text('Are you sure you want to delete "${store.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _undoDeleteStore(Store store) async {
    final success = await _storeService.addStore(store);
    if (success) {
      setState(() {
        _allStores.add(store);
        // Re-apply current search filter
        if (_searchController.text.isNotEmpty) {
          _performSearch(_searchController.text);
        } else {
          _filteredStores = _allStores;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${store.name} restored'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _toggleFavorite(Store store) async {
    await _storeService.toggleFavorite(store.id);
    setState(() {
      final index = _allStores.indexWhere((s) => s.id == store.id);
      if (index != -1) {
        _allStores[index] = _allStores[index]
            .copyWith(isFavorite: !_allStores[index].isFavorite);
      }

      final filteredIndex = _filteredStores.indexWhere((s) => s.id == store.id);
      if (filteredIndex != -1) {
        _filteredStores[filteredIndex] = _filteredStores[filteredIndex]
            .copyWith(isFavorite: !_filteredStores[filteredIndex].isFavorite);
      }
    });
  }

  Future<void> _editStore(Store store) async {
    final result = await Navigator.push<Store>(
      context,
      MaterialPageRoute(
        builder: (context) => StoreEditScreen(store: store),
      ),
    );

    if (result != null) {
      // Update the store in both lists
      setState(() {
        final allIndex = _allStores.indexWhere((s) => s.id == store.id);
        if (allIndex != -1) {
          _allStores[allIndex] = result;
        }

        final filteredIndex =
            _filteredStores.indexWhere((s) => s.id == store.id);
        if (filteredIndex != -1) {
          _filteredStores[filteredIndex] = result;
        }
      });
    }
  }

  Future<void> _addStore() async {
    final result = await Navigator.push<Store>(
      context,
      MaterialPageRoute(
        builder: (context) => StoreAddScreen(),
      ),
    );

    if (result != null) {
      // Add the new store to both lists
      setState(() {
        _allStores.add(result);
        // Re-apply current search filter
        if (_searchController.text.isNotEmpty) {
          _performSearch(_searchController.text);
        } else {
          _filteredStores = _allStores;
        }
      });
    }
  }

  void _makePayment(Store store) {
    try {
      String input = store.paymentCode;
      String ussdCode = input.contains('*') && input.contains('#')
          ? input
          : "*182*${RegExp(r'^(?:\+2507|2507|07|7)[0-9]{8}$').hasMatch(input) ? '1' : '8'}*1*${input}#";

      launchUSSD(ussdCode, context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to launch payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStoreCard(Store store) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: store.isFavorite ? Colors.red : Colors.blue,
          child: Icon(
            store.isFavorite ? Icons.favorite : Icons.store,
            color: Colors.white,
          ),
        ),
        title: Text(
          store.name,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${store.paymentType}: ${store.paymentCode}"),
            if (store.distance != null)
              Text(
                "${store.distance!.toStringAsFixed(2)} km away",
                style: TextStyle(color: Colors.green),
              ),
            if (store.categories != null && store.categories!.isNotEmpty)
              Text(
                store.categories!.join(', '),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'favorite':
                _toggleFavorite(store);
                break;
              case 'edit':
                _editStore(store);
                break;
              case 'delete':
                _deleteStore(store);
                break;
              case 'pay':
                _makePayment(store);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'pay',
              child: Row(
                children: [
                  Icon(Icons.payment, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Pay Now'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'favorite',
              child: Row(
                children: [
                  Icon(
                    store.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: store.isFavorite ? Colors.red : null,
                  ),
                  SizedBox(width: 8),
                  Text(store.isFavorite
                      ? 'Remove from Favorites'
                      : 'Add to Favorites'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Edit Store'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete Store'),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StoreDetailsScreen(store: store),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Stores"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => _fetchNearestStores(forceRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search stores by name, payment type, or category...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          // Results
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _isSearching
                    ? Center(child: CircularProgressIndicator())
                    : _filteredStores.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.store_outlined,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  _searchController.text.isNotEmpty
                                      ? 'No stores found for "${_searchController.text}"'
                                      : 'No stores found',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredStores.length,
                            itemBuilder: (context, index) {
                              return _buildStoreCard(_filteredStores[index]);
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "add",
            onPressed: _addStore,
            child: Icon(Icons.add),
            tooltip: 'Add Store',
            backgroundColor: Colors.green,
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "refresh",
            onPressed: () => _fetchNearestStores(forceRefresh: true),
            child: Icon(Icons.refresh),
            tooltip: 'Refresh stores',
          ),
        ],
      ),
    );
  }
}
