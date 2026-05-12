import 'package:flutter/material.dart';
import '../generated/l10n.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/localProvider.dart';
import '../helpers/app_theme.dart';
import '../helpers/theme_provider.dart';
import '../services/backup_service.dart';
import '../services/supabase_backup_service.dart';
import 'dart:convert';
import '../widgets/scroll_indicator.dart';
import 'package:file_picker/file_picker.dart';
import '../helpers/safe_date_format.dart';
import '../widgets/accessibility_permission_card.dart';

// Payment Method Model
class PaymentMethod {
  final String id;
  String type; // 'mobile' or 'momo'
  String value; // phone number or momo code
  String provider; // 'MTN', 'Airtel', etc.
  bool isDefault;

  PaymentMethod({
    required this.id,
    required this.type,
    required this.value,
    required this.provider,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'value': value,
        'provider': provider,
        'isDefault': isDefault,
      };

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
        id: json['id'],
        type: json['type'],
        value: json['value'],
        provider: json['provider'],
        isDefault: json['isDefault'] ?? false,
      );
}

// New SettingsPage widget
class SettingsPage extends StatefulWidget {
  final String initialMobile;
  final String initialMomoCode;
  final String selectedLanguage;

  const SettingsPage(
      {super.key,
      required this.initialMobile,
      required this.initialMomoCode,
      required this.selectedLanguage});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController mobileController;
  late TextEditingController momoCodeController;
  late String selectedLanguage;
  List<PaymentMethod> paymentMethods = [];

  // Controllers for adding new payment methods
  final TextEditingController _newPaymentController = TextEditingController();
  String _selectedType = 'mobile';
  String _selectedProvider = 'MTN';

  // Auto-backup settings
  bool _autoBackupEnabled = false;
  String _autoBackupFrequency = 'daily'; // daily, weekly, monthly
  String? _autoBackupLocation; // Custom backup location path

  // Supabase backup settings
  bool _supabaseConfigured = false;

  // ScrollController for scroll indicators
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    mobileController = TextEditingController(text: widget.initialMobile);
    momoCodeController = TextEditingController(text: widget.initialMomoCode);
    selectedLanguage = widget.selectedLanguage;
    _loadPaymentMethods();
    _loadAutoBackupSettings();
    _loadSupabaseSettings();
  }

  Future<void> _loadPaymentMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final paymentMethodsJson = prefs.getString('paymentMethods') ?? '[]';
    final List<dynamic> jsonList = json.decode(paymentMethodsJson);

    setState(() {
      paymentMethods =
          jsonList.map((json) => PaymentMethod.fromJson(json)).toList();

      // If no payment methods exist, migrate from old single mobile/momo
      if (paymentMethods.isEmpty) {
        _migrateOldPaymentMethods();
      }
    });
  }

  Future<void> _loadAutoBackupSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoBackupEnabled = prefs.getBool('autoBackupEnabled') ?? false;
      _autoBackupFrequency = prefs.getString('autoBackupFrequency') ?? 'daily';
      _autoBackupLocation = prefs.getString('autoBackupLocation');
    });
  }

  Future<void> _saveAutoBackupSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoBackupEnabled', _autoBackupEnabled);
    await prefs.setString('autoBackupFrequency', _autoBackupFrequency);
    if (_autoBackupLocation != null) {
      await prefs.setString('autoBackupLocation', _autoBackupLocation!);
    }

    // If enabled, create an initial auto-backup (both local and Supabase)
    if (_autoBackupEnabled) {
      try {
        await BackupService.createAutoBackup();
        await prefs.setInt(
            'lastAutoBackupTimestamp', DateTime.now().millisecondsSinceEpoch);
      } catch (e) {
        // Ignore errors during initial local backup
      }

      // Also create initial Supabase backup if configured
      try {
        if (SupabaseBackupService.isConfigured()) {
          await SupabaseBackupService.uploadBackup();
        }
      } catch (e) {
        // Ignore errors during initial Supabase backup
      }
    }
  }

  Future<void> _selectBackupLocation() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Backup Location',
      );

      if (selectedDirectory != null) {
        setState(() {
          _autoBackupLocation = selectedDirectory;
        });
        await _saveAutoBackupSettings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup location updated: $selectedDirectory'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select backup location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showBackupsDialog() async {
    try {
      // Fetch available backups
      final backups = await BackupService.getAutoBackups();

      if (!mounted) return;

      if (backups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No auto-backups found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show dialog with backups
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(S.of(context).availableBackups),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backups.length,
              itemBuilder: (context, index) {
                final backup = backups[index];
                final modified = backup['modified'] as DateTime;
                final size = backup['size'] as int;
                final sizeInKB = (size / 1024).toStringAsFixed(2);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading:
                        const Icon(Icons.backup_rounded, color: Colors.blue),
                    title: Text(
                      '${modified.day}/${modified.month}/${modified.year} ${modified.hour}:${modified.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('Size: $sizeInKB KB'),
                    trailing: IconButton(
                      icon: const Icon(Icons.restore_rounded),
                      color: Colors.green,
                      onPressed: () async {
                        Navigator.pop(context);
                        await _restoreBackup(backup['path'] as String);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(S.of(context).close),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load backups: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreBackup(String backupPath) async {
    try {
      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(S.of(context).restoreBackupTitle),
          content: const Text(
            'This will merge the backup data with your current data. '
            'Duplicates will be automatically skipped.\n\n'
            'Do you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(S.of(context).cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(S.of(context).restore),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text(S.of(context).restoringBackup),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Restore the backup
      final result = await BackupService.restoreAutoBackup(backupPath);

      if (mounted) {
        // Hide loading indicator
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Reload payment methods
        await _loadPaymentMethods();

        // Show success message with details
        final message = StringBuffer('Backup restored successfully!\n\n');
        message.write('New records: ${result['newRecordsAdded']}\n');
        message.write(
            'Duplicates skipped: ${result['duplicateRecordsSkipped']}\n');
        message.write(
            'New payment methods: ${result['newPaymentMethodsAdded']}\n');
        message.write(
            'Duplicate methods skipped: ${result['duplicatePaymentMethodsSkipped']}');

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text(S.of(context).backupRestoredTitle),
              ],
            ),
            content: Text(message.toString()),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).ok),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restore Failed'),
            content: Text('Failed to restore backup: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).ok),
              ),
            ],
          ),
        );
      }
    }
  }

  void _migrateOldPaymentMethods() {
    if (widget.initialMobile.isNotEmpty) {
      final provider = _getProviderFromNumber(widget.initialMobile);
      paymentMethods.add(PaymentMethod(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'mobile',
        value: widget.initialMobile,
        provider: provider,
        isDefault: true,
      ));
    }

    if (widget.initialMomoCode.isNotEmpty) {
      paymentMethods.add(PaymentMethod(
        id: DateTime.now().millisecondsSinceEpoch.toString() + '1',
        type: 'momo',
        value: widget.initialMomoCode,
        provider: 'General',
        isDefault: paymentMethods.isEmpty,
      ));
    }
  }

  String _getProviderFromNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('072') || cleaned.startsWith('073')) {
      return 'Airtel';
    } else if (cleaned.startsWith('078') || cleaned.startsWith('079')) {
      return 'MTN';
    }
    return 'Unknown';
  }

  String _getFlag(String languageCode) {
    switch (languageCode) {
      case 'fr':
        return '🇫🇷';
      case 'sw':
        return '🇹🇿';
      case 'rw':
        return '🇷🇼';
      default:
        return '🇺🇸';
    }
  }

  String _getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'fr':
        return 'Français';
      case 'sw':
        return 'Kiswahili';
      case 'rw':
        return 'Kinyarwanda';
      default:
        return 'English';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(S.of(context).settings),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        centerTitle: false,
      ),
      body: SafeArea(
        child: ScrollIndicatorWrapper(
          controller: _scrollController,
          showTopIndicator: true,
          showBottomIndicator: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // USSD Auto-Detection
                  const AccessibilityPermissionCard(),
                  const SizedBox(height: 20),

                  // Payment Configuration
                  _buildPaymentConfigSection(context, theme),
                  const SizedBox(height: 20),

                  // Appearance
                  _buildAppearanceSection(context, theme),
                  const SizedBox(height: 12),

                  // Data & Backup
                  _buildDataSection(context, theme),
                  const SizedBox(height: 12),

                  // About
                  _buildAboutSection(context, theme),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildPaymentConfigSection(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.payment_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(S.of(context).paymentMethods,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // List of existing payment methods
            if (paymentMethods.isNotEmpty) ...[
              ...paymentMethods
                  .map((method) => _buildPaymentMethodItem(method, theme)),
              const SizedBox(height: 16),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(S.of(context).noPaymentMethods,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Add new payment method button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddPaymentMethodDialog(context, theme),
                icon: const Icon(Icons.add_rounded),
                label: Text(S.of(context).addPaymentMethod),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodItem(PaymentMethod method, ThemeData theme) {
    IconData icon;
    Color color;

    switch (method.provider.toLowerCase()) {
      case 'mtn':
        icon = Icons.phone_android_rounded;
        color = Colors.yellow.shade700;
        break;
      case 'airtel':
        icon = Icons.phone_android_rounded;
        color = Colors.red.shade600;
        break;
      default:
        icon = method.type == 'mobile'
            ? Icons.phone_rounded
            : Icons.qr_code_rounded;
        color = theme.colorScheme.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: method.isDefault
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: method.isDefault
            ? Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3))
            : null,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method.value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${method.provider} · ${method.type == 'mobile' ? 'Mobile' : 'MoMo Code'}${method.isDefault ? ' · Default' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            onSelected: (value) {
              switch (value) {
                case 'default':
                  _setAsDefault(method);
                  break;
                case 'edit':
                  _editPaymentMethod(method);
                  break;
                case 'delete':
                  _deletePaymentMethod(method);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (!method.isDefault)
                const PopupMenuItem(
                  value: 'default',
                  child: Row(
                    children: [
                      Icon(Icons.star_rounded),
                      SizedBox(width: 8),
                      Text('Set as Default'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, color: Colors.red),
                    SizedBox(width: 8),
                    Text(S.of(context).delete, style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  void _setAsDefault(PaymentMethod method) {
    setState(() {
      // Remove default from all methods
      for (var m in paymentMethods) {
        m.isDefault = false;
      }
      // Set new default
      method.isDefault = true;
    });
    _savePaymentMethods();
  }

  void _editPaymentMethod(PaymentMethod method) {
    _newPaymentController.text = method.value;
    _selectedType = method.type;
    _selectedProvider = method.provider;

    _showAddPaymentMethodDialog(context, Theme.of(context),
        editingMethod: method);
  }

  void _deletePaymentMethod(PaymentMethod method) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).deletePaymentMethod),
        content: Text(
            'Are you sure you want to delete "${method.provider} - ${method.value}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).cancel),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                paymentMethods.remove(method);
                // If deleted method was default, set first remaining as default
                if (method.isDefault && paymentMethods.isNotEmpty) {
                  paymentMethods.first.isDefault = true;
                }
              });
              _savePaymentMethods();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(S.of(context).delete),
          ),
        ],
      ),
    );
  }

  Future<void> _savePaymentMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = paymentMethods.map((method) => method.toJson()).toList();
    await prefs.setString('paymentMethods', json.encode(jsonList));

    // If all payment methods are deleted, clear old storage keys to prevent migration
    if (paymentMethods.isEmpty) {
      await prefs.remove('mobileNumber');
      await prefs.remove('momoCode');
    }
  }

  void _showAddPaymentMethodDialog(BuildContext context, ThemeData theme,
      {PaymentMethod? editingMethod}) {
    final isEditing = editingMethod != null;

    if (!isEditing) {
      _newPaymentController.clear();
      _selectedType = 'mobile';
      _selectedProvider = 'MTN';
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Payment Method' : 'Add Payment Method'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Type Selection
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'mobile', child: Text('Mobile Number')),
                    DropdownMenuItem(value: 'momo', child: Text('Momo Code')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Provider Selection
                DropdownButtonFormField<String>(
                  initialValue: _selectedProvider,
                  decoration: InputDecoration(
                    labelText: S.of(context).providerLabel,
                    prefixIcon: Icon(Icons.business_rounded),
                  ),
                  items: _selectedType == 'mobile'
                      ? const [
                          DropdownMenuItem(value: 'MTN', child: Text('MTN')),
                          DropdownMenuItem(
                              value: 'Airtel', child: Text('Airtel')),
                        ]
                      : [
                          DropdownMenuItem(
                              value: 'General', child: Text(S.of(context).general)),
                          DropdownMenuItem(
                              value: 'MTN', child: Text(S.of(context).mtnMomo)),
                          DropdownMenuItem(
                              value: 'Airtel', child: Text(S.of(context).airtelMoney)),
                        ],
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedProvider = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Value Input
                TextField(
                  controller: _newPaymentController,
                  keyboardType: _selectedType == 'mobile'
                      ? TextInputType.phone
                      : TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _selectedType == 'mobile'
                        ? 'Phone Number'
                        : 'Momo Code',
                    hintText: _selectedType == 'mobile'
                        ? '078xxxxxxx'
                        : 'Enter momo code',
                    prefixIcon: Icon(_selectedType == 'mobile'
                        ? Icons.phone_rounded
                        : Icons.qr_code_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(S.of(context).cancel),
            ),
            ElevatedButton(
              onPressed: () {
                _savePaymentMethod(editingMethod);
                Navigator.pop(context);
              },
              child: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _savePaymentMethod(PaymentMethod? editingMethod) {
    final value = _newPaymentController.text.trim();

    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).pleaseEnterValidValue)),
      );
      return;
    }

    setState(() {
      if (editingMethod != null) {
        // Edit existing method
        editingMethod.value = value;
        editingMethod.type = _selectedType;
        editingMethod.provider = _selectedProvider;
      } else {
        // Add new method
        final newMethod = PaymentMethod(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: _selectedType,
          value: value,
          provider: _selectedProvider,
          isDefault: paymentMethods.isEmpty,
        );
        paymentMethods.add(newMethod);
      }
    });

    _savePaymentMethods();
  }

  Widget _buildAppearanceSection(BuildContext context, ThemeData theme) {
    final currentLang =
        Provider.of<LocaleProvider>(context).locale!.languageCode;
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              ListTile(
                leading: _iconBox(theme,
                    child: Text(_getFlag(currentLang),
                        style: const TextStyle(fontSize: 18))),
                title: Text(_getLanguageName(currentLang)),
                trailing: Icon(Icons.chevron_right_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                onTap: () => _showLanguageBottomSheet(context, theme),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: _iconBox(theme,
                    child: Icon(
                      themeProvider.isDarkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    )),
                title: Text(themeProvider.isDarkMode ? 'Dark' : 'Light'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.light_mode_rounded,
                        size: 16,
                        color: themeProvider.isDarkMode
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.25)
                            : theme.colorScheme.primary),
                    Switch(
                      value: themeProvider.isDarkMode,
                      onChanged: themeProvider.setDarkMode,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Icon(Icons.dark_mode_rounded,
                        size: 16,
                        color: themeProvider.isDarkMode
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.25)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLanguageBottomSheet(BuildContext context, ThemeData theme) {
    final localeProvider =
        Provider.of<LocaleProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, _) {
          final currentLang = localeProvider.locale!.languageCode;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Text(S.of(context).languagePreferences,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...['en', 'fr', 'sw', 'rw'].map((code) => ListTile(
                      leading: Text(_getFlag(code),
                          style: const TextStyle(fontSize: 22)),
                      title: Text(_getLanguageName(code)),
                      trailing: currentLang == code
                          ? Icon(Icons.check_rounded,
                              color: theme.colorScheme.primary)
                          : null,
                      selected: currentLang == code,
                      onTap: () {
                        setState(() => selectedLanguage = code);
                        localeProvider.setLocale(Locale(code));
                        Navigator.pop(ctx);
                      },
                    )),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDataSection(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Local backup actions ---
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              _buildActionTile(context, theme,
                  icon: Icons.download_rounded,
                  label: S.of(context).exportBackup,
                  onTap: _exportBackup),
              const Divider(height: 1, indent: 56),
              _buildActionTile(context, theme,
                  icon: Icons.table_chart_rounded,
                  label: S.of(context).exportToExcel,
                  iconColor: Colors.green.shade600,
                  onTap: _exportToExcel),
              const Divider(height: 1, indent: 56),
              _buildActionTile(context, theme,
                  icon: Icons.upload_rounded,
                  label: S.of(context).importBackup,
                  onTap: _importBackup),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // --- Auto-backup settings ---
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              SwitchListTile(
                secondary: _iconBox(theme,
                    child: Icon(Icons.autorenew_rounded,
                        color: theme.colorScheme.primary, size: 20)),
                title: Text(S.of(context).enableAutoBackup),
                value: _autoBackupEnabled,
                onChanged: (v) {
                  setState(() => _autoBackupEnabled = v);
                  _saveAutoBackupSettings();
                },
                activeThumbColor: theme.colorScheme.primary,
              ),
              if (_autoBackupEnabled) ...[
                const Divider(height: 1, indent: 56),
                Padding(
                  padding: const EdgeInsets.fromLTRB(72, 4, 16, 8),
                  child: Row(
                    children: ['daily', 'weekly', 'monthly'].map((freq) {
                      final isSelected = _autoBackupFrequency == freq;
                      final label =
                          freq[0].toUpperCase() + freq.substring(1);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal)),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _autoBackupFrequency = freq);
                            _saveAutoBackupSettings();
                          },
                          selectedColor: theme.colorScheme.primary
                              .withValues(alpha: 0.15),
                          checkmarkColor: theme.colorScheme.primary,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: _iconBox(theme,
                      child: Icon(Icons.folder_outlined,
                          color: theme.colorScheme.primary, size: 20)),
                  title: Text(
                      _autoBackupLocation ?? S.of(context).backupLocation),
                  subtitle: Text(
                    _autoBackupLocation == null
                        ? 'Default'
                        : _autoBackupLocation!,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(Icons.chevron_right_rounded,
                      size: 20,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  onTap: _selectBackupLocation,
                ),
                const Divider(height: 1, indent: 56),
                _buildActionTile(context, theme,
                    icon: Icons.restore_rounded,
                    label: S.of(context).viewRestoreBackups,
                    onTap: _showBackupsDialog),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // --- Supabase cloud backup ---
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _iconBox(theme,
                        child: Icon(Icons.cloud_rounded,
                            color: theme.colorScheme.primary, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Supabase Cloud',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Text('Sync backups to the cloud',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _supabaseConfigured
                            ? Colors.green.withValues(alpha: 0.12)
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _supabaseConfigured ? 'Active' : 'Not set up',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _supabaseConfigured
                              ? Colors.green.shade700
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_supabaseConfigured) ...[
                const Divider(height: 1, indent: 16),
                _buildActionTile(context, theme,
                    icon: Icons.cloud_upload_rounded,
                    label: S.of(context).uploadBackup,
                    onTap: _uploadToSupabase),
                const Divider(height: 1, indent: 56),
                _buildActionTile(context, theme,
                    icon: Icons.cloud_download_rounded,
                    label: S.of(context).viewBackups,
                    onTap: _viewSupabaseBackups),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: _iconBox(theme,
            child: Icon(Icons.apps_rounded,
                color: theme.colorScheme.primary, size: 20)),
        title: const Text('MQ Pay'),
        trailing: const Text('v1.0.0'),
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, ThemeData theme,
      {required IconData icon,
      required String label,
      Color? iconColor,
      VoidCallback? onTap}) {
    final color = iconColor ?? theme.colorScheme.primary;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label),
      trailing: Icon(Icons.chevron_right_rounded,
          size: 18,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
      onTap: onTap,
    );
  }

  Widget _iconBox(ThemeData theme, {required Widget child}) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
      child: child,
    );
  }

  Future<void> _exportBackup() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(S.of(context).exportingBackup),
                  ],
                ),
              ),
            ),
          );
        },
      );

      // Export backup
      final filePath = await BackupService.exportBackup();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (filePath == null) {
        // User cancelled
        return;
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(S.of(context).backupExportedSuccess,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to export backup: ${e.toString()}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _exportToExcel() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(S.of(context).exportingToExcel),
                  ],
                ),
              ),
            ),
          );
        },
      );

      // Export to Excel
      final filePath = await BackupService.exportToExcel();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (filePath == null) {
        // User cancelled
        return;
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(S.of(context).excelExportedSuccess,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to export to Excel: ${e.toString()}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Text(S.of(context).importBackup),
            ],
          ),
          content: const Text(
            'Importing a backup will replace all your current data including transactions, payment methods, and settings. This action cannot be undone.\n\nDo you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(S.of(context).cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(S.of(context).importingBackup),
                  ],
                ),
              ),
            ),
          );
        },
      );

      // Import backup
      final result = await BackupService.importBackup();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success message with details
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            final theme = Theme.of(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.successColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Backup Restored'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.of(context).backupRestoredMsg),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Merged:',
                          style: theme.textTheme.labelSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${result['newRecordsAdded']} new transactions added',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if ((result['duplicateRecordsSkipped'] ?? 0) > 0)
                          Text(
                            '${result['duplicateRecordsSkipped']} duplicates skipped',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        Text(
                          '${result['newPaymentMethodsAdded']} new payment methods added',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(S.of(context).pleaseRestartApp,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Reload payment methods
                    _loadPaymentMethods();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(S.of(context).ok),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to import backup: ${e.toString()}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _loadSupabaseSettings() async {
    final isConfigured = SupabaseBackupService.isConfigured();

    setState(() {
      _supabaseConfigured = isConfigured;
    });

    // Initialize Supabase if configured
    if (isConfigured) {
      try {
        await SupabaseBackupService.initialize();
      } catch (e) {
        // Already initialized or error - ignore
      }
    }
  }

  Future<void> _uploadToSupabase() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(S.of(context).uploadingToSupabase),
                ],
              ),
            ),
          ),
        ),
      );

      final result = await SupabaseBackupService.uploadBackup();

      if (mounted) {
        Navigator.pop(context);

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Backup Uploaded'),
              ],
            ),
            content: Text(
              'Your backup has been uploaded to Supabase!\n\n'
              'Records: ${result['recordsCount']}\n'
              'Payment Methods: ${result['paymentMethodsCount']}\n\n'
              'Note: Only the 3 most recent backups are kept.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).ok),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _viewSupabaseBackups() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading backups...'),
                ],
              ),
            ),
          ),
        ),
      );

      final backups = await SupabaseBackupService.listBackups();

      if (mounted) {
        Navigator.pop(context);

        if (backups.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context).noBackupsFound),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        showDialog(
          context: context,
          builder: (context) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: const Text('Supabase Backups'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: backups.length,
                  itemBuilder: (context, index) {
                    final backup = backups[index];
                    final created = backup['created'] as DateTime;
                    final localCreated = created.toLocal();
                    final size = backup['size'] as int;
                    final sizeInKB = (size / 1024).toStringAsFixed(2);

                    return Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.cloud_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(
                          safeDateFormat('MMM d, y h:mm a').format(localCreated),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('Size: $sizeInKB KB'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.restore_rounded),
                              color: theme.colorScheme.primary,
                              onPressed: () async {
                                Navigator.pop(context);
                                await _restoreFromSupabase(
                                    backup['path'] as String);
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_rounded),
                            color: Colors.red,
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(S.of(context).deleteBackupTitle),
                                  content: Text(S.of(context).deleteBackupMessage),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(S.of(context).cancel),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: Text(S.of(context).delete),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true && mounted) {
                                Navigator.pop(context);
                                await _deleteSupabaseBackup(
                                    backup['path'] as String);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).close),
              ),
            ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load backups: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreFromSupabase(String backupPath) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).restoreBackupTitle),
        content: const Text(
          'This will merge the backup data with your current data. '
          'Duplicates will be automatically skipped.\n\n'
          'Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context).cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).restore),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(S.of(context).restoringFromSupabase),
                ],
              ),
            ),
          ),
        ),
      );

      final result =
          await SupabaseBackupService.restoreBackup(backupPath: backupPath);

      if (mounted) {
        Navigator.pop(context);

        await _loadPaymentMethods();

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text(S.of(context).backupRestoredTitle),
              ],
            ),
            content: Text(
              'Backup restored successfully!\n\n'
              'New records: ${result['newRecordsAdded']}\n'
              'Duplicates skipped: ${result['duplicateRecordsSkipped']}\n'
              'New payment methods: ${result['newPaymentMethodsAdded']}\n'
              'Duplicate methods skipped: ${result['duplicatePaymentMethodsSkipped']}',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).ok),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSupabaseBackup(String backupPath) async {
    try {
      await SupabaseBackupService.deleteBackup(backupPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).backupDeletedSuccess),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    mobileController.dispose();
    momoCodeController.dispose();
    _newPaymentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
