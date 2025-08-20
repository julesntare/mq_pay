import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/store.dart';
import '../services/simple_store_service.dart';

class StoreAddScreen extends StatefulWidget {
  @override
  _StoreAddScreenState createState() => _StoreAddScreenState();
}

class _StoreAddScreenState extends State<StoreAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final SimpleStoreService _storeService = SimpleStoreService();

  final _nameController = TextEditingController();
  final _paymentCodeController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customCategoryController = TextEditingController();

  bool _isLoading = false;
  bool _isLocationLoading = false;
  Position? _currentPosition;

  // Dropdown values
  String? _selectedPaymentType;
  List<String> _selectedCategories = [];

  // Dropdown options
  final List<String> _paymentTypes = [
    'MTN MoMo',
    'Airtel Money',
    'Bank Transfer',
    'Credit Card',
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
  void dispose() {
    _nameController.dispose();
    _paymentCodeController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _customCategoryController.dispose();
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
      default:
        return {
          'label': 'Payment Code *',
          'hint': 'Phone number or payment identifier',
        };
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Location services are disabled. Please enable them in settings.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () async {
                await Geolocator.openLocationSettings();
              },
            ),
          ),
        );
        setState(() => _isLocationLoading = false);
        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location permission denied'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLocationLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Location permission permanently denied. Please enable in settings.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () async {
                await Geolocator.openAppSettings();
              },
            ),
          ),
        );
        setState(() => _isLocationLoading = false);
        return;
      }

      // Get current position
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      // Update the text fields
      _latitudeController.text = _currentPosition!.latitude.toStringAsFixed(6);
      _longitudeController.text =
          _currentPosition!.longitude.toStringAsFixed(6);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLocationLoading = false);
    }
  }

  void _clearBothLocationFields() {
    setState(() {
      _latitudeController.clear();
      _longitudeController.clear();
    });
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

      // Parse coordinates, allowing null values
      double? latitude;
      double? longitude;

      if (_latitudeController.text.trim().isNotEmpty) {
        latitude = double.tryParse(_latitudeController.text.trim());
        if (latitude == null || latitude < -90 || latitude > 90) {
          throw Exception('Invalid latitude value');
        }
      }

      if (_longitudeController.text.trim().isNotEmpty) {
        longitude = double.tryParse(_longitudeController.text.trim());
        if (longitude == null || longitude < -180 || longitude > 180) {
          throw Exception('Invalid longitude value');
        }
      }

      // Create new store
      final newStore = Store(
        id: DateTime.now()
            .millisecondsSinceEpoch
            .toString(), // Simple ID generation
        name: _nameController.text.trim(),
        paymentCode: _paymentCodeController.text.trim(),
        paymentType: _selectedPaymentType ?? '',
        latitude: latitude ?? 0.0, // Default to 0.0 if not provided
        longitude: longitude ?? 0.0, // Default to 0.0 if not provided
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        categories: categories,
        isFavorite: false,
      );

      final success = await _storeService.addStore(newStore);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Store added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(newStore); // Return new store
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add store'),
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
        title: Text('Add New Store'),
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
            // Help text
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.green[600], size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Tips:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Fields marked with * are required\n'
                    '• Latitude/Longitude are optional - click on fields to auto-fill using GPS\n'
                    '• Address can be used instead of coordinates\n'
                    '• Categories help users find your store in search\n'
                    '• For Kigali: Latitude ≈ -1.9441, Longitude ≈ 30.0619',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                if (_latitudeController.text.isNotEmpty ||
                    _longitudeController.text.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearBothLocationFields,
                    icon: Icon(Icons.clear_all, size: 18),
                    label: Text('Clear All'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      textStyle: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),

            // Latitude
            TextFormField(
              controller: _latitudeController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Latitude (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
                suffixIcon: _isLocationLoading
                    ? Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_latitudeController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _latitudeController.clear();
                                });
                              },
                              tooltip: 'Clear latitude',
                            ),
                          IconButton(
                            icon: Icon(Icons.my_location),
                            onPressed: _getCurrentLocation,
                            tooltip: 'Get current location',
                          ),
                        ],
                      ),
                hintText: 'Tap location icon to auto-fill (e.g., -1.9441)',
              ),
              onTap: () {
                // Auto-populate when field is tapped if no value exists
                if (_latitudeController.text.isEmpty) {
                  _getCurrentLocation();
                }
              },
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  final lat = double.tryParse(value.trim());
                  if (lat == null || lat < -90 || lat > 90) {
                    return 'Invalid latitude (-90 to 90)';
                  }
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // Longitude
            TextFormField(
              controller: _longitudeController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Longitude (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
                suffixIcon: _isLocationLoading
                    ? Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_longitudeController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _longitudeController.clear();
                                });
                              },
                              tooltip: 'Clear longitude',
                            ),
                          IconButton(
                            icon: Icon(Icons.my_location),
                            onPressed: _getCurrentLocation,
                            tooltip: 'Get current location',
                          ),
                        ],
                      ),
                hintText: 'Tap location icon to auto-fill (e.g., 30.0619)',
              ),
              onTap: () {
                // Auto-populate when field is tapped if no value exists
                if (_longitudeController.text.isEmpty) {
                  _getCurrentLocation();
                }
              },
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  final lng = double.tryParse(value.trim());
                  if (lng == null || lng < -180 || lng > 180) {
                    return 'Invalid longitude (-180 to 180)';
                  }
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
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.category, color: Colors.grey.shade600),
                      SizedBox(width: 8),
                      Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
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
                        selectedColor: Colors.blue.shade100,
                        checkmarkColor: Colors.blue.shade700,
                      );
                    }).toList(),
                  ),
                  if (_selectedCategories.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      'Selected: ${_selectedCategories.join(', ')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  // Custom category input when "Other" is selected
                  if (_selectedCategories.contains('Other')) ...[
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _customCategoryController,
                      decoration: InputDecoration(
                        labelText: 'Custom Category',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.add),
                        hintText: 'Enter custom category name',
                        suffixIcon: IconButton(
                          icon: Icon(Icons.add_circle),
                          onPressed: () {
                            final customCategory =
                                _customCategoryController.text.trim();
                            if (customCategory.isNotEmpty &&
                                !_selectedCategories.contains(customCategory)) {
                              setState(() {
                                _selectedCategories.add(customCategory);
                                _customCategoryController.clear();
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Custom category "$customCategory" added'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          tooltip: 'Add custom category',
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (value) {
                        final customCategory = value.trim();
                        if (customCategory.isNotEmpty &&
                            !_selectedCategories.contains(customCategory)) {
                          setState(() {
                            _selectedCategories.add(customCategory);
                            _customCategoryController.clear();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Custom category "$customCategory" added'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tip: Type a custom category name and press Enter or tap the + button to add it',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
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
