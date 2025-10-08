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
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  late TextEditingController _addressController;
  late TextEditingController _descriptionController;

  bool _isLoading = false;

  // Dropdown values
  String? _selectedPaymentType;
  List<String> _selectedCategories = [];

  // Dropdown options
  final List<String> _paymentTypes = [
    'MTN MoMo',
    'Airtel Money',
    'MoMo Code',
    'Bank Transfer',
    'Credit Card',
    'Tigo Cash',
    'Cash',
  ];

  final List<String> _categories = [
    'Grocery',
    'Electronics',
    'Clothing',
    'Restaurant',
    'Pharmacy',
    'Hardware',
    'Beauty & Health',
    'Automotive',
    'Sports & Recreation',
    'Books & Education',
    'Home & Garden',
    'Technology',
    'Services',
    'Entertainment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.store.name);
    _paymentCodeController =
        TextEditingController(text: widget.store.paymentCode);
    _selectedPaymentType =
        widget.store.paymentType.isNotEmpty ? widget.store.paymentType : null;
    _latitudeController =
        TextEditingController(text: widget.store.latitude.toString());
    _longitudeController =
        TextEditingController(text: widget.store.longitude.toString());
    _addressController =
        TextEditingController(text: widget.store.address ?? '');
    _descriptionController =
        TextEditingController(text: widget.store.description ?? '');
    _selectedCategories = widget.store.categories ?? [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _paymentCodeController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Map<String, String> _getPaymentCodeLabels() {
    switch (_selectedPaymentType) {
      case 'MTN MoMo':
        return {
          'label': 'MTN MoMo Number *',
          'hint': 'Enter MTN mobile number (e.g., 07(8/9)XXXXXXX)',
        };
      case 'Airtel Money':
        return {
          'label': 'Airtel Money Number *',
          'hint': 'Enter Airtel mobile number (e.g., 07(2/3)XXXXXXX)',
        };
      case 'MoMo Code':
        return {
          'label': 'MoMo Code *',
          'hint': 'Enter MoMo payment code or merchant number',
        };
      case 'Bank Transfer':
        return {
          'label': 'Bank Account Number *',
          'hint': 'Enter bank account number',
        };
      case 'Credit Card':
        return {
          'label': 'Payment Reference *',
          'hint': 'Enter payment reference or contact',
        };
      case 'Tigo Cash':
        return {
          'label': 'Tigo Cash Number *',
          'hint': 'Enter Tigo mobile number',
        };
      case 'Cash':
        return {
          'label': 'Contact Number *',
          'hint': 'Enter contact phone number',
        };
      default:
        return {
          'label': 'Payment Code *',
          'hint': 'Phone number or payment identifier',
        };
    }
  }

  Future<void> _saveStore() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Use selected categories directly
      List<String>? categories =
          _selectedCategories.isNotEmpty ? _selectedCategories : null;

      // Create updated store
      final updatedStore = widget.store.copyWith(
        name: _nameController.text.trim(),
        paymentCode: _paymentCodeController.text.trim(),
        paymentType: _selectedPaymentType ?? '',
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
                      color: Theme.of(context).colorScheme.primary,
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
            // Help text
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info,
                          color: Theme.of(context).colorScheme.primary, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Tips:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 12),

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

            // Payment Type Dropdown
            DropdownButtonFormField<String>(
              value: _selectedPaymentType,
              decoration: InputDecoration(
                labelText: 'Payment Type *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payment),
                hintText: 'Select payment type',
              ),
              items: _paymentTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPaymentType = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
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
                labelText: _getPaymentCodeLabels()['label'],
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.code),
                hintText: _getPaymentCodeLabels()['hint'],
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
                color: Theme.of(context).colorScheme.onSurface,
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

            // Categories Multi-Select
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.category,
                          color: Theme.of(context).colorScheme.onSurface),
                      SizedBox(width: 8),
                      Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((category) {
                      final isSelected = _selectedCategories.contains(category);
                      return FilterChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedCategories.add(category);
                            } else {
                              _selectedCategories.remove(category);
                            }
                          });
                        },
                        selectedColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      );
                    }).toList(),
                  ),
                  if (_selectedCategories.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      'Selected: ${_selectedCategories.join(', ')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
