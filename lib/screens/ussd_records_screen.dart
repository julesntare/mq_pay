import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ussd_record.dart';
import '../services/ussd_record_service.dart';
import '../helpers/app_theme.dart';
import '../helpers/launcher.dart';
import 'edit_ussd_record_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => isLoading = true);

    try {
      final loadedRecords = await UssdRecordService.getUssdRecords();
      final total = await UssdRecordService.getTotalAmount();
      final count = await UssdRecordService.getTotalRecordsCount();
      final typeAmounts = await UssdRecordService.getAmountByRecipientType();

      setState(() {
        records = loadedRecords.reversed.toList(); // Show newest first
        totalAmount = total;
        totalRecords = count;
        amountByType = typeAmounts;
        isLoading = false;
      });

      // Calculate months with data AFTER records are set
      _calculateMonthsWithData(loadedRecords);
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading records: $e')),
        );
      }
    }
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
              : Column(
                  children: [
                    _buildSummaryCards(theme),
                    Expanded(child: _buildRecordsList(theme)),
                  ],
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

  Widget _buildSummaryCards(ThemeData theme) {
    final tabData = [
      {'title': 'Mobile', 'icon': Icons.phone_rounded, 'color': AppTheme.successColor, 'key': 'phone'},
      {'title': 'MoCode', 'icon': Icons.qr_code_rounded, 'color': AppTheme.warningColor, 'key': 'momo'},
      {'title': 'Misc', 'icon': Icons.code_rounded, 'color': AppTheme.primaryColor, 'key': 'misc'},
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            NumberFormat.currency(
                              locale: 'en_RW',
                              symbol: 'RWF ',
                              decimalDigits: 0,
                            ).format(totalAmount),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (monthsWithData.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: currentMonthIndex < monthsWithData.length - 1
                                      ? () => _navigateMonth(1)
                                      : null,
                                  icon: Icon(
                                    Icons.arrow_back_ios_rounded,
                                    color: currentMonthIndex < monthsWithData.length - 1
                                        ? Colors.white
                                        : Colors.white38,
                                    size: 14,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('MMM yyyy').format(monthsWithData[currentMonthIndex]),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: currentMonthIndex > 0 ? () => _navigateMonth(-1) : null,
                                  icon: Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: currentMonthIndex > 0 ? Colors.white : Colors.white38,
                                    size: 14,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            Text(
                              NumberFormat.currency(
                                locale: 'en_RW',
                                symbol: 'RWF ',
                                decimalDigits: 0,
                              ).format(currentMonthTotal),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const Divider(color: Colors.white24, height: 1),

                // Tab Bar
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: List.generate(tabData.length, (index) {
                      final isSelected = selectedTab == index;
                      final tab = tabData[index];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => selectedTab = index),
                          child: Container(
                            margin: EdgeInsets.only(right: index < tabData.length - 1 ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.3)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  tab['icon'] as IconData,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tab['title'] as String,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
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
                        NumberFormat.currency(
                          locale: 'en_RW',
                          symbol: 'RWF ',
                          decimalDigits: 0,
                        ).format(totalTabAmount),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
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
                          DateFormat('MMM yyyy').format(monthsWithData[currentMonthIndex]),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          NumberFormat.currency(
                            locale: 'en_RW',
                            symbol: 'RWF ',
                            decimalDigits: 0,
                          ).format(monthlyTabAmount),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
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


  Widget _buildRecordsList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return _buildRecordCard(theme, record);
      },
    );
  }

  Widget _buildRecordCard(ThemeData theme, UssdRecord record) {
    final isPhonePayment = record.recipientType == 'phone';
    final isMiscCode = record.recipientType == 'misc';
    Color color;
    IconData icon;

    if (isPhonePayment) {
      color = AppTheme.successColor;
      icon = Icons.phone_rounded;
    } else if (isMiscCode) {
      color = AppTheme.primaryColor;
      icon = Icons.code_rounded;
    } else {
      color = AppTheme.warningColor;
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
                        Text(
                          NumberFormat.currency(
                            locale: 'en_RW',
                            symbol: 'RWF ',
                            decimalDigits: 0,
                          ).format(record.amount),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPhonePayment
                          ? 'To: ${record.maskedRecipient ?? record.recipient}'
                          : (isMiscCode
                              ? 'Code: ${record.recipient}'
                              : 'Momo Code: ${record.recipient}'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                        Row(
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              size: 16,
                              color: AppTheme.successColor,
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit_rounded,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.more_vert_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ],
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
      launchUSSD(record.ussdCode, context);

      // Save a new record for the redial
      final newRecord = record.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
      );
      await UssdRecordService.saveUssdRecord(newRecord);

      _loadRecords(); // Refresh to show the new record

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Redialing transaction...')),
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

  Future<void> _deleteRecord(UssdRecord record) async {
    final confirmed = await _showConfirmationDialog(
      'Delete Transaction',
      'Are you sure you want to delete this transaction record?',
      confirmText: 'Delete',
    );

    if (confirmed) {
      await UssdRecordService.deleteUssdRecord(record.id);
      _loadRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted successfully')),
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
              icon: Icons.delete_rounded,
              title: 'Delete',
              subtitle: 'Remove this transaction',
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
            Text(
                'Amount: ${NumberFormat.currency(locale: 'en_RW', symbol: 'RWF ', decimalDigits: 0).format(record.amount)}'),
            Text(
                'Date: ${DateFormat('MMM dd, yyyy • HH:mm').format(record.timestamp)}'),
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
