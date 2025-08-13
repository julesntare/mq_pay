import 'package:flutter/material.dart';
import '../models/store.dart';
import '../services/simple_store_service.dart';

class StoreEditScreen extends StatefulWidget {
  final Store store;

  const StoreEditScreen({Key? key, required this.store}) : super(key: key);

  @override
  _StoreEditScreenState createState() => _StoreEditScreenState();
}

class _StoreEditScreenState extends State<StoreEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final SimpleStoreService _storeService = SimpleStoreService();

  late TextEditingController _nameController;
  late TextEditingController _paymentCodeController;
  late TextEditingController _paymentTypeController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  late TextEditingController _addressController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoriesController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.store.name);
    _paymentCodeController =
        TextEditingController(text: widget.store.paymentCode);
    _paymentTypeController =
        TextEditingController(text: widget.store.paymentType);
    _latitudeController =
        TextEditingController(text: widget.store.latitude.toString());
    _longitudeController =
        TextEditingController(text: widget.store.longitude.toString());
    _addressController =
        TextEditingController(text: widget.store.address ?? '');
    _descriptionController =
        TextEditingController(text: widget.store.description ?? '');
    _categoriesController =
        TextEditingController(text: widget.store.categories?.join(', ') ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _paymentCodeController.dispose();
    _paymentTypeController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _categoriesController.dispose();
    super.dispose();
  }

  Future<void> _saveStore() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Parse categories
      List<String>? categories;
      if (_categoriesController.text.trim().isNotEmpty) {
        categories = _categoriesController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      // Create updated store
      final updatedStore = widget.store.copyWith(
        name: _nameController.text.trim(),
        paymentCode: _paymentCodeController.text.trim(),
        paymentType: _paymentTypeController.text.trim(),
        latitude: double.parse(_latitudeController.text.trim()),
        longitude: double.parse(_longitudeController.text.trim()),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        categories: categories,
      );

      final success = await _storeService.updateStore(updatedStore);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Store updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(updatedStore); // Return updated store
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update store'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Store'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveStore,
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16.0),
          children: [
            // Store Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Store Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Store name is required';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // Payment Type
            TextFormField(
              controller: _paymentTypeController,
              decoration: InputDecoration(
                labelText: 'Payment Type *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payment),
                hintText: 'e.g., MTN MoMo, Airtel Money, Bank',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Payment type is required';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // Payment Code
            TextFormField(
              controller: _paymentCodeController,
              decoration: InputDecoration(
                labelText: 'Payment Code *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.code),
                hintText: 'Phone number or payment identifier',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Payment code is required';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // Location Section
            Text(
              'Location',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),

            // Latitude
            TextFormField(
              controller: _latitudeController,
              decoration: InputDecoration(
                labelText: 'Latitude *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Latitude is required';
                }
                final lat = double.tryParse(value.trim());
                if (lat == null || lat < -90 || lat > 90) {
                  return 'Invalid latitude (-90 to 90)';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // Longitude
            TextFormField(
              controller: _longitudeController,
              decoration: InputDecoration(
                labelText: 'Longitude *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Longitude is required';
                }
                final lng = double.tryParse(value.trim());
                if (lng == null || lng < -180 || lng > 180) {
                  return 'Invalid longitude (-180 to 180)';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // Address
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
                hintText: 'Street address or location description',
              ),
              maxLines: 2,
            ),
            SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                hintText: 'Additional information about the store',
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),

            // Categories
            TextFormField(
              controller: _categoriesController,
              decoration: InputDecoration(
                labelText: 'Categories',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
                hintText: 'Comma-separated (e.g., Grocery, Electronics)',
              ),
            ),
            SizedBox(height: 24),

            // Help text
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[600], size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Tips:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Fields marked with * are required\n'
                    '• Use GPS coordinates for accurate location\n'
                    '• Categories help users find your store in search',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
