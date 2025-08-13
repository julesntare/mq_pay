import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/store.dart';
import '../helpers/launcher.dart';
import '../services/store_service.dart';

class StoreDetailsScreen extends StatefulWidget {
  final Store store;

  const StoreDetailsScreen({Key? key, required this.store}) : super(key: key);

  @override
  _StoreDetailsScreenState createState() => _StoreDetailsScreenState();
}

class _StoreDetailsScreenState extends State<StoreDetailsScreen> {
  final StoreService _storeService = StoreService();
  late Store _store;

  @override
  void initState() {
    super.initState();
    _store = widget.store;
  }

  Future<void> _toggleFavorite() async {
    await _storeService.toggleFavorite(_store.id);
    setState(() {
      _store = _store.copyWith(isFavorite: !_store.isFavorite);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_store.isFavorite
            ? 'Added to favorites'
            : 'Removed from favorites'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _makePayment() async {
    try {
      String input = _store.paymentCode;
      String ussdCode = input.contains('*') && input.contains('#')
          ? input
          : "*182*${RegExp(r'^(?:\+2507|2507|07|7)[0-9]{8}$').hasMatch(input) ? '1' : '8'}*1*${input}#";

      launchUSSD(ussdCode, context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch payment: $e')),
      );
    }
  }

  Future<void> _callStore() async {
    if (_store.phoneNumber != null) {
      final url = 'tel:${_store.phoneNumber}';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot make phone calls')),
        );
      }
    }
  }

  Future<void> _openMaps() async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${_store.latitude},${_store.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_store.name),
        actions: [
          IconButton(
            icon: Icon(
              _store.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _store.isFavorite ? Colors.red : null,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store name and basic info
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _store.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    if (_store.description != null)
                      Text(
                        _store.description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.payment, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('${_store.paymentType}: ${_store.paymentCode}'),
                      ],
                    ),
                    if (_store.distance != null) ...[
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                              '${_store.distance!.toStringAsFixed(2)} km away'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Categories
            if (_store.categories != null && _store.categories!.isNotEmpty) ...[
              Text(
                'Categories',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _store.categories!
                    .map((category) => Chip(label: Text(category)))
                    .toList(),
              ),
              SizedBox(height: 16),
            ],

            // Address
            if (_store.address != null) ...[
              Text(
                'Address',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(Icons.location_on),
                  title: Text(_store.address!),
                  trailing: IconButton(
                    icon: Icon(Icons.map),
                    onPressed: _openMaps,
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],

            // Opening hours
            if (_store.openingHours != null &&
                _store.openingHours!.isNotEmpty) ...[
              Text(
                'Opening Hours',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: _store.openingHours!.entries
                        .map((entry) => Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(entry.key),
                                  Text(entry.value),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],

            // Contact information
            if (_store.phoneNumber != null) ...[
              Text(
                'Contact',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(Icons.phone),
                  title: Text(_store.phoneNumber!),
                  trailing: IconButton(
                    icon: Icon(Icons.call),
                    onPressed: _callStore,
                  ),
                ),
              ),
              SizedBox(height: 24),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _makePayment,
                    icon: Icon(Icons.payment),
                    label: Text('Pay Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openMaps,
                    icon: Icon(Icons.directions),
                    label: Text('Directions'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
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
}
