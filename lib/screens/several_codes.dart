import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../helpers/launcher.dart';
import '../helpers/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/ussd_record.dart';
import '../services/ussd_record_service.dart';

class Item {
  String title;
  String ussCode;
  String? description;
  String? provider;
  String? category;
  List<String>? keywords;

  Item({
    required this.title,
    required this.ussCode,
    this.description,
    this.provider,
    this.category,
    this.keywords,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'code': ussCode,
        'description': description,
        'provider': provider,
        'category': category,
        'keywords': keywords,
      };

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      title: json['title'],
      ussCode: json['ussCode'] ?? json['code'], // Support both keys
      description: json['description'],
      provider: json['provider'],
      category: json['category'],
      keywords:
          json['keywords'] != null ? List<String>.from(json['keywords']) : null,
    );
  }
}

class CodesPage extends StatefulWidget {
  @override
  _CodesPageState createState() => _CodesPageState();
}

class _CodesPageState extends State<CodesPage> {
  List<Item> items = [];
  List<Item> filteredItems = [];
  List<Item> paginatedItems = [];
  TextEditingController searchController = TextEditingController();

  // Form state and controllers
  bool _showAddForm = false;
  final _formKey = GlobalKey<FormState>();
  TextEditingController _titleController = TextEditingController();
  TextEditingController _ussCodeController = TextEditingController();

  // Loading state
  bool _isLoading = true;

  // Pagination
  int currentPage = 0;
  int itemsPerPage = 20;
  int get totalPages => (filteredItems.length / itemsPerPage).ceil();

  @override
  void initState() {
    super.initState();
    loadItems();
    searchController.addListener(() {
      setState(() {
        filterItems();
      });
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _titleController.dispose();
    _ussCodeController.dispose();
    super.dispose();
  }

  Future<void> saveItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> jsonList =
        items.map((item) => json.encode(item.toJson())).toList();
    await prefs.setStringList('items', jsonList);
  }

  Future<void> loadItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load USSDs from JSON file
      final String response =
          await rootBundle.loadString("assets/data/misc_ussds.json");
      dynamic data = json.decode(response);

      List<Item> loadedItems = [];
      for (var ussd in data) {
        try {
          Item item = Item.fromJson(ussd);
          loadedItems.add(item);
        } catch (e) {
          print('Error parsing item: $ussd, error: $e');
        }
      }

      setState(() {
        items = loadedItems;
        _isLoading = false;
        filterItems();
      });
    } catch (e) {
      print('Error loading USSDs: $e');
      // Initialize with empty list if loading fails
      setState(() {
        items = [];
        _isLoading = false;
        filterItems();
      });
    }
  }

  void filterItems() {
    String query = searchController.text.toLowerCase();
    setState(() {
      // First filter by search query
      var searchFiltered = items.where((item) {
        // Search in title
        if (item.title.toLowerCase().contains(query)) return true;

        // Search in USSD code
        if (item.ussCode.toLowerCase().contains(query)) return true;
        if (_getDisplayCode(item.ussCode).toLowerCase().contains(query))
          return true;

        // Search in description
        if (item.description != null &&
            item.description!.toLowerCase().contains(query)) return true;

        // Search in provider
        if (item.provider != null &&
            item.provider!.toLowerCase().contains(query)) return true;

        // Search in category
        if (item.category != null &&
            item.category!.toLowerCase().contains(query)) return true;

        // Search in keywords
        if (item.keywords != null) {
          for (String keyword in item.keywords!) {
            if (keyword.toLowerCase().contains(query)) return true;
          }
        }

        return false;
      }).toList();

      // Remove duplicates based on display code
      final seenDisplayCodes = <String>{};
      filteredItems = searchFiltered.where((item) {
        final displayCode = _getDisplayCode(item.ussCode);
        if (seenDisplayCodes.contains(displayCode)) {
          return false; // Skip duplicate
        }
        seenDisplayCodes.add(displayCode);
        return true;
      }).toList();

      // Reset to first page when filtering
      currentPage = 0;
      _updatePaginatedItems();
    });
  }

  void _updatePaginatedItems() {
    int startIndex = currentPage * itemsPerPage;
    int endIndex = (startIndex + itemsPerPage).clamp(0, filteredItems.length);

    setState(() {
      paginatedItems = filteredItems.sublist(startIndex, endIndex);
    });
  }

  void _goToPage(int page) {
    if (page >= 0 && page < totalPages) {
      setState(() {
        currentPage = page;
        _updatePaginatedItems();
      });
    }
  }

  void toggleAddForm() {
    setState(() {
      _showAddForm = !_showAddForm;
      if (!_showAddForm) {
        // Clear form when hiding
        _titleController.clear();
        _ussCodeController.clear();
      }
    });
  }

  void submitNewCode() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        items.add(
          Item(title: _titleController.text, ussCode: _ussCodeController.text),
        );
        saveItems();
        filterItems();

        // Clear form and hide it
        _titleController.clear();
        _ussCodeController.clear();
        _showAddForm = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Code added successfully!'),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void editItem(int paginatedIndex) {
    Item itemToEdit = paginatedItems[paginatedIndex];

    TextEditingController titleController = TextEditingController(
      text: itemToEdit.title,
    );
    TextEditingController ussCodeController = TextEditingController(
      text: itemToEdit.ussCode,
    );
    final theme = Theme.of(context);

    // Find the actual index in the main items list
    int actualIndex = items.indexWhere(
      (item) =>
          item.title == itemToEdit.title && item.ussCode == itemToEdit.ussCode,
    );

    showDialog(
      context: context,
      builder: (context) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Edit Code",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: "Title",
                    hintText: "Enter a descriptive title",
                    prefixIcon: Icon(Icons.title_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ussCodeController,
                  keyboardType: TextInputType.text,
                  maxLines: 2,
                  minLines: 1,
                  decoration: InputDecoration(
                    labelText: "USSD Code / Pay Code",
                    hintText:
                        "e.g., *182#, *182*1*1*0780123456*0780123456#, or 0780123456",
                    helperText:
                        "Enter complete USSD code, phone number, or any pay code",
                    prefixIcon: const Icon(Icons.code_rounded),
                    border: const OutlineInputBorder(),
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (titleController.text.isNotEmpty &&
                              ussCodeController.text.isNotEmpty &&
                              actualIndex != -1) {
                            setState(() {
                              items[actualIndex] = Item(
                                title: titleController.text,
                                ussCode: ussCodeController.text,
                              );
                              saveItems();
                              filterItems();
                            });
                            Navigator.pop(context);

                            // Show success message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('Code updated successfully!'),
                                  ],
                                ),
                                backgroundColor: AppTheme.successColor,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          }
                        },
                        child: const Text("Save"),
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

  void deleteItem(int paginatedIndex) {
    Item itemToDelete = paginatedItems[paginatedIndex];

    // Find the actual index in the main items list
    int actualIndex = items.indexWhere(
      (item) =>
          item.title == itemToDelete.title &&
          item.ussCode == itemToDelete.ussCode,
    );

    if (actualIndex == -1) return; // Item not found

    Item deletedItem = items[actualIndex];
    setState(() {
      items.removeAt(actualIndex);
      saveItems();
      filterItems();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Code deleted',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: "Undo",
          textColor: Colors.white,
          backgroundColor: Colors.white.withOpacity(0.2),
          onPressed: () {
            setState(() {
              items.insert(actualIndex, deletedItem);
              saveItems();
              filterItems();
            });
          },
        ),
      ),
    );
  }

  String _getDisplayCode(String ussCode) {
    // Clean up the input
    String cleanCode = ussCode.trim();

    // Remove placeholders like [BillID], [account], [amount], etc. and everything after them
    final placeholderRegex = RegExp(r'\*\[[^\]]+\].*');
    if (placeholderRegex.hasMatch(cleanCode)) {
      // Remove from the first placeholder onwards
      cleanCode = cleanCode.replaceAll(placeholderRegex, '');
      // Ensure it ends with #
      if (!cleanCode.endsWith('#')) {
        cleanCode = '$cleanCode#';
      }
      return cleanCode;
    }

    // If it's already a complete USSD code, return as is
    if (cleanCode.contains('*') && cleanCode.contains('#')) {
      return cleanCode;
    }

    // If it looks like a phone number, format for mobile money
    if (RegExp(r'^(?:\+2507|2507|07|7)[0-9]{8}$').hasMatch(cleanCode)) {
      return "*182*1*1*$cleanCode*$cleanCode#";
    }

    // For other codes that look like simple USSD without #, add it
    if (cleanCode.startsWith('*') && !cleanCode.contains('#')) {
      return "$cleanCode#";
    }

    // For other codes, format as pay bill
    return "*182*8*1*$cleanCode*$cleanCode#";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
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
                          Icons.qr_code_rounded,
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
                              'Misc. USSDs',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage your saved USSD codes',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Search Bar
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: searchController,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Search codes...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    searchController.clear();
                                    filterItems();
                                  },
                                  icon: const Icon(Icons.clear_rounded),
                                  tooltip: 'Clear search',
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
                ],
              ),
            ),

            // Content
            Expanded(
              child: _showAddForm
                  ? _buildAddForm(context, theme)
                  : _isLoading
                      ? _buildLoadingState(context, theme)
                      : (items.isEmpty
                          ? _buildEmptyState(context, theme)
                          : (filteredItems.isEmpty
                              ? _buildNoSearchResults(context, theme)
                              : Stack(
                                  children: [
                                    _buildCodesList(context, theme),
                                    if (totalPages > 1) ...[
                                      _buildLeftArrow(context, theme),
                                      _buildRightArrow(context, theme),
                                    ],
                                  ],
                                ))),
            ),
          ],
        ),
      ),
      floatingActionButton: (items.isNotEmpty || _showAddForm)
          ? Container(
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
                onPressed: toggleAddForm,
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Icon(
                  _showAddForm ? Icons.close_rounded : Icons.add_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildLoadingState(BuildContext context, ThemeData theme) {
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
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading USSDs...',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please wait while we load the USSD codes',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
                Icons.qr_code_2_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No USSDs Available',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load USSD codes at this time',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: loadItems,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResults(BuildContext context, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60), // Add some top spacing
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 48,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Results Found',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No codes match your search criteria.\nTry different keywords or clear the search.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              searchController.clear();
              filterItems();
            },
            icon: const Icon(Icons.clear_rounded),
            label: const Text('Clear Search'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(height: 60), // Add some bottom spacing
        ],
      ),
    );
  }

  Widget _buildCodesList(BuildContext context, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: paginatedItems.length,
      itemBuilder: (context, index) {
        return _buildCodeCard(context, theme, index);
      },
    );
  }

  Widget _buildCodeCard(BuildContext context, ThemeData theme, int index) {
    final item = paginatedItems[index];

    return Dismissible(
      key: Key('${item.title}-${item.ussCode}'),
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => deleteItem(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.qr_code_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getDisplayCode(item.ussCode),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (item.provider != null || item.category != null) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: [
                              if (item.provider != null) ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.business_rounded,
                                      size: 12,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.5),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        item.provider!,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.6),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (item.provider != null &&
                                  item.category != null) ...[
                                Text(
                                  ' • ',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                                  ),
                                ),
                              ],
                              if (item.category != null) ...[
                                Text(
                                  item.category!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        if (item.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (item.ussCode != _getDisplayCode(item.ussCode)) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Original: ${item.ussCode}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      context: context,
                      theme: theme,
                      icon: Icons.call_rounded,
                      label: 'Call',
                      color: AppTheme.successColor,
                      onPressed: () {
                        _showAmountDialog(item);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildIconButton(
                    context: context,
                    theme: theme,
                    icon: Icons.edit_rounded,
                    color: AppTheme.primaryColor,
                    onPressed: () => editItem(index),
                  ),
                  const SizedBox(width: 8),
                  _buildIconButton(
                    context: context,
                    theme: theme,
                    icon: Icons.delete_rounded,
                    color: AppTheme.errorColor,
                    onPressed: () => deleteItem(index),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildIconButton({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color),
        padding: const EdgeInsets.all(12),
      ),
    );
  }

  void _showAmountDialog(Item item) {
    // Check if USSD code has placeholders like [BillID], [account], etc.
    final placeholderRegex = RegExp(r'\[([^\]]+)\]');
    final placeholders = placeholderRegex.allMatches(item.ussCode).toList();

    if (placeholders.isNotEmpty) {
      // Show placeholder input dialog instead
      _showPlaceholderInputDialog(item, placeholders);
    } else {
      // Show regular amount dialog
      _showRegularAmountDialog(item);
    }
  }

  void _showPlaceholderInputDialog(Item item, List<RegExpMatch> placeholders) {
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();

    // Create controllers for each placeholder
    final controllers = <String, TextEditingController>{};
    for (var match in placeholders) {
      final placeholderName = match.group(1)!;
      controllers[placeholderName] = TextEditingController();
    }

    showDialog(
      context: context,
      builder: (context) {
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
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.qr_code_rounded,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                item.ussCode,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Input fields for each placeholder
                    ...controllers.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          controller: entry.value,
                          decoration: InputDecoration(
                            labelText: entry.key,
                            hintText: 'Enter ${entry.key}',
                            prefixIcon: Icon(Icons.edit_rounded),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter ${entry.key}';
                            }
                            return null;
                          },
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              for (var controller in controllers.values) {
                                controller.dispose();
                              }
                              Navigator.pop(context);
                            },
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                Navigator.pop(context);

                                // Build USSD code with placeholder values
                                String finalCode = item.ussCode;
                                for (var entry in controllers.entries) {
                                  finalCode = finalCode.replaceAll(
                                    '[${entry.key}]',
                                    entry.value.text.trim(),
                                  );
                                }

                                // Ensure it ends with #
                                if (!finalCode.endsWith('#')) {
                                  finalCode = '$finalCode#';
                                }

                                // Dispose controllers
                                for (var controller in controllers.values) {
                                  controller.dispose();
                                }

                                // Launch USSD
                                launchUSSD(finalCode, context);

                                // Show success message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.call_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child:
                                              Text('USSD dialed: $finalCode'),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: AppTheme.successColor,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.call_rounded),
                            label: const Text("Call"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRegularAmountDialog(Item item) {
    final theme = Theme.of(context);
    final TextEditingController amountController = TextEditingController();
    final _amountFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
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
            child: Form(
              key: _amountFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.qr_code_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _getDisplayCode(item.ussCode),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.7,
                                ),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Amount (Optional)",
                      hintText: "Enter amount in RWF",
                      prefixIcon: Icon(Icons.attach_money_rounded),
                      border: OutlineInputBorder(),
                      helperText: "Leave empty if no amount is needed",
                    ),
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final amount = double.tryParse(value.trim());
                        if (amount == null || amount < 0) {
                          return 'Please enter a valid amount';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_amountFormKey.currentState!.validate()) {
                              Navigator.pop(context);
                              final amountText = amountController.text.trim();
                              final amount = amountText.isEmpty
                                  ? 0.0
                                  : double.parse(amountText);
                              _callUSSDWithAmount(item, amount);
                            }
                          },
                          icon: const Icon(Icons.call_rounded),
                          label: const Text("Call"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _callUSSDWithAmount(Item item, double amount) async {
    try {
      String ussdCode = _getDisplayCode(item.ussCode);

      // Append amount to USSD code if provided
      if (amount > 0) {
        // If the code ends with #, insert amount before it
        if (ussdCode.endsWith('#')) {
          ussdCode = ussdCode.substring(0, ussdCode.length - 1) +
              '*${amount.toStringAsFixed(0)}#';
        } else {
          // If no # at the end, just append the amount
          ussdCode = '$ussdCode*${amount.toStringAsFixed(0)}';
        }
      }

      // Launch the USSD
      launchUSSD(ussdCode, context);

      // Save to history if amount was provided
      if (amount > 0) {
        final record = UssdRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          ussdCode: ussdCode,
          recipient: item.title, // Use title as recipient for misc codes
          recipientType: 'misc', // New type for miscellaneous codes
          amount: amount,
          timestamp: DateTime.now(),
          maskedRecipient: item.title,
          reason: null,
        );

        await UssdRecordService.saveUssdRecord(record);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'USSD called and saved to history (RWF ${amount.toStringAsFixed(0)})',
                  ),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } else {
        // Show message for call without saving
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.call_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('USSD code dialed'),
                ],
              ),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Widget _buildAddForm(BuildContext context, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Form Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Add New Code",
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: toggleAddForm,
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Cancel',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Title Field
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: "Title",
                      hintText: "Enter a descriptive title",
                      prefixIcon: Icon(Icons.title_rounded),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // USSD Code Field
                  TextFormField(
                    controller: _ussCodeController,
                    keyboardType: TextInputType.text,
                    maxLines: 2,
                    minLines: 1,
                    decoration: InputDecoration(
                      labelText: "USSD Code / Pay Code",
                      hintText:
                          "e.g., *182#, *182*1*1*0780123456*0780123456#, or 0780123456",
                      helperText:
                          "Enter complete USSD code, phone number, or any pay code",
                      prefixIcon: const Icon(Icons.code_rounded),
                      border: const OutlineInputBorder(),
                      helperMaxLines: 2,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a USSD code or pay code';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: toggleAddForm,
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: submitNewCode,
                          child: const Text("Add Code"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Help Text
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Supported Formats',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Complete USSD codes: *182#, *144#, *131#\n'
                    '• Mobile money codes: *182*1*1*0780123456*0780123456#\n'
                    '• Phone numbers: 0780123456, +250780123456\n'
                    '• Pay bill codes: 12345, ABCD123\n'
                    '• Any custom code you want to save',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      height: 1.4,
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

  Widget _buildLeftArrow(BuildContext context, ThemeData theme) {
    return Positioned(
      left: 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: currentPage > 0 ? 1.0 : 0.3,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(50),
              child: InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap:
                    currentPage > 0 ? () => _goToPage(currentPage - 1) : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: currentPage > 0
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.3),
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightArrow(BuildContext context, ThemeData theme) {
    return Positioned(
      right: 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: currentPage < totalPages - 1 ? 1.0 : 0.3,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(50),
              child: InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap: currentPage < totalPages - 1
                    ? () => _goToPage(currentPage + 1)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: currentPage < totalPages - 1
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.3),
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
