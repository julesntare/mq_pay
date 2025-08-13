import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/store.dart';
import '../services/store_service.dart';
import '../helpers/launcher.dart';
import 'store_details_screen.dart';

class NearestStoresPage extends StatefulWidget {
  @override
  _NearestStoresPageState createState() => _NearestStoresPageState();
}

class _NearestStoresPageState extends State<NearestStoresPage>
    with TickerProviderStateMixin {
  final StoreService _storeService = StoreService();
  List<Store> _allStores = [];
  List<Store> _filteredStores = [];
  bool _isLoading = true;
  bool _isOnline = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _showFavoritesOnly = false;

  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  Position? _currentPosition;
  Set<String> _categories = {'All'};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkConnectivity();
    _fetchNearestStores();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _setupConnectivityListener() {
    try {
      Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
        setState(() {
          _isOnline = result != ConnectivityResult.none;
        });
      });
    } catch (e) {
      print('Connectivity plugin error: $e');
      // Assume online if plugin fails
      setState(() {
        _isOnline = true;
      });
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      setState(() {
        _isOnline = connectivityResult != ConnectivityResult.none;
      });
    } catch (e) {
      print('Connectivity check error: $e');
      // Assume online if plugin fails
      setState(() {
        _isOnline = true;
      });
    }
  }

  Future<void> _fetchNearestStores({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);

    try {
      // Try to get current position
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception('Location services are disabled');
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            throw Exception('Location permissions are denied');
          }
        }

        if (permission == LocationPermission.deniedForever) {
          throw Exception('Location permissions are permanently denied');
        }

        _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        );
      } catch (e) {
        print('Location error: $e');
        // Try to get last known location from storage
        final lastLocation = await _storeService.getLastKnownLocation();
        if (lastLocation != null) {
          _currentPosition = Position(
            latitude: lastLocation['latitude']!,
            longitude: lastLocation['longitude']!,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        }
      }

      // Fetch stores
      final stores = await _storeService.getStores(
        userLatitude: _currentPosition?.latitude,
        userLongitude: _currentPosition?.longitude,
        forceRefresh: forceRefresh,
      );

      // Extract categories
      final categories = <String>{'All'};
      for (final store in stores) {
        if (store.categories != null) {
          categories.addAll(store.categories!);
        }
      }

      setState(() {
        _allStores = stores;
        _categories = categories;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching stores: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isOnline
              ? "Error fetching stores: $e"
              : "Using offline data. Error: $e"),
          backgroundColor: _isOnline ? Colors.red : Colors.orange,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<Store> filtered = List.from(_allStores);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = _storeService.searchStores(_searchQuery);
    }

    // Apply category filter
    if (_selectedCategory != 'All') {
      filtered = filtered.where((store) {
        return store.categories?.contains(_selectedCategory) ?? false;
      }).toList();
    }

    // Apply favorites filter
    if (_showFavoritesOnly) {
      filtered = filtered.where((store) => store.isFavorite).toList();
    }

    setState(() {
      _filteredStores = filtered;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyFilters();
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _applyFilters();
  }

  void _toggleFavoritesOnly() {
    setState(() {
      _showFavoritesOnly = !_showFavoritesOnly;
    });
    _applyFilters();
  }

  Future<void> _toggleStoreFavorite(Store store) async {
    await _storeService.toggleFavorite(store.id);
    setState(() {
      final index = _allStores.indexWhere((s) => s.id == store.id);
      if (index != -1) {
        _allStores[index] = _allStores[index]
            .copyWith(isFavorite: !_allStores[index].isFavorite);
      }
    });
    _applyFilters();
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search stores...',
          prefixIcon: Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Favorites filter
          FilterChip(
            label: Text('Favorites Only'),
            selected: _showFavoritesOnly,
            onSelected: (_) => _toggleFavoritesOnly(),
            avatar: Icon(Icons.favorite),
          ),
          SizedBox(width: 8),
          // Category filters
          ..._categories.map((category) => Padding(
                padding: EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(category),
                  selected: _selectedCategory == category,
                  onSelected: (_) => _onCategoryChanged(category),
                ),
              )),
        ],
      ),
    );
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                store.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: store.isFavorite ? Colors.red : null,
              ),
              onPressed: () => _toggleStoreFavorite(store),
            ),
            ElevatedButton(
              onPressed: () {
                String input = store.paymentCode;
                launchUSSD(
                  input.contains('*') && input.contains('#')
                      ? input
                      : "*182*${RegExp(r'^(?:\+2507|2507|07|7)[0-9]{8}$').hasMatch(input) ? '1' : '8'}*1*${input}#",
                  context,
                );
              },
              child: Text("Pay"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
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

  Widget _buildStoresList() {
    if (_filteredStores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              _showFavoritesOnly
                  ? 'No favorite stores found'
                  : _searchQuery.isNotEmpty
                      ? 'No stores match your search'
                      : 'No stores found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (!_isOnline) ...[
              SizedBox(height: 8),
              Text(
                'You are offline',
                style: TextStyle(color: Colors.orange),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredStores.length,
      itemBuilder: (context, index) {
        return _buildStoreCard(_filteredStores[index]);
      },
    );
  }

  Widget _buildFavoritesList() {
    final favorites = _storeService.getFavoriteStores();

    if (favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No favorite stores yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the heart icon on stores to add them to favorites',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        return _buildStoreCard(favorites[index]);
      },
    );
  }

  Widget _buildCategoriesList() {
    final categorizedStores = <String, List<Store>>{};

    for (final store in _allStores) {
      if (store.categories != null) {
        for (final category in store.categories!) {
          if (!categorizedStores.containsKey(category)) {
            categorizedStores[category] = [];
          }
          categorizedStores[category]!.add(store);
        }
      }
    }

    if (categorizedStores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No categories available',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: categorizedStores.length,
      itemBuilder: (context, index) {
        final category = categorizedStores.keys.elementAt(index);
        final stores = categorizedStores[category]!;

        return ExpansionTile(
          leading: Icon(Icons.category),
          title: Text(category),
          subtitle: Text('${stores.length} stores'),
          children: stores.map((store) => _buildStoreCard(store)).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Stores"),
        actions: [
          if (!_isOnline) Icon(Icons.cloud_off, color: Colors.orange),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => _fetchNearestStores(forceRefresh: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.location_on), text: "Nearest"),
            Tab(icon: Icon(Icons.favorite), text: "Favorites"),
            Tab(icon: Icon(Icons.category), text: "Categories"),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_isOnline)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8),
                    color: Colors.orange,
                    child: Text(
                      'Offline mode - Using cached data',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                _buildSearchBar(),
                _buildFilters(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStoresList(),
                      _buildFavoritesList(),
                      _buildCategoriesList(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _currentPosition != null
          ? FloatingActionButton(
              onPressed: () => _fetchNearestStores(forceRefresh: true),
              child: Icon(Icons.my_location),
              tooltip: 'Refresh location and stores',
            )
          : null,
    );
  }
}
