import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../helpers/app_theme.dart';

class StoreRegistrationPage extends StatefulWidget {
  @override
  _StoreRegistrationPageState createState() => _StoreRegistrationPageState();
}

class _StoreRegistrationPageState extends State<StoreRegistrationPage> {
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _paymentCodeController = TextEditingController();
  String _paymentType = "MTN MoMo";
  List<String> _selectedCategories = [];
  bool _isLoading = false;

  // Dropdown options
  final List<String> _paymentTypes = [
    'MTN MoMo',
    'Airtel Money',
    'Bank Transfer',
    'Tigo Cash',
    'Cash',
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

  Future<void> _registerStore() async {
    setState(() => _isLoading = true);

    try {
      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError("Location permission is required to register a store.");
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError(
            "Location permission is permanently denied. Enable it from settings.");
        setState(() => _isLoading = false);
        return;
      }

      // Fetch user location
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      await FirebaseFirestore.instance.collection('stores').add({
        'name': _storeNameController.text,
        'paymentCode': _paymentCodeController.text,
        'paymentType': _paymentType,
        'categories': _selectedCategories,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Store Registered Successfully!")));
      _storeNameController.clear();
      _paymentCodeController.clear();
      setState(() {
        _selectedCategories.clear();
      });
    } catch (e) {
      _showError("Error: $e");
    }

    setState(() => _isLoading = false);
  }

  IconData _getPaymentTypeIcon(String type) {
    switch (type) {
      case 'MTN MoMo':
        return Icons.phone_android_rounded;
      case 'Airtel Money':
        return Icons.phone_iphone_rounded;
      case 'Bank Transfer':
        return Icons.account_balance_rounded;
      case 'Credit Card':
        return Icons.credit_card_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                GradientCard(
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
                                  'Register Store',
                                  style:
                                      theme.textTheme.headlineMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Add your store to our network',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Form Section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Store Information',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Registration Tips
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Registration Tips',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Your store location will be automatically detected to help customers find you nearby. Make sure location permission is enabled.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Store Name Field
                        TextField(
                          controller: _storeNameController,
                          decoration: const InputDecoration(
                            labelText: "Store Name",
                            hintText: "Enter your store name",
                            prefixIcon: Icon(Icons.store_rounded),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Payment Code Field
                        TextField(
                          controller: _paymentCodeController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: "Payment Code",
                            hintText: "Enter phone number or MoMo code",
                            prefixIcon: Icon(Icons.payment_rounded),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Payment Type Dropdown
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: theme.colorScheme.outline),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _paymentType,
                              isExpanded: true,
                              icon: Icon(
                                Icons.expand_more_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              onChanged: (value) {
                                setState(() => _paymentType = value!);
                              },
                              items: _paymentTypes
                                  .map((type) => DropdownMenuItem(
                                        value: type,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: theme
                                                      .colorScheme.primary
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Icon(
                                                  _getPaymentTypeIcon(type),
                                                  color:
                                                      theme.colorScheme.primary,
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                type,
                                                style: theme.textTheme.bodyLarge
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Categories Multi-Select
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: theme.colorScheme.outline),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.category_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Categories (Optional)',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _categories.map((category) {
                                  final isSelected =
                                      _selectedCategories.contains(category);
                                  return FilterChip(
                                    label: Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
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
                                    selectedColor: theme.colorScheme.primary
                                        .withOpacity(0.2),
                                    checkmarkColor: theme.colorScheme.primary,
                                    backgroundColor: theme.colorScheme.surface,
                                    elevation: 1,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                  );
                                }).toList(),
                              ),
                              if (_selectedCategories.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Selected: ${_selectedCategories.join(', ')}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Register Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: _isLoading
                              ? Container(
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Registering...',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: _registerStore,
                                    icon: const Icon(Icons.add_business_rounded,
                                        color: Colors.white),
                                    label: Text(
                                      'Register Store',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Info Card - moved to top
              ],
            ),
          ),
        ),
      ),
    );
  }
}
