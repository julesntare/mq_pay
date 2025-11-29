import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ussd_record.dart';
import '../services/ussd_record_service.dart';
import '../helpers/app_theme.dart';
import '../helpers/launcher.dart';
import 'edit_ussd_record_dialog.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../widgets/scroll_indicator.dart';

class UssdRecordsScreen extends StatefulWidget {
  const UssdRecordsScreen({super.key});

  @override
  State<UssdRecordsScreen> createState() => _UssdRecordsScreenState();
}

class _UssdRecordsScreenState extends State<UssdRecordsScreen> {
  List<UssdRecord> records = [];
  bool isLoading = true;
  double totalAmount = 0.0;
  int totalRecords = 0;
  Map<String, double> amountByType = {};

  // Monthly navigation
  List<DateTime> monthsWithData = [];
  int currentMonthIndex = 0;
  double currentMonthTotal = 0.0;
  Map<String, double> currentMonthAmountByType = {};

  // Tab selection for breakdown view
  int selectedTab = 0; // 0: Mobile, 1: MoCode, 2: Misc

  // Filter state
  String? activeFilter; // null = no filter, 'phone', 'momo', 'misc'
  // Advanced filter controls
  String? recipientTypeFilter; // 'phone' | 'momo' | 'misc' | null
  DateTime? filterStartDate;
  DateTime? filterEndDate;
  double filteredTotal = 0.0;

  // Search state
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  // Contact caching
  List<Contact> deviceContacts = [];
  bool contactsLoaded = false;
  Map<String, String> contactNameCache = {}; // phone -> name mapping
  // Reason filter state
  List<String> availableReasons = [];
  String? selectedReason;
  double selectedReasonTotalAllTime = 0.0;
  double selectedReasonTotalCurrentMonth = 0.0;

  // Collapsible groups state - tracks which date groups are expanded
  Set<String> expandedGroups = {}; // Set of date keys 'yyyy-MM-dd'

  // PageController for swipeable tabs
  late PageController _pageController;

  // ScrollController for scroll indicators
  final ScrollController _scrollController = ScrollController();

  // Fee display toggle
  bool includeFees = true; // true = show total with fees, false = show amount only
  double totalFees = 0.0;
  double currentMonthTotalFees = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: selectedTab);
    _loadRecords();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      if (await FlutterContacts.requestPermission()) {
        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: false,
        );
        setState(() {
          deviceContacts = contacts;
          contactsLoaded = true;
        });
        // Build contact name cache after contacts are loaded
        _buildContactNameCache();
      }
    } catch (e) {
      // Silently fail if contacts can't be loaded
      setState(() {
        contactsLoaded = true;
      });
    }
  }

  void _buildContactNameCache() {
    if (records.isEmpty || deviceContacts.isEmpty) return;

    // Get all unique phone numbers from records
    final uniquePhoneNumbers = records
        .where((record) => record.recipientType == 'phone')
        .map((record) => record.recipient)
        .toSet();

    // Create a reverse lookup map: cleaned phone -> contact name
    final Map<String, String> cleanedPhoneToName = {};

    // Build lookup map from contacts
    for (var contact in deviceContacts) {
      if (contact.phones.isNotEmpty) {
        for (var phone in contact.phones) {
          final cleanContactPhone =
              phone.number.replaceAll(RegExp(r'[^0-9]'), '');
          if (cleanContactPhone.isNotEmpty) {
            // Store with different length variants for better matching
            cleanedPhoneToName[cleanContactPhone] = contact.displayName;
            // Also store last 9 digits (common in Rwanda)
            if (cleanContactPhone.length >= 9) {
              final last9 =
                  cleanContactPhone.substring(cleanContactPhone.length - 9);
              cleanedPhoneToName[last9] = contact.displayName;
            }
            // Also store last 10 digits
            if (cleanContactPhone.length >= 10) {
              final last10 =
                  cleanContactPhone.substring(cleanContactPhone.length - 10);
              cleanedPhoneToName[last10] = contact.displayName;
            }
          }
        }
      }
    }

    // Match record phone numbers to contacts
    for (var phoneNumber in uniquePhoneNumbers) {
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

      // Try exact match first
      if (cleanedPhoneToName.containsKey(cleanPhone)) {
        contactNameCache[phoneNumber] = cleanedPhoneToName[cleanPhone]!;
        continue;
      }

      // Try last 9 digits
      if (cleanPhone.length >= 9) {
        final last9 = cleanPhone.substring(cleanPhone.length - 9);
        if (cleanedPhoneToName.containsKey(last9)) {
          contactNameCache[phoneNumber] = cleanedPhoneToName[last9]!;
          continue;
        }
      }

      // Try last 10 digits
      if (cleanPhone.length >= 10) {
        final last10 = cleanPhone.substring(cleanPhone.length - 10);
        if (cleanedPhoneToName.containsKey(last10)) {
          contactNameCache[phoneNumber] = cleanedPhoneToName[last10]!;
          continue;
        }
      }

      // No match found
      contactNameCache[phoneNumber] = '';
    }

    // Trigger rebuild to show contact names
    setState(() {});
  }

  String? _getContactNameForPhone(String phoneNumber) {
    // Return from cache (already built in _buildContactNameCache)
    if (contactNameCache.containsKey(phoneNumber)) {
      final name = contactNameCache[phoneNumber];
      return name!.isEmpty ? null : name;
    }
    return null;
  }

  Future<void> _loadRecords() async {
    setState(() => isLoading = true);

    try {
      final loadedRecords = await UssdRecordService.getUssdRecords();
      final allRecords = loadedRecords;
      final count = allRecords.length;
      final total = allRecords.fold<double>(0.0, (s, r) => s + r.amount);
      final fees = allRecords.fold<double>(0.0, (s, r) => s + r.calculateFee());

      final typeAmounts = <String, double>{
        'phone': 0.0,
        'momo': 0.0,
        'misc': 0.0
      };
      for (final r in allRecords) {
        if (r.recipientType == 'phone') {
          typeAmounts['phone'] = (typeAmounts['phone'] ?? 0) + r.amount;
        } else if (r.recipientType == 'momo') {
          typeAmounts['momo'] = (typeAmounts['momo'] ?? 0) + r.amount;
        } else {
          typeAmounts['misc'] = (typeAmounts['misc'] ?? 0) + r.amount;
        }
      }

      setState(() {
        records = allRecords.reversed.toList(); // Show newest first
        totalAmount = total;
        totalFees = fees;
        totalRecords = count;
        amountByType = typeAmounts;
        isLoading = false;
      });

      // Load available reasons for filters
      _loadAvailableReasons();

      // Calculate months with data AFTER records are set
      _calculateMonthsWithData(loadedRecords);

      // Rebuild contact cache if contacts are already loaded
      if (contactsLoaded && deviceContacts.isNotEmpty) {
        _buildContactNameCache();
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading records: $e')),
        );
      }
    }
  }

  Future<void> _loadAvailableReasons() async {
    final reasons = await UssdRecordService.getUniqueReasons();
    setState(() {
      availableReasons = reasons;
    });
  }

  void _calculateMonthsWithData(List<UssdRecord> allRecords) {
    Map<String, double> monthlyTotals = {};

    for (var record in allRecords) {
      final monthKey = DateFormat('yyyy-MM').format(record.timestamp);
      monthlyTotals[monthKey] =
          (monthlyTotals[monthKey] ?? 0.0) + record.amount;
    }

    // Get months with totals > 0, sorted newest first
    List<DateTime> months =
        monthlyTotals.entries.where((entry) => entry.value > 0).map((entry) {
      final parts = entry.key.split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]));
    }).toList()
          ..sort((a, b) => b.compareTo(a)); // Newest first

    setState(() {
      monthsWithData = months;
      currentMonthIndex = 0;
    });

    if (monthsWithData.isNotEmpty) {
      _updateCurrentMonthTotal();
    }
  }

  void _updateCurrentMonthTotal() {
    if (monthsWithData.isEmpty) {
      setState(() {
        currentMonthTotal = 0.0;
        currentMonthTotalFees = 0.0;
        currentMonthAmountByType = {};
      });
      return;
    }

    final currentMonth = monthsWithData[currentMonthIndex];
    final monthKey = DateFormat('yyyy-MM').format(currentMonth);

    final monthRecords = records
        .where((record) =>
            DateFormat('yyyy-MM').format(record.timestamp) == monthKey)
        .toList();

    final total = monthRecords.fold(0.0, (sum, record) => sum + record.amount);
    final fees = monthRecords.fold(0.0, (sum, record) => sum + record.calculateFee());

    // Calculate monthly amounts by type
    final amountsByType = {
      'phone': monthRecords
          .where((r) => r.recipientType == 'phone')
          .fold(0.0, (sum, r) => sum + r.amount),
      'momo': monthRecords
          .where((r) => r.recipientType == 'momo')
          .fold(0.0, (sum, r) => sum + r.amount),
      'misc': monthRecords
          .where((r) => r.recipientType == 'misc')
          .fold(0.0, (sum, r) => sum + r.amount),
    };

    setState(() {
      currentMonthTotal = total;
      currentMonthTotalFees = fees;
      currentMonthAmountByType = amountsByType;
    });
  }

  void _navigateMonth(int direction) {
    if (monthsWithData.isEmpty) return;

    setState(() {
      currentMonthIndex =
          (currentMonthIndex + direction).clamp(0, monthsWithData.length - 1);
      _updateCurrentMonthTotal();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _clearAllRecords() async {
    final confirmed = await _showConfirmationDialog(
      'Clear All Records',
      'Are you sure you want to clear all USSD records? This action cannot be undone.',
      confirmText: 'Clear All',
    );

    if (confirmed) {
      await UssdRecordService.clearUssdRecords();
      _loadRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All records cleared successfully')),
        );
      }
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message,
      {String confirmText = 'Confirm'}) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(confirmText),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('USSD Records'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          if (records.isNotEmpty)
            IconButton(
              onPressed: _clearAllRecords,
              icon: const Icon(Icons.clear_all_rounded),
              tooltip: 'Clear all records',
            ),
          IconButton(
            onPressed: _loadRecords,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : records.isEmpty
              ? _buildEmptyState(theme)
              : ScrollIndicatorWrapper(
                  controller: _scrollController,
                  showTopIndicator: true,
                  showBottomIndicator: true,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // Summary cards
                      SliverToBoxAdapter(
                        child: _buildSummaryCards(theme),
                      ),
                      // Search bar
                      SliverToBoxAdapter(
                        child: _buildSearchBar(theme),
                      ),
                      // Active filter title
                      if (activeFilter != null)
                        SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.filter_list_rounded,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Filtered: ${_getFilterDisplayName(activeFilter!)}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Filtered total badge
                      if (recipientTypeFilter != null ||
                          selectedReason != null ||
                          filterStartDate != null ||
                          filterEndDate != null ||
                          searchQuery.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 6),
                            alignment: Alignment.centerLeft,
                            child: Chip(
                              label: Text(_formatCurrency(filteredTotal)),
                              backgroundColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                      // Reason filters
                      SliverToBoxAdapter(
                        child: _buildReasonFilters(theme),
                      ),
                      // Records list
                      _buildRecordsListSliver(theme),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: TextField(
        controller: searchController,
        onChanged: (value) {
          setState(() {
            searchQuery = value.toLowerCase();
          });
          _computeFilteredTotal();
        },
        decoration: InputDecoration(
          hintText: 'Search by name, number, amount...',
          prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Filter icon
              IconButton(
                icon: Icon(Icons.filter_list,
                    color: filterStartDate != null ||
                            recipientTypeFilter != null ||
                            selectedReason != null
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                onPressed: () async {
                  await _showFilterSheet();
                },
                tooltip: 'Filters',
              ),
              // Clear search
              if (searchQuery.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.clear,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  onPressed: () {
                    setState(() {
                      searchController.clear();
                      searchQuery = '';
                    });
                  },
                ),
            ],
          ),
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Future<void> _showFilterSheet() async {
    final theme = Theme.of(context);

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String? localRecipientType = recipientTypeFilter;
        DateTime? localStart = filterStartDate;
        DateTime? localEnd = filterEndDate;
        // Default to single-date mode as requested
        bool singleDateMode = true;
        String? localReason = selectedReason;

        return StatefulBuilder(builder: (context, setLocalState) {
          void applyLocal() {
            setState(() {
              recipientTypeFilter = localRecipientType;
              selectedReason = localReason;

              if (singleDateMode) {
                if (localStart != null) {
                  // single date -> set start to 00:00 and end to end of day
                  filterStartDate = DateTime(localStart!.year,
                      localStart!.month, localStart!.day, 0, 0, 0);
                  filterEndDate = DateTime(localStart!.year, localStart!.month,
                      localStart!.day, 23, 59, 59, 999);
                } else {
                  filterStartDate = null;
                  filterEndDate = null;
                }
              } else {
                if (localStart != null) {
                  filterStartDate = DateTime(localStart!.year,
                      localStart!.month, localStart!.day, 0, 0, 0);
                } else {
                  filterStartDate = null;
                }
                if (localEnd != null) {
                  filterEndDate = DateTime(localEnd!.year, localEnd!.month,
                      localEnd!.day, 23, 59, 59, 999);
                } else {
                  filterEndDate = null;
                }
              }
            });
            _computeFilteredTotal();
            Navigator.of(context).pop();
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Filters', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Flexible(
                      child: DropdownButtonFormField<String?>(
                        isExpanded: true,
                        value: localRecipientType,
                        decoration: const InputDecoration(
                            labelText: 'Type', isDense: true),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('All')),
                          const DropdownMenuItem(
                              value: 'phone', child: Text('Phone')),
                          const DropdownMenuItem(
                              value: 'momo', child: Text('MoCode')),
                          const DropdownMenuItem(
                              value: 'misc', child: Text('Misc')),
                        ],
                        onChanged: (v) =>
                            setLocalState(() => localRecipientType = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: DropdownButtonFormField<String?>(
                        isExpanded: true,
                        value: localReason,
                        decoration: const InputDecoration(
                            labelText: 'Reason', isDense: true),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Any')),
                          ...availableReasons.map((r) =>
                              DropdownMenuItem(value: r, child: Text(r))),
                        ],
                        onChanged: (v) => setLocalState(() => localReason = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Single date or range toggle
                Row(
                  children: [
                    ToggleButtons(
                      isSelected: [singleDateMode, !singleDateMode],
                      onPressed: (i) =>
                          setLocalState(() => singleDateMode = i == 0),
                      children: const [
                        Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Single')),
                        Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Range'))
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Replace date buttons with inline date fields (tappable InputDecorator)
                if (singleDateMode)
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: localStart ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null)
                              setLocalState(() => localStart = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Date',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            child: Text(localStart == null
                                ? ''
                                : DateFormat('yyyy-MM-dd').format(localStart!)),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: localStart ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null)
                              setLocalState(() => localStart = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Start date',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            child: Text(localStart == null
                                ? ''
                                : DateFormat('yyyy-MM-dd').format(localStart!)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: localEnd ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null)
                              setLocalState(() => localEnd = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'End date',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            child: Text(localEnd == null
                                ? ''
                                : DateFormat('yyyy-MM-dd').format(localEnd!)),
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),
                // Clear and Apply actions
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setLocalState(() {
                          localRecipientType = null;
                          localStart = null;
                          localEnd = null;
                          localReason = null;
                          singleDateMode = false;
                        });
                      },
                      child: const Text('Clear'),
                    ),
                    const SizedBox(width: 12),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: applyLocal,
                      child: const Text('Apply'),
                    ),
                  ],
                ),
                // end of sheet content
              ],
            ),
          );
        });
      },
    );
  }

  void _computeFilteredTotal() {
    double total = 0.0;

    for (final r in records) {
      if (recipientTypeFilter != null && r.recipientType != recipientTypeFilter)
        continue;
      if (selectedReason != null &&
          (r.reason == null || r.reason!.trim() != selectedReason)) continue;
      if (filterStartDate != null && r.timestamp.isBefore(filterStartDate!))
        continue;
      if (filterEndDate != null && r.timestamp.isAfter(filterEndDate!))
        continue;
      total += r.amount;
    }

    setState(() {
      filteredTotal = total;
    });
  }

  // Build reason filter chips beneath search bar
  Widget _buildReasonFilters(ThemeData theme) {
    if (availableReasons.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const SizedBox(width: 4),
            ...availableReasons.map((r) {
              final isSelected = selectedReason == r;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(r),
                  selected: isSelected,
                  onSelected: (sel) async {
                    setState(() {
                      selectedReason = sel ? r : null;
                    });

                    if (selectedReason != null) {
                      // compute totals for selected reason
                      selectedReasonTotalAllTime =
                          await UssdRecordService.getTotalByReason(r);
                      // current month totals
                      if (monthsWithData.isNotEmpty) {
                        final cur = monthsWithData[currentMonthIndex];
                        selectedReasonTotalCurrentMonth =
                            await UssdRecordService.getTotalByReasonForMonth(
                                r, cur.year, cur.month);
                      } else {
                        selectedReasonTotalCurrentMonth = 0.0;
                      }
                    } else {
                      selectedReasonTotalAllTime = 0.0;
                      selectedReasonTotalCurrentMonth = 0.0;
                    }
                    setState(() {});
                  },
                ),
              );
            }).toList(),
            const SizedBox(width: 8),
            if (selectedReason != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    selectedReason = null;
                    selectedReasonTotalAllTime = 0.0;
                    selectedReasonTotalCurrentMonth = 0.0;
                  });
                },
                child: const Text('Clear reason filter'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'No USSD Records',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Start making payments to see your transaction history here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getFilterDisplayName(String filterKey) {
    switch (filterKey) {
      case 'phone':
        return 'Phone Number';
      case 'momo':
        return 'Momo Code';
      case 'misc':
        return 'Side Payments';
      default:
        return 'All';
    }
  }

  Widget _buildSummaryCards(ThemeData theme) {
    final tabData = [
      {
        'title': 'Phone Number',
        'icon': Icons.phone_rounded,
        'color': AppTheme.successColor,
        'key': 'phone'
      },
      {
        'title': 'Momo Code',
        'icon': Icons.qr_code_rounded,
        'color': AppTheme.warningColor,
        'key': 'momo'
      },
      {
        'title': 'Side Payments',
        'icon': Icons.code_rounded,
        'color': const Color(0xFF06B6D4), // Cyan for better contrast
        'key': 'misc'
      },
    ];

    final currentTab = tabData[selectedTab];
    final totalTabAmount = amountByType[currentTab['key']] ?? 0.0;
    final monthlyTabAmount = currentMonthAmountByType[currentTab['key']] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Compact Summary Card with Tabs
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Total Section (Compact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Overall Total',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatCurrency(includeFees ? totalAmount + totalFees : totalAmount),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Fee Toggle Button
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                includeFees = !includeFees;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    includeFees ? Icons.check_circle : Icons.circle_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    includeFees ? 'Fees Included in All Totals' : 'Fees Excluded from All Totals',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.swap_horiz_rounded,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (totalFees > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 14,
                                    color: Colors.white60,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Total Fees Paid',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _formatCurrency(totalFees),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (monthsWithData.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: currentMonthIndex <
                                          monthsWithData.length - 1
                                      ? () => _navigateMonth(1)
                                      : null,
                                  icon: Icon(
                                    Icons.arrow_back_ios_rounded,
                                    color: currentMonthIndex <
                                            monthsWithData.length - 1
                                        ? Colors.white
                                        : Colors.white38,
                                    size: 14,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('MMM yyyy').format(
                                      monthsWithData[currentMonthIndex]),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: currentMonthIndex > 0
                                      ? () => _navigateMonth(-1)
                                      : null,
                                  icon: Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: currentMonthIndex > 0
                                        ? Colors.white
                                        : Colors.white38,
                                    size: 14,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatCurrency(includeFees ? currentMonthTotal + currentMonthTotalFees : currentMonthTotal),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (currentMonthTotalFees > 0)
                                  Text(
                                    '+ ${_formatCurrency(currentMonthTotalFees)} fees',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white60,
                                      fontSize: 9,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const Divider(color: Colors.white24, height: 1),

                // Swipeable Tab Content with Navigation Arrows
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      // Left Arrow
                      IconButton(
                        icon: Icon(
                          Icons.chevron_left_rounded,
                          color: selectedTab > 0
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.3),
                          size: 32,
                        ),
                        onPressed: selectedTab > 0
                            ? () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                      ),
                      // PageView for swipeable tabs
                      Expanded(
                        child: SizedBox(
                          height: 80,
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() {
                                selectedTab = index;
                              });
                            },
                            itemCount: tabData.length,
                            itemBuilder: (context, index) {
                              final tab = tabData[index];
                              final tabKey = tab['key'] as String;
                              final isFiltered = activeFilter == tabKey;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    // Toggle filter on/off
                                    if (activeFilter == tabKey) {
                                      activeFilter = null; // Turn off filter
                                    } else {
                                      activeFilter = tabKey; // Turn on filter
                                    }
                                  });
                                  _computeFilteredTotal();
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 2, horizontal: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            tab['icon'] as IconData,
                                            color: tab['color'] as Color,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Flexible(
                                            child: Text(
                                              tab['title'] as String,
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                color: tab['color'] as Color,
                                                fontWeight: isFiltered
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                              ),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (isFiltered)
                                            Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.3),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.close_rounded,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            )
                                          else
                                            Icon(
                                              Icons.touch_app_rounded,
                                              color: Colors.white
                                                  .withValues(alpha: 0.5),
                                              size: 18,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      // Right Arrow
                      IconButton(
                        icon: Icon(
                          Icons.chevron_right_rounded,
                          color: selectedTab < tabData.length - 1
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.3),
                          size: 32,
                        ),
                        onPressed: selectedTab < tabData.length - 1
                            ? () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                      ),
                    ],
                  ),
                ),

                // Selected Tab Content
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${currentTab['title']} Total',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        _formatCurrency(totalTabAmount),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: currentTab['color'] as Color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Monthly amount for selected tab
                if (monthsWithData.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('MMM yyyy')
                              .format(monthsWithData[currentMonthIndex]),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          _formatCurrency(monthlyTabAmount),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: (currentTab['color'] as Color)
                                .withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsListSliver(ThemeData theme) {
    // Apply combined filters: activeFilter (tab), recipientTypeFilter (advanced), reason, date range
    var filteredRecords = records.where((record) {
      if (activeFilter != null && record.recipientType != activeFilter)
        return false;
      if (recipientTypeFilter != null &&
          record.recipientType != recipientTypeFilter) return false;
      if (selectedReason != null &&
          (record.reason == null || record.reason!.trim() != selectedReason))
        return false;
      if (filterStartDate != null &&
          record.timestamp.isBefore(filterStartDate!)) return false;
      if (filterEndDate != null && record.timestamp.isAfter(filterEndDate!))
        return false;
      return true;
    }).toList();

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filteredRecords = filteredRecords.where((record) {
        // Search in recipient/phone number
        final recipientMatch =
            record.recipient.toLowerCase().contains(searchQuery);

        // Search in masked recipient
        final maskedMatch =
            record.maskedRecipient?.toLowerCase().contains(searchQuery) ??
                false;

        // Search in contact name
        final contactName = _getContactNameForPhone(record.recipient);
        final contactMatch =
            contactName?.toLowerCase().contains(searchQuery) ?? false;

        // Search in amount
        final amountStr = record.amount.toString();
        final amountMatch = amountStr.contains(searchQuery);

        // Search in formatted amount
        final formattedAmount = _formatCurrency(record.amount).toLowerCase();
        final formattedAmountMatch = formattedAmount.contains(searchQuery);

        // Search in date
        final dateStr =
            DateFormat('MMM dd, yyyy').format(record.timestamp).toLowerCase();
        final dateMatch = dateStr.contains(searchQuery);

        // Search in type
        final typeMatch =
            record.recipientType.toLowerCase().contains(searchQuery) ||
                (record.recipientType == 'phone' &&
                    'mobile'.contains(searchQuery)) ||
                (record.recipientType == 'momo' &&
                    'mocode'.contains(searchQuery)) ||
                (record.recipientType == 'misc' &&
                    'miscellaneous'.contains(searchQuery));

        return recipientMatch ||
            maskedMatch ||
            contactMatch ||
            amountMatch ||
            formattedAmountMatch ||
            dateMatch ||
            typeMatch;
      }).toList();
    }

    // Show empty state if no results
    if (filteredRecords.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                searchQuery.isNotEmpty ? Icons.search_off : Icons.filter_alt_off,
                size: 60,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                searchQuery.isNotEmpty
                    ? 'No results for "$searchQuery"'
                    : 'No ${activeFilter == 'phone' ? 'Mobile' : activeFilter == 'momo' ? 'MoCode' : 'Misc'} transactions',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                searchQuery.isNotEmpty
                    ? 'Try different keywords'
                    : 'Tap the filter again to view all',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group records by day (yyyy-MM-dd) with newest date first
    final grouped = _groupRecordsByDay(filteredRecords);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= grouped.length * 2 - 1) return null;

            // Separator on odd indices
            if (index.isOdd) {
              return const SizedBox(height: 12);
            }

            // Group item on even indices
            final groupIndex = index ~/ 2;
            final group = grouped[groupIndex];
            final date = group.key; // 'yyyy-MM-dd'
            final dayRecords = group.value;
            // Parse date for display
            final dateObj = DateTime.parse(date);
            return _buildDayGroup(theme, dateObj, dayRecords);
          },
          childCount: grouped.length * 2 - 1,
        ),
      ),
    );
  }

  // Helper: groups list of records by date key 'yyyy-MM-dd' (newest first)
  List<MapEntry<String, List<UssdRecord>>> _groupRecordsByDay(
      List<UssdRecord> records) {
    final Map<String, List<UssdRecord>> map = {};

    for (final r in records) {
      final key = DateFormat('yyyy-MM-dd').format(r.timestamp);
      map.putIfAbsent(key, () => []).add(r);
    }

    // Convert to list and sort by date descending
    final entries = map.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    // Within each group, sort records by timestamp desc
    for (final entry in entries) {
      entry.value.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    return entries;
  }

  // Helper: format currency with RWF suffix
  String _formatCurrency(double amount) {
    return '${NumberFormat('#,##0', 'en_RW').format(amount)} RWF';
  }

  Widget _buildDayGroup(
      ThemeData theme, DateTime dateObj, List<UssdRecord> dayRecords) {
    final dateKey = DateFormat('yyyy-MM-dd').format(dateObj);
    final isExpanded = expandedGroups.contains(dateKey);

    // Calculate total amount for this day (with or without fees based on toggle)
    final dayTotal = dayRecords.fold<double>(0, (sum, record) {
      return sum + (includeFees ? record.amount + record.calculateFee() : record.amount);
    });

    // Determine color based on active filter
    Color totalColor = theme.colorScheme.onSurface;
    if (activeFilter != null) {
      if (activeFilter == 'phone') {
        totalColor = AppTheme.successColor; // Green
      } else if (activeFilter == 'momo') {
        totalColor = AppTheme.warningColor; // Orange
      } else if (activeFilter == 'misc') {
        totalColor = const Color(0xFF06B6D4); // Cyan
      }
    }

    // Format date labels
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final recordDate = DateTime(dateObj.year, dateObj.month, dateObj.day);

    String dateLabel;
    if (recordDate == today) {
      dateLabel = 'Today';
    } else if (recordDate == yesterday) {
      dateLabel = 'Yesterday';
    } else {
      dateLabel = DateFormat('EEEE, MMM dd, yyyy').format(dateObj);
    }

    return Column(
      children: [
        // Horizontal header with date, total, and expand/collapse button
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                expandedGroups.remove(dateKey);
              } else {
                expandedGroups.add(dateKey);
              }
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.08),
                  theme.colorScheme.primary.withValues(alpha: 0.03),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Date icon and label
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                // Date and count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${dayRecords.length} transaction${dayRecords.length != 1 ? 's' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                // Total amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(dayTotal),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: totalColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Expand/collapse icon
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Collapsible content
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
            child: Column(
              children: dayRecords
                  .map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildRecordCard(theme, r),
                      ))
                  .toList(),
            ),
          ),
          crossFadeState:
              isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }

  Widget _buildRecordCard(ThemeData theme, UssdRecord record) {
    final isPhonePayment = record.recipientType == 'phone';
    final isMiscCode = record.recipientType == 'misc';
    Color color;
    IconData icon;

    if (isPhonePayment) {
      color = AppTheme.successColor; // Green for phone
      icon = Icons.phone_rounded;
    } else if (isMiscCode) {
      color = const Color(0xFF06B6D4); // Cyan for side payments
      icon = Icons.code_rounded;
    } else {
      color = AppTheme.warningColor; // Orange for momo
      icon = Icons.qr_code_rounded;
    }

    return GestureDetector(
      onTap: () => _showRecordActions(record),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Icon and Type
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isPhonePayment
                              ? 'Phone Payment'
                              : (isMiscCode ? 'Misc. Code' : 'Momo Payment'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatCurrency(includeFees ? record.amount + record.calculateFee() : record.amount),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            Builder(
                              builder: (context) {
                                final calculatedFee = record.calculateFee();
                                // Only show fee badge if fees are included and fee > 0
                                if (includeFees && calculatedFee > 0) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '+${_formatCurrency(calculatedFee)}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontSize: 10,
                                        color: color,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      () {
                        if (isPhonePayment) {
                          final phoneDisplay =
                              record.maskedRecipient ?? record.recipient;
                          final contactName =
                              _getContactNameForPhone(record.recipient);
                          return 'To: ${contactName != null && contactName.isNotEmpty ? contactName : phoneDisplay}';
                        } else if (isMiscCode) {
                          // Check if there's a contact name for misc codes too
                          final contactName = record.contactName;
                          return contactName != null && contactName.isNotEmpty
                              ? 'To: $contactName'
                              : 'Code: ${record.recipient}';
                        } else {
                          // Check if there's a contact name for momo codes
                          final contactName = record.contactName;
                          return contactName != null && contactName.isNotEmpty
                              ? 'To: $contactName'
                              : 'Momo Code: ${record.recipient}';
                        }
                      }(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (record.reason != null && record.reason!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Reason: ${record.reason}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('MMM dd, yyyy • HH:mm')
                              .format(record.timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editRecord(UssdRecord record) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditUssdRecordDialog(record: record),
    );

    if (result == true) {
      _loadRecords(); // Refresh the list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction updated successfully')),
        );
      }
    }
  }

  Future<void> _redialRecord(UssdRecord record) async {
    try {
      // Show dialog to confirm if the transaction failed
      final shouldDeleteOriginal = await _showRedialConfirmationDialog(record);

      if (shouldDeleteOriginal == null) {
        // User cancelled the dialog
        return;
      }

      launchUSSD(record.ussdCode, context);

      // If the transaction failed, delete the original record
      if (shouldDeleteOriginal) {
        await UssdRecordService.deleteUssdRecord(record.id);
      }

      // Save a new record for the redial
      final newRecord = record.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
      );
      await UssdRecordService.saveUssdRecord(newRecord);

      _loadRecords(); // Refresh to show the new record

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(shouldDeleteOriginal
              ? 'Failed transaction deleted and redialing...'
              : 'Redialing transaction...'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to redial: $e')),
        );
      }
    }
  }

  Future<bool?> _showRedialConfirmationDialog(UssdRecord record) async {
    bool transactionFailed = false;
    final theme = Theme.of(context);

    return await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.refresh_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              const Text('Redial Transaction'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to redial this transaction:',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount: ${_formatCurrency(record.amount)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'To: ${record.maskedRecipient ?? record.recipient}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  setState(() {
                    transactionFailed = !transactionFailed;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: transactionFailed,
                        onChanged: (value) {
                          setState(() {
                            transactionFailed = value ?? false;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The original transaction failed',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (transactionFailed) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The original transaction will be deleted',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(transactionFailed),
              child: const Text('Redial'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRecord(UssdRecord record) async {
    final confirmed = await _showConfirmationDialog(
      'Mark Transaction as Invalid',
      'Are you sure you want to delete this transaction? Use this for failed or duplicate transactions.',
      confirmText: 'Delete',
    );

    if (confirmed) {
      await UssdRecordService.deleteUssdRecord(record.id);
      _loadRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Invalid transaction deleted successfully')),
        );
      }
    }
  }

  void _showRecordActions(UssdRecord record) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Transaction Actions',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildActionTile(
              icon: Icons.refresh_rounded,
              title: 'Redial',
              subtitle: 'Make the same payment again',
              color: AppTheme.successColor,
              onTap: () {
                Navigator.pop(context);
                _redialRecord(record);
              },
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              icon: Icons.edit_rounded,
              title: 'Edit',
              subtitle: 'Modify transaction details',
              color: theme.colorScheme.primary,
              onTap: () {
                Navigator.pop(context);
                _editRecord(record);
              },
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              icon: Icons.visibility_rounded,
              title: 'View USSD Code',
              subtitle: 'See the full USSD code used',
              color: AppTheme.warningColor,
              onTap: () {
                Navigator.pop(context);
                _showUssdCodeDialog(record);
              },
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              icon: Icons.cancel_rounded,
              title: 'Mark as Invalid',
              subtitle: 'Delete failed or duplicate transaction',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _deleteRecord(record);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
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

  void _showUssdCodeDialog(UssdRecord record) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.dialpad_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            const Text('USSD Code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction Details:',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Amount: ${_formatCurrency(record.amount)}'),
            Builder(
              builder: (context) {
                final calculatedFee = record.calculateFee();
                if (calculatedFee > 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fee: ${_formatCurrency(calculatedFee)}',
                        style: TextStyle(color: theme.colorScheme.secondary)),
                      Divider(height: 12, thickness: 1),
                      Text('Total: ${_formatCurrency(record.amount + calculatedFee)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        )),
                      const SizedBox(height: 4),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Text(
                'Date: ${DateFormat('MMM dd, yyyy • HH:mm').format(record.timestamp)}'),
            if (record.reason != null && record.reason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Reason: ${record.reason}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'USSD Code Used:',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Text(
                record.ussdCode,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
