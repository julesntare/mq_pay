import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/store.dart';
import '../services/simple_store_service.dart';
import '../helpers/launcher.dart';
import '../helpers/app_theme.dart';
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
    final theme = Theme.of(context);

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: theme.colorScheme.surface,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.delete_rounded,
                    color: AppTheme.errorColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Delete Store',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to delete "${store.name}"? This action cannot be undone.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StoreDetailsScreen(store: store),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Store Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: store.isFavorite
                            ? LinearGradient(
                                colors: [
                                  Colors.pink.shade400,
                                  Colors.red.shade400
                                ],
                              )
                            : AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (store.isFavorite
                                    ? Colors.pink
                                    : theme.colorScheme.primary)
                                .withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        store.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.store_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Store Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.payment_rounded,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${store.paymentType}: ${store.paymentCode}",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // More Options
                    Container(
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
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
                          _buildPopupMenuItem(
                            value: 'pay',
                            icon: Icons.payment_rounded,
                            text: 'Pay Now',
                            color: AppTheme.successColor,
                          ),
                          _buildPopupMenuItem(
                            value: 'favorite',
                            icon: store.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            text: store.isFavorite
                                ? 'Remove from Favorites'
                                : 'Add to Favorites',
                            color: store.isFavorite
                                ? Colors.red
                                : Colors.grey.shade600,
                          ),
                          _buildPopupMenuItem(
                            value: 'edit',
                            icon: Icons.edit_rounded,
                            text: 'Edit Store',
                            color: AppTheme.primaryColor,
                          ),
                          _buildPopupMenuItem(
                            value: 'delete',
                            icon: Icons.delete_rounded,
                            text: 'Delete Store',
                            color: AppTheme.errorColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Store Details
                const SizedBox(height: 16),

                // Distance and Categories
                Row(
                  children: [
                    if (store.distance != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: AppTheme.successColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${store.distance!.toStringAsFixed(2)} km",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.successColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (store.categories != null &&
                        store.categories!.isNotEmpty) ...[
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: store.categories!.take(2).map((category) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                category,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),

                // Action Button
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _makePayment(store),
                    icon: const Icon(Icons.payment_rounded),
                    label: const Text('Pay Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required String value,
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.store_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nearby Stores',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Find stores near you',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Refresh Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.white),
                          onPressed: () =>
                              _fetchNearestStores(forceRefresh: true),
                          tooltip: 'Refresh stores',
                        ),
                      ),
                    ],
                  ),

                  // Search Bar
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Search stores, payment types, categories...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? _buildLoadingState(context, theme)
                  : _isSearching
                      ? _buildLoadingState(context, theme)
                      : _filteredStores.isEmpty
                          ? _buildEmptyState(context, theme)
                          : _buildStoresList(context, theme),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.secondaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.secondaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton(
              heroTag: "add",
              onPressed: _addStore,
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
              tooltip: 'Add Store',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading stores...',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                _searchController.text.isNotEmpty
                    ? Icons.search_off_rounded
                    : Icons.store_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No stores found'
                  : 'No stores available',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No stores found for "${_searchController.text}". Try adjusting your search.'
                  : 'Start by adding your first store or refresh to load stores.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_searchController.text.isEmpty) ...[
                  ElevatedButton.icon(
                    onPressed: _addStore,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Store'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                OutlinedButton.icon(
                  onPressed: () => _fetchNearestStores(forceRefresh: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoresList(BuildContext context, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 20),
      itemCount: _filteredStores.length,
      itemBuilder: (context, index) {
        return _buildStoreCard(_filteredStores[index]);
      },
    );
  }
}
