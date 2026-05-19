import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../generated/l10n.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:call_log/call_log.dart';
import '../helpers/launcher.dart';
import 'settings.dart';
import 'qr_scanner_screen.dart';
import 'ussd_records_screen.dart';
import '../models/ussd_record.dart';
import '../models/transaction_status.dart';
import '../services/ussd_record_service.dart';
import '../services/tariff_service.dart';
import '../services/ussd_transaction_manager.dart';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/favorite_contact.dart';
import '../services/favorites_service.dart';
import '../models/bill_shortcut.dart';
import '../services/bill_shortcuts_service.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController reasonController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController manualMobileController = TextEditingController();
  final TextEditingController momoCodeController = TextEditingController();
  final FocusNode amountFocusNode = FocusNode();
  final FocusNode phoneFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String? selectedNumber;
  String? selectedName;
  bool showManualInput = true;
  ContactSuggestion? _selectedContact;

  // Multistep form variables
  int currentStep = 0;
  bool recipientFirst = false;
  bool isPhoneNumberMomo = false;
  bool isRecordOnlyMode = false; // true = Record Only, false = Dial Now
  bool isReceiveMode =
      false; // true = Generate QR to Receive, false = Send Money

  String? generatedUssdCode;
  bool showQrCode = false;

  String mobileNumber = '';
  String momoCode = '';
  String scannedData = '';
  String? selectedLanguage = 'en';
  String selectedPaymentMethod = 'auto'; // 'auto', 'mobile', 'momo'
  List<PaymentMethod> paymentMethods = [];

  // Contact autocomplete variables
  List<Contact> allContacts = [];
  List<ContactSuggestion> filteredContacts = [];
  bool isLoadingContacts = false;
  bool _suggestionDismissed = false;
  List<CallLogEntry> _recentCallLog = [];
  bool _isLoadingRecentCalls = false;
  bool _recentCallPermissionDenied = false;

  // Favorites
  List<FavoriteContact> _favorites = [];
  List<FavoriteContact> _frequentContacts = [];

  // Bill shortcuts
  List<BillShortcut> _billShortcuts = [];

  Future<void> _loadFavorites() async {
    final favs = await FavoritesService.getFavorites();
    if (mounted) setState(() => _favorites = favs);
  }

  Future<void> _loadFrequentContacts() async {
    final records = await UssdRecordService.getUssdRecords();
    final counts = <String, int>{};
    final displayNames = <String, String>{};

    for (final r in records) {
      if (r.status == TransactionStatus.success &&
          r.recipient.isNotEmpty &&
          (_isValidPhoneNumber(r.recipient) || _isValidMomoCode(r.recipient))) {
        counts[r.recipient] = (counts[r.recipient] ?? 0) + 1;
        if (r.contactName != null && r.contactName!.isNotEmpty) {
          displayNames[r.recipient] = r.contactName!;
        } else if (!displayNames.containsKey(r.recipient)) {
          displayNames[r.recipient] = r.maskedRecipient ?? r.recipient;
        }
      }
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final frequent = sorted
        .take(5)
        .map((e) => FavoriteContact(
              name: displayNames[e.key] ?? e.key,
              phoneNumber: e.key,
            ))
        .toList();

    if (mounted) setState(() => _frequentContacts = frequent);
  }

  Future<void> _loadBillShortcuts() async {
    final shortcuts = await BillShortcutsService.getShortcuts();
    if (mounted) setState(() => _billShortcuts = shortcuts);
  }

  Future<void> _toggleFavorite(ContactSuggestion contact) async {
    final fav = FavoriteContact(
      name: contact.name,
      phoneNumber: contact.phoneNumber,
      originalPhone: contact.originalPhone,
    );
    final alreadyFav = _favorites.any((f) => f.phoneNumber == fav.phoneNumber);
    if (alreadyFav) {
      await FavoritesService.removeFavorite(fav.phoneNumber);
    } else {
      await FavoritesService.addFavorite(fav);
    }
    await _loadFavorites();
  }

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
    _loadFavorites();
    _loadFrequentContacts();
    _loadBillShortcuts();
    phoneFocusNode.addListener(_onPhoneFocusChanged);
    // Request focus on amount field after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      amountFocusNode.requestFocus();
    });
  }

  String _maskPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.length >= 10) {
      // Show first 3 digits, mask middle digits, show last 2 digits
      String first = cleaned.substring(0, 3);
      String last = cleaned.substring(cleaned.length - 2);
      String masked = '*' * (cleaned.length - 5);
      return '$first$masked$last';
    }
    return phoneNumber; // Return original if too short
  }

  String _formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    // Handle different formats
    if (cleaned.startsWith('25078') ||
        cleaned.startsWith('25079') ||
        cleaned.startsWith('25072') ||
        cleaned.startsWith('25073')) {
      // Format: 25078xxxxxxx -> 078xxxxxxx
      cleaned = '0' + cleaned.substring(3);
    } else if (cleaned.startsWith('2507')) {
      // Format: 2507xxxxxxxx -> 07xxxxxxxx
      cleaned = '0' + cleaned.substring(3);
    } else if (cleaned.startsWith('78') ||
        cleaned.startsWith('79') ||
        cleaned.startsWith('72') ||
        cleaned.startsWith('73')) {
      // Format: 78xxxxxxx -> 078xxxxxxx
      cleaned = '0' + cleaned;
    } else if (cleaned.startsWith('8') ||
        cleaned.startsWith('9') ||
        cleaned.startsWith('2') ||
        cleaned.startsWith('3')) {
      // Format: 8xxxxxxxx -> 078xxxxxxx
      cleaned = '07' + cleaned;
    }

    // Ensure it's exactly 10 digits and starts with 07(8|9|2|3)
    if (cleaned.length == 10 &&
        (cleaned.startsWith('078') ||
            cleaned.startsWith('079') ||
            cleaned.startsWith('072') ||
            cleaned.startsWith('073'))) {
      return cleaned;
    }

    // If we can't format it properly, return empty string to indicate invalid
    return '';
  }

  bool _isValidPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    // Check if it starts with valid prefixes and has correct length
    if (cleaned.startsWith('25078') ||
        cleaned.startsWith('25079') ||
        cleaned.startsWith('25072') ||
        cleaned.startsWith('25073')) {
      return cleaned.length == 12; // +25078xxxxxxx
    } else if (cleaned.startsWith('078') ||
        cleaned.startsWith('079') ||
        cleaned.startsWith('072') ||
        cleaned.startsWith('073')) {
      return cleaned.length == 10; // 078xxxxxxx
    } else if (cleaned.startsWith('78') ||
        cleaned.startsWith('79') ||
        cleaned.startsWith('72') ||
        cleaned.startsWith('73')) {
      return cleaned.length == 9; // 78xxxxxxx
    }

    return false;
  }

  bool _isValidMomoCode(String momoCode) {
    // Remove all non-digit characters
    String cleaned = momoCode.replaceAll(RegExp(r'[^0-9]'), '');

    // Momo codes are typically more than 3 digits
    return cleaned.length >= 3;
  }

  void _nextStep() {
    if (currentStep < 1) {
      setState(() {
        currentStep++;
      });

      if (currentStep == 1) {
        Future.delayed(const Duration(milliseconds: 350), () {
          final focusNode = recipientFirst ? amountFocusNode : phoneFocusNode;
          focusNode.requestFocus();
          Future.delayed(const Duration(milliseconds: 300), () {
            if (context.mounted && focusNode.context != null) {
              Scrollable.ensureVisible(
                focusNode.context!,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });
        });
      }
    }
  }

  void _previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });

      if (currentStep == 0) {
        Future.delayed(const Duration(milliseconds: 350), () {
          final focusNode = recipientFirst ? phoneFocusNode : amountFocusNode;
          focusNode.requestFocus();
        });
      }
    }
  }

  void _resetForm() {
    setState(() {
      currentStep = 0;
      amountController.clear();
      mobileController.clear();
      reasonController.clear();
      isPhoneNumberMomo = false;
      isRecordOnlyMode = false;
      selectedName = null;
      _selectedContact = null;
      filteredContacts = [];
      _suggestionDismissed = true;
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      amountFocusNode.requestFocus();
    });
  }

  String _getServiceType(String phoneNumber) {
    // Remove all non-digit characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    // Normalize to 10-digit format starting with 07
    if (cleaned.startsWith('25078') ||
        cleaned.startsWith('25079') ||
        cleaned.startsWith('25072') ||
        cleaned.startsWith('25073')) {
      cleaned = '0' + cleaned.substring(3);
    } else if (cleaned.startsWith('2507')) {
      cleaned = '0' + cleaned.substring(3);
    } else if (cleaned.startsWith('78') ||
        cleaned.startsWith('79') ||
        cleaned.startsWith('72') ||
        cleaned.startsWith('73')) {
      cleaned = '0' + cleaned;
    }

    // Return service type based on prefix
    if (cleaned.startsWith('072') || cleaned.startsWith('073')) {
      return '2'; // Airtel
    } else if (cleaned.startsWith('078') || cleaned.startsWith('079')) {
      return '1'; // MTN
    }

    return '1'; // Default to MTN
  }

  @override
  void dispose() {
    amountController.dispose();
    reasonController.dispose();
    mobileController.dispose();
    manualMobileController.dispose();
    momoCodeController.dispose();
    amountFocusNode.dispose();
    phoneFocusNode.removeListener(_onPhoneFocusChanged);
    phoneFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      mobileNumber = prefs.getString('mobileNumber') ?? '';
      momoCode = prefs.getString('momoCode') ?? '';

      // Load payment methods
      final paymentMethodsJson = prefs.getString('paymentMethods');
      if (paymentMethodsJson != null) {
        final List<dynamic> methodList = jsonDecode(paymentMethodsJson);
        paymentMethods =
            methodList.map((json) => PaymentMethod.fromJson(json)).toList();
      }
    });
  }

  Future<void> _scanQrCode() async {
    try {
      final result = await Navigator.of(context).push<String?>(
        MaterialPageRoute(
          builder: (context) => const QrScannerScreen(),
        ),
      );

      if (result == null) {
        return; // User cancelled scanning
      }

      setState(() {
        scannedData = result;
      });

      // Try to parse as payment request JSON
      try {
        final paymentData = jsonDecode(result);
        if (paymentData is Map && paymentData['type'] == 'payment_request') {
          // Handle payment request QR code
          final amount = paymentData['amount']?.toString() ?? '';
          final recipient = paymentData['recipient']?.toString();

          setState(() {
            amountController.text = amount;
            if (recipient != null && recipient.isNotEmpty) {
              mobileController.text = recipient;
            }
            _selectedContact = null;
            _suggestionDismissed = true;
            currentStep = 1;
          });

          // Focus on phone field for next input
          WidgetsBinding.instance.addPostFrameCallback((_) {
            phoneFocusNode.requestFocus();
          });

          final message = recipient != null && recipient.isNotEmpty
              ? 'Payment request scanned: $amount RWF to ${_maskPhoneNumber(recipient)}'
              : 'Payment request scanned: $amount RWF';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
      } catch (e) {
        // Not a JSON payment request, continue with other checks
      }

      // Check if scanned data is a phone number or momo code pattern
      if (_isValidPhoneNumber(result) || _isValidMomoCode(result)) {
        // Populate the mobile field and advance to step 2
        setState(() {
          mobileController.text = result;
          _selectedContact = null;
          currentStep = 1;
          _suggestionDismissed = true;
        });

        // Focus on amount field for next input
        WidgetsBinding.instance.addPostFrameCallback((_) {
          phoneFocusNode.requestFocus();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).scannedResult(result)),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      // Validate if the scanned data is a USSD-like text
      final ussdPattern = RegExp(r'^\*[\d*#]+#$');
      if (!ussdPattern.hasMatch(scannedData)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).invalidUssdCode)),
        );
        return;
      }

      setState(() {
        generatedUssdCode = null;
        showQrCode = false;
        amountController.clear();
      });

      launchUSSD(scannedData, context);
    } catch (e) {
      setState(() {
        scannedData = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAppHeader(context, theme),
                  const SizedBox(height: 16),
                  _buildFavoritesRow(theme),
                  _buildBillShortcutsRow(context, theme),
                  _buildStreamlinedPaymentForm(context, theme),
                ],
              ),
            ),
          ),
          if (_shouldShowSuggestionsOverlay()) _buildSuggestionsOverlay(theme),
        ],
      ),
    );
  }

  void _checkBalance() {
    final prefix = mobileNumber.replaceAll(RegExp(r'\D'), '');
    String? ussd;
    if (prefix.startsWith('078') ||
        prefix.startsWith('079') ||
        prefix.startsWith('25078') ||
        prefix.startsWith('25079')) {
      ussd = '*182*6*1#';
    } else if (prefix.startsWith('072') ||
        prefix.startsWith('073') ||
        prefix.startsWith('25072') ||
        prefix.startsWith('25073')) {
      ussd = '*182*3*2#';
    }

    if (ussd != null) {
      launchUSSD(ussd, context);
      return;
    }

    // Network unknown — let user pick
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Check balance'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              launchUSSD('*182*6*1#', context);
            },
            child: const Text('MTN MoMo'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              launchUSSD('*182*3*2#', context);
            },
            child: const Text('Airtel eKash'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppHeader(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _checkBalance,
              icon: Icon(
                Icons.account_balance_wallet_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                size: 26,
              ),
              tooltip: 'Check balance',
            ),
            IconButton(
              onPressed: _scanQrCode,
              icon: Icon(
                Icons.qr_code_scanner_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                size: 28,
              ),
              tooltip: S.of(context).scanNow,
            ),
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UssdRecordsScreen(),
                ),
              ),
              icon: Icon(
                Icons.history_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                size: 28,
              ),
            ),
            IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => SettingsPage(
                            initialMobile: mobileNumber,
                            initialMomoCode: momoCode,
                            selectedLanguage: selectedLanguage ?? 'en',
                          )),
                );
                _loadSavedPreferences();
              },
              icon: Icon(
                Icons.settings_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                size: 28,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFavoritesRow(ThemeData theme) {
    final favPhones = _favorites.map((f) => f.phoneNumber).toSet();
    final filteredFrequent =
        _frequentContacts.where((f) => !favPhones.contains(f.phoneNumber)).toList();

    // (contact, isPinned) — skip any entry with no usable phone number
    final items = [
      ..._favorites.where((f) => f.phoneNumber.isNotEmpty).map((f) => (f, true)),
      ...filteredFrequent.where((f) => f.phoneNumber.isNotEmpty).map((f) => (f, false)),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Favorites',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final (fav, isPinned) = items[i];
              final initials = fav.name.isNotEmpty
                  ? fav.name
                      .trim()
                      .split(' ')
                      .map((w) => w[0])
                      .take(2)
                      .join()
                      .toUpperCase()
                  : '?';

              return GestureDetector(
                onTap: () {
                  setState(() {
                    mobileController.text = fav.phoneNumber;
                    _selectedContact = ContactSuggestion(
                      name: fav.name,
                      phoneNumber: fav.phoneNumber,
                      originalPhone: fav.originalPhone ?? fav.phoneNumber,
                    );
                    isPhoneNumberMomo = _isValidMomoCode(fav.phoneNumber) &&
                        !_isValidPhoneNumber(fav.phoneNumber);
                    _suggestionDismissed = true;
                    currentStep = 0;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    amountFocusNode.requestFocus();
                  });
                },
                onLongPress: () async {
                  if (isPinned) {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Remove ${fav.name}?'),
                        content: const Text('Remove from favorites?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Remove')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await FavoritesService.removeFavorite(fav.phoneNumber);
                      await _loadFavorites();
                    }
                  } else {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Pin ${fav.name}?'),
                        content: const Text('Add to favorites so they always appear here?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Pin')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await FavoritesService.addFavorite(fav);
                      await _loadFavorites();
                    }
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: isPinned
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          child: Text(
                            initials,
                            style: TextStyle(
                              color: isPinned
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.75),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPinned
                                  ? Icons.star_rounded
                                  : Icons.history_rounded,
                              size: 12,
                              color: isPinned
                                  ? Colors.amber
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 60,
                      child: Text(
                        fav.name.split(' ').first,
                        style: theme.textTheme.labelSmall,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _showAddShortcutDialog(BuildContext context) async {
    final labelCtrl = TextEditingController();
    final recipientCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add bill shortcut'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                  labelText: 'Label', hintText: 'e.g. Electricity'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: recipientCtrl,
              decoration: const InputDecoration(
                  labelText: 'Phone / MoMo code',
                  hintText: 'e.g. 0788123456 or 182800'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(
                  labelText: 'Default amount (optional)',
                  hintText: 'e.g. 5000 or 5k'),
              keyboardType: TextInputType.text,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );

    if (confirmed != true) return;

    final label = labelCtrl.text.trim();
    final recipient = recipientCtrl.text.trim();
    if (label.isEmpty || recipient.isEmpty) return;

    double? amount;
    final rawAmount = amountCtrl.text.trim();
    if (rawAmount.isNotEmpty) {
      amount = double.tryParse(_expandShorthand(rawAmount.replaceAll(',', '')));
    }

    await BillShortcutsService.addShortcut(BillShortcut(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      recipient: recipient,
      defaultAmount: amount,
    ));
    await _loadBillShortcuts();
  }

  Widget _buildBillShortcutsRow(BuildContext context, ThemeData theme) {
    final hasShortcuts = _billShortcuts.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Quick pay',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _showAddShortcutDialog(context),
              child: Icon(Icons.add_circle_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.primary.withValues(alpha: 0.7)),
            ),
          ],
        ),
        if (hasShortcuts) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _billShortcuts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final s = _billShortcuts[i];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      mobileController.text = s.recipient;
                      _selectedContact = null;
                      isPhoneNumberMomo = _isValidMomoCode(s.recipient) &&
                          !_isValidPhoneNumber(s.recipient);
                      _suggestionDismissed = true;
                      if (s.defaultAmount != null) {
                        amountController.text =
                            s.defaultAmount!.toStringAsFixed(0);
                        currentStep = 1;
                      } else {
                        currentStep = 0;
                      }
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (s.defaultAmount != null) {
                        phoneFocusNode.requestFocus();
                      } else {
                        amountFocusNode.requestFocus();
                      }
                    });
                  },
                  onLongPress: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Remove "${s.label}"?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Remove')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await BillShortcutsService.removeShortcut(s.id);
                      await _loadBillShortcuts();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(s.label,
                            style: theme.textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        if (s.defaultAmount != null)
                          Text(
                            '${s.defaultAmount!.toStringAsFixed(0)} RWF',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ] else ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _showAddShortcutDialog(context),
            child: Text(
              'Tap + to add a quick-pay shortcut',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildStreamlinedPaymentForm(BuildContext context, ThemeData theme) {
    return Container(
      constraints: BoxConstraints(maxWidth: 400),
      width: double.infinity,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mode Selector (Send vs Receive)
              // Enhanced Send Money / Get Paid Toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedScale(
                        scale: !isReceiveMode ? 1.0 : 0.98,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => isReceiveMode = false);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: !isReceiveMode
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.send_rounded,
                                  size: 22,
                                  color: !isReceiveMode
                                      ? Colors.white
                                      : theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    S.of(context).sendMoney,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: !isReceiveMode
                                          ? Colors.white
                                          : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: AnimatedScale(
                        scale: isReceiveMode ? 1.0 : 0.98,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => isReceiveMode = true);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isReceiveMode
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 22,
                                  color: isReceiveMode
                                      ? Colors.white
                                      : theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    S.of(context).getPaid,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isReceiveMode
                                          ? Colors.white
                                          : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form Title with Step Indicator (only for Send mode)
              if (!isReceiveMode) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Record Only label + switch
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          S.of(context).recordOnly,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isRecordOnlyMode
                                ? theme.colorScheme.secondary
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                            fontWeight: isRecordOnlyMode
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: S.of(context).recordOnlyExplain,
                          child: Switch(
                            value: isRecordOnlyMode,
                            onChanged: (v) =>
                                setState(() => isRecordOnlyMode = v),
                            activeThumbColor: theme.colorScheme.secondary,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ] else ...[
                Text(
                  S.of(context).generatePaymentQr,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  S.of(context).createQrCodeDesc,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Content based on mode
              if (isReceiveMode) ...[
                // Receive Mode - Just amount input and generate button
                _buildReceiveMode(theme),
              ] else ...[
                // Send Mode — step order indicator with swap
                _buildStepOrderIndicator(theme),
                const SizedBox(height: 32),

                // Step Content
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: currentStep == 0
                      ? (recipientFirst
                          ? _buildPhoneStep(theme)
                          : _buildAmountStep(theme))
                      : (recipientFirst
                          ? _buildAmountStep(theme)
                          : _buildPhoneStep(theme)),
                ),

                const SizedBox(height: 24),

                // Navigation Buttons
                Row(
                  children: [
                    if (currentStep > 0)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _previousStep,
                          icon: Icon(Icons.arrow_back_rounded),
                          label: Text(S.of(context).back),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ),
                    if (currentStep > 0) const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _getNextButtonAction(),
                        icon: Icon(currentStep == 0
                            ? Icons.arrow_forward_rounded
                            : (isRecordOnlyMode
                                ? Icons.save_rounded
                                : Icons.send_rounded)),
                        label: Text(
                          currentStep == 0
                              ? S.of(context).next
                              : (isRecordOnlyMode
                                  ? S.of(context).saveRecord
                                  : S.of(context).payNow),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: theme.colorScheme.onSurface
                              .withValues(alpha: 0.12),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiveMode(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Amount input
        TextField(
          controller: amountController,
          focusNode: amountFocusNode,
          keyboardType: TextInputType.text,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9kKmM.,]')),
          ],
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            labelText: S.of(context).amountRwf,
            hintText: S.of(context).enterAmount,
            helperText: 'e.g. 5000, 5k, 2.5m',
            prefixIcon: const Icon(Icons.attach_money_rounded),
            suffixIcon: amountController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    onPressed: () => setState(() => amountController.clear()),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 20,
            ),
          ),
          onChanged: (value) {
            final trimmed = value.replaceAll(',', '').trim();
            final lower = trimmed.toLowerCase();
            if (lower.endsWith('k') || lower.endsWith('m')) {
              final expanded = _expandShorthand(trimmed);
              final n = int.tryParse(expanded);
              if (n != null) {
                final formatted = _formatAmountDisplay(n.toString());
                amountController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
                setState(() {});
                return;
              }
            }
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        if (amountController.text.isNotEmpty && !_isValidAmount())
          Text(
            'Please enter a valid amount (minimum 1 RWF)',
            style: TextStyle(
              color: theme.colorScheme.error,
              fontSize: 14,
            ),
          ),
        const SizedBox(height: 24),

        // Generate QR Button
        ElevatedButton.icon(
          onPressed: _isValidAmount() ? () => _showQrCodeDialog(context) : null,
          icon: Icon(Icons.qr_code_2_rounded, size: 24),
          label: Text(
            S.of(context).generateQrCode,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                theme.colorScheme.onSurface.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Info text
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  S.of(context).generateQrHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountStep(ThemeData theme) {
    final hasPreselected = mobileController.text.isNotEmpty;
    final recipientLabel = _selectedContact?.name.isNotEmpty == true
        ? _selectedContact!.name
        : mobileController.text;

    return Column(
      key: const ValueKey('amount'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context).enterAmount,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),

        if (hasPreselected) ...[
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_rounded,
                          size: 14,
                          color: theme.colorScheme.onPrimaryContainer),
                      const SizedBox(width: 6),
                      Text(
                        'Paying $recipientLabel',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() {
                          mobileController.clear();
                          _selectedContact = null;
                        }),
                        child: Icon(Icons.close_rounded,
                            size: 14,
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Quick amount presets
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [500, 1000, 2000, 5000, 10000, 20000, 50000, 100000].map((amt) {
            final label = amt >= 1000 ? '${amt ~/ 1000}K' : '$amt';
            final isSelected = _getRawAmount() == amt.toString();
            return GestureDetector(
              onTap: () {
                setState(() {
                  amountController.text = _formatAmountDisplay(amt.toString());
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color:
                        isSelected ? Colors.white : theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),
        TextField(
          controller: amountController,
          focusNode: amountFocusNode,
          keyboardType: TextInputType.text,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9kKmM.,]')),
          ],
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            labelText: S.of(context).amountRwf,
            hintText: S.of(context).enterAmount,
            helperText: 'e.g. 5000, 5k, 2.5m',
            prefixIcon: const Icon(Icons.attach_money_rounded),
            suffixIcon: amountController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    onPressed: () => setState(() => amountController.clear()),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 20,
            ),
          ),
          onChanged: (value) {
            final trimmed = value.replaceAll(',', '').trim();
            final lower = trimmed.toLowerCase();

            if (lower.endsWith('k') || lower.endsWith('m')) {
              // Expand shorthand immediately when the suffix is typed.
              final expanded = _expandShorthand(trimmed);
              final n = int.tryParse(expanded);
              if (n != null) {
                final formatted = _formatAmountDisplay(n.toString());
                amountController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
                setState(() {});
                return;
              }
            }

            // Plain integer: keep commas in sync.
            final n = int.tryParse(trimmed);
            if (n != null) {
              final formatted = _formatAmountDisplay(n.toString());
              if (formatted != value) {
                amountController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
            }
            // Intermediate decimal like "1.5" (before k/m is typed): leave as-is.
            setState(() {});
          },
          onSubmitted: (_) {
            if (_isValidAmount()) {
              if (recipientFirst && currentStep == 1) {
                if (_canProceedWithPayment()) _processPayment(context);
              } else {
                _nextStep();
              }
            }
          },
        ),
        const SizedBox(height: 16),
        if (amountController.text.isNotEmpty && !_isValidAmount())
          Text(
            'Please enter a valid amount (minimum 1 RWF)',
            style: TextStyle(
              color: theme.colorScheme.error,
              fontSize: 14,
            ),
          ),
      ],
    );
  }

  Widget _buildPhoneStep(ThemeData theme) {
    final rawPhone = mobileController.text.trim();
    final bool isValidPhone = _isValidPhoneNumber(rawPhone);
    final bool isValidMomo = _isValidMomoCode(rawPhone);
    final bool hasValidContact = isValidPhone || isValidMomo;

    // Inline fee preview when amount + valid contact are both present
    Map<String, dynamic>? feeData;
    if (_isValidAmount() && hasValidContact) {
      final recipientType = isValidPhone ? 'phone' : 'momo';
      final serviceType =
          isValidPhone ? _getServiceType(_formatPhoneNumber(rawPhone)) : null;
      feeData = TariffService.getFeeBreakdown(
        amount: double.tryParse(_getRawAmount()) ?? 0,
        recipientType: recipientType,
        serviceType: serviceType,
      );
    }

    return Column(
      key: const ValueKey('contact'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context).recipientInfo,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 24),

        // Contact chip (when a contact is selected) OR unified input field
        if (_selectedContact != null)
          _buildSelectedContactChip(theme)
        else
          TextField(
            controller: mobileController,
            focusNode: phoneFocusNode,
            keyboardType: TextInputType.text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: isRecordOnlyMode
                  ? S.of(context).phoneOrMomoOptional
                  : S.of(context).phoneOrMomo,
              hintText: S.of(context).typeNamePhoneOrMomoHint,
              prefixIcon: const Icon(Icons.person_search_rounded),
              suffixIcon: isLoadingContacts
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : mobileController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                          onPressed: () => setState(() {
                            mobileController.clear();
                            filteredContacts = [];
                            selectedName = null;
                            _suggestionDismissed = false;
                          }),
                          tooltip: S.of(context).clearAction,
                        )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              helperText: _getInputHelperText(),
            ),
            onChanged: (value) {
              setState(() {
                isPhoneNumberMomo =
                    _isValidMomoCode(value) && !_isValidPhoneNumber(value);
                _suggestionDismissed = false;
              });
              _filterContacts(value);
            },
            onSubmitted: (value) {
              if (filteredContacts.isNotEmpty && !_suggestionDismissed) {
                _selectContactSuggestion(filteredContacts[0]);
                return;
              }
              if (recipientFirst && currentStep == 0) {
                final hasValid = isRecordOnlyMode ||
                    _isValidPhoneNumber(value) ||
                    _isValidMomoCode(value);
                if (hasValid) _nextStep();
              } else if (_canProceedWithPayment()) {
                _processPayment(context);
              }
            },
          ),

        const SizedBox(height: 12),

        // Validation error (only for unresolved free-text that isn't valid)
        if (_selectedContact == null &&
            rawPhone.isNotEmpty &&
            !hasValidContact &&
            !isRecordOnlyMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Please enter a valid phone number (078xxxxxxx) or momo code',
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ),

        // Type badge for raw valid input (no chip selected)
        if (_selectedContact == null && hasValidContact)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isValidPhone ? Icons.phone_rounded : Icons.qr_code_rounded,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isValidPhone
                      ? S.of(context).validPhoneDetected
                      : S.of(context).validMomoDetected,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        // Inline fee preview
        if (feeData != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  'Fee: ${feeData['formattedFee']}  ·  Total: ${feeData['formattedTotal']}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.secondary),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepOrderIndicator(ThemeData theme) {
    final bool step1IsAmount = !recipientFirst;
    final bool canSwap = currentStep == 0;

    Widget pill({
      required IconData icon,
      required String label,
      required bool active,
    }) {
      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: active
                      ? Colors.white
                      : theme.colorScheme.primary.withValues(alpha: 0.5)),
              const SizedBox(width: 5),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: active
                      ? Colors.white
                      : theme.colorScheme.primary.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        pill(
          icon: step1IsAmount
              ? Icons.attach_money_rounded
              : Icons.person_search_rounded,
          label: step1IsAmount ? 'Amount' : 'Contact',
          active: true,
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: canSwap
              ? () => setState(() => recipientFirst = !recipientFirst)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: canSwap
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.swap_horiz_rounded,
              size: 18,
              color: canSwap
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
          ),
        ),
        const SizedBox(width: 6),
        pill(
          icon: step1IsAmount
              ? Icons.person_search_rounded
              : Icons.attach_money_rounded,
          label: step1IsAmount ? 'Contact' : 'Amount',
          active: currentStep >= 1,
        ),
      ],
    );
  }

  Widget _buildSelectedContactChip(ThemeData theme) {
    final contact = _selectedContact!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            radius: 22,
            child: Icon(Icons.person_rounded,
                color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _maskPhoneNumber(contact.phoneNumber),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            onPressed: _clearSelectedContact,
            tooltip: S.of(context).clearAction,
          ),
        ],
      ),
    );
  }

  String _getInputHelperText() {
    if (mobileController.text.isEmpty) {
      return S.of(context).phoneOrMomoExample;
    } else if (_isValidPhoneNumber(mobileController.text)) {
      return S.of(context).phoneFormatDetected;
    } else if (_isValidMomoCode(mobileController.text)) {
      return S.of(context).momoFormatDetected;
    } else {
      return S.of(context).enterValidPhoneOrMomo;
    }
  }

  VoidCallback? _getNextButtonAction() {
    if (currentStep == 0) {
      if (recipientFirst) {
        final hasValidRecipient = isRecordOnlyMode ||
            (mobileController.text.isNotEmpty &&
                (_isValidPhoneNumber(mobileController.text) ||
                    _isValidMomoCode(mobileController.text)));
        return hasValidRecipient ? _nextStep : null;
      }
      return _isValidAmount() ? _nextStep : null;
    } else {
      return _canProceedWithPayment() ? () => _processPayment(context) : null;
    }
  }

  bool _canProceedWithPayment() {
    // In Record Only mode, recipient is optional
    if (isRecordOnlyMode) {
      return _isValidAmount();
    }

    // In Dial Now mode, recipient is required and must be valid
    return _isValidAmount() &&
        mobileController.text.isNotEmpty &&
        (_isValidPhoneNumber(mobileController.text) ||
            _isValidMomoCode(mobileController.text));
  }

  void _processPayment(BuildContext context) {
    if (_selectedContact != null) {
      selectedName = _selectedContact!.name;
    }

    // Handle Record Only mode
    if (isRecordOnlyMode) {
      _showRecordOnlyDialog(context);
      return;
    }

    // Handle Dial Now mode (existing logic)
    String input = mobileController.text.trim();
    String ussdCode;
    String? serviceType;

    // Determine if input is phone number or momo code
    if (_isValidPhoneNumber(input)) {
      // Process as phone number
      String formattedPhone = _formatPhoneNumber(input);
      serviceType = _getServiceType(formattedPhone);
      ussdCode = '*182*1*$serviceType*$formattedPhone*${_getRawAmount()}#';
    } else if (_isValidMomoCode(input)) {
      // Process as momo code
      ussdCode = '*182*8*1*$input*${_getRawAmount()}#';
      serviceType = null; // MoMo codes don't have service type
    } else {
      // Should not reach here due to validation, but handle gracefully
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).invalidPhoneOrMomo)),
      );
      return;
    }

    // Show the USSD code in a dialog
    _showUssdDialog(context, ussdCode, input, serviceType);
  }

  Future<void> _showUssdDialog(BuildContext context, String ussdCode,
      String paymentInfo, String? serviceType) async {
    final theme = Theme.of(context);
    bool isPhoneNumber = _isValidPhoneNumber(paymentInfo);

    // Calculate fee
    double amount = double.tryParse(_getRawAmount()) ?? 0.0;
    String recipientType = isPhoneNumber ? 'phone' : 'momo';
    final feeBreakdown = TariffService.getFeeBreakdown(
      amount: amount,
      recipientType: recipientType,
      serviceType: serviceType,
    );

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        bool applyFee = true; // Default to applying fee

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.dialpad_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(width: 12),
                  Text(
                    S.of(context).ussdCode,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                // This padding ensures the dialog content moves above the keyboard
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${S.of(context).paymentDetails}:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      S.of(context).amountRwfLabel(amountController.text),
                      style: theme.textTheme.bodyLarge,
                    ),
                    SizedBox(height: 12),
                    // Fee toggle switch
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  S.of(context).applyTransactionFee,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  applyFee
                                      ? S.of(context).feeWillBeAdded
                                      : S.of(context).noFeeApplied,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: applyFee,
                            onChanged: (value) {
                              setState(() {
                                applyFee = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    if (applyFee) ...[
                      Text(S.of(context).feeLabel(feeBreakdown['formattedFee']),
                          style: TextStyle(
                            color: theme.colorScheme.secondary,
                            fontSize: 14,
                          )),
                      Divider(height: 12, thickness: 1),
                      Text(
                          S
                              .of(context)
                              .totalLabel(feeBreakdown['formattedTotal']),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          )),
                      Text(
                          S
                              .of(context)
                              .tariffTypeLabel(feeBreakdown['tariffType']),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          )),
                      SizedBox(height: 8),
                    ],
                    if (selectedName != null && selectedName!.isNotEmpty)
                      Text(S.of(context).toRecipient(selectedName!)),
                    Text(isPhoneNumber
                        ? S
                            .of(context)
                            .phoneLabel(_maskPhoneNumber(paymentInfo))
                        : S.of(context).momoCodeLabel(paymentInfo.length > 3
                            ? paymentInfo.substring(0, 3) + "***"
                            : paymentInfo)),
                    SizedBox(height: 20),
                    Text(
                      S.of(context).dialUssdCode,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              ussdCode,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: ussdCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text(S.of(context).ussdCodeCopied)),
                              );
                            },
                            icon: Icon(Icons.copy_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Optional reason field with suggestions
                    FutureBuilder<List<String>>(
                      future: UssdRecordService.getUniqueReasons(),
                      builder: (context, snapshot) {
                        final options = snapshot.data ?? [];
                        return Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text == '') {
                              return const Iterable<String>.empty();
                            }
                            return options.where((String option) {
                              return option.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase());
                            });
                          },
                          onSelected: (String selection) {
                            reasonController.text = selection;
                          },
                          fieldViewBuilder: (context, controller, focusNode,
                              onFieldSubmitted) {
                            controller.text = reasonController.text;
                            controller.selection = TextSelection.fromPosition(
                                TextPosition(offset: controller.text.length));
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Reason (optional)',
                                hintText: S.of(context).reasonHint,
                                prefixIcon: Icon(Icons.note_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onChanged: (v) => reasonController.text = v,
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(S.of(context).close),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.phone_rounded),
                  label: Text(S.of(context).dial),
                  onPressed: () async {
                    Navigator.of(context).pop();

                    // Save the USSD record before dialing
                    String recipientType =
                        _isValidPhoneNumber(paymentInfo) ? 'phone' : 'momo';
                    double amount = double.tryParse(_getRawAmount()) ?? 0.0;
                    final reason = reasonController.text.trim().isEmpty
                        ? null
                        : reasonController.text.trim();

                    // Calculate fee only if applyFee is true
                    double? fee;
                    if (applyFee) {
                      fee = feeBreakdown['fee'] as double;
                    }

                    await _saveUssdRecord(ussdCode, paymentInfo, recipientType,
                        amount, reason, fee, applyFee);

                    launchUSSD(ussdCode, context);

                    // Reset the form for next payment
                    _resetForm();
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showRecordOnlyDialog(BuildContext context) async {
    final theme = Theme.of(context);
    String paymentInfo = mobileController.text.trim();

    // Calculate fee
    double amount = double.tryParse(_getRawAmount()) ?? 0.0;
    String recipientType;
    String? serviceType;

    if (paymentInfo.isEmpty) {
      recipientType = 'misc';
      serviceType = null;
    } else if (_isValidPhoneNumber(paymentInfo)) {
      recipientType = 'phone';
      String formattedPhone = _formatPhoneNumber(paymentInfo);
      serviceType = _getServiceType(formattedPhone);
    } else if (_isValidMomoCode(paymentInfo)) {
      recipientType = 'momo';
      serviceType = null;
    } else {
      recipientType = 'misc';
      serviceType = null;
    }

    final feeBreakdown = (recipientType != 'misc')
        ? TariffService.getFeeBreakdown(
            amount: amount,
            recipientType: recipientType,
            serviceType: serviceType,
          )
        : null;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        bool applyFee = false; // Default to no fee in record-only mode

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.save_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(width: 12),
                  Text(
                    S.of(context).savePaymentRecord,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${S.of(context).paymentDetails}:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      S.of(context).amountRwfLabel(amountController.text),
                      style: theme.textTheme.bodyLarge,
                    ),
                    SizedBox(height: 12),
                    // Fee toggle switch - always show
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  S.of(context).applyTransactionFee,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  feeBreakdown != null
                                      ? (applyFee
                                          ? S.of(context).feeWillBeAdded
                                          : S.of(context).noFeeApplied)
                                      : (applyFee
                                          ? S.of(context).feeTrackingEnabled
                                          : S.of(context).noFeeTracked),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: applyFee,
                            onChanged: (value) {
                              setState(() {
                                applyFee = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    if (feeBreakdown != null && applyFee) ...[
                      Text(
                        'Fee: ${feeBreakdown['formattedFee']}',
                        style: TextStyle(
                          color: theme.colorScheme.secondary,
                          fontSize: 14,
                        ),
                      ),
                      Divider(height: 12, thickness: 1),
                      Text(
                        'Total: ${feeBreakdown['formattedTotal']}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        'Tariff Type: ${feeBreakdown['tariffType']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      SizedBox(height: 8),
                    ],
                    if (selectedName != null && selectedName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          S.of(context).toRecipient(selectedName!),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    if (paymentInfo.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _isValidPhoneNumber(paymentInfo)
                              ? S
                                  .of(context)
                                  .phoneLabel(_maskPhoneNumber(paymentInfo))
                              : _isValidMomoCode(paymentInfo)
                                  ? S.of(context).momoCodeLabel(
                                      paymentInfo.length > 3
                                          ? paymentInfo.substring(0, 3) + "***"
                                          : paymentInfo)
                                  : S.of(context).recipientLabel(paymentInfo),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    if (paymentInfo.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          S.of(context).typeSidePayment,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Optional reason field with suggestions
                    FutureBuilder<List<String>>(
                      future: UssdRecordService.getUniqueReasons(),
                      builder: (context, snapshot) {
                        final options = snapshot.data ?? [];
                        return Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text == '') {
                              return const Iterable<String>.empty();
                            }
                            return options.where((String option) {
                              return option.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase());
                            });
                          },
                          onSelected: (String selection) {
                            reasonController.text = selection;
                          },
                          fieldViewBuilder: (context, controller, focusNode,
                              onFieldSubmitted) {
                            controller.text = reasonController.text;
                            controller.selection = TextSelection.fromPosition(
                                TextPosition(offset: controller.text.length));
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Reason (optional)',
                                hintText: S.of(context).reasonHint,
                                prefixIcon: Icon(Icons.note_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onChanged: (v) => reasonController.text = v,
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(S.of(context).cancel),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.save_rounded),
                  label: Text(S.of(context).saveRecord),
                  onPressed: () async {
                    Navigator.of(context).pop();

                    // Determine recipient type and value
                    String recipient;
                    String recipientType;

                    if (paymentInfo.isEmpty) {
                      // Side payment or no specific recipient
                      recipient = 'Side Payment';
                      recipientType = 'misc';
                    } else if (_isValidPhoneNumber(paymentInfo)) {
                      recipient = paymentInfo;
                      recipientType = 'phone';
                    } else if (_isValidMomoCode(paymentInfo)) {
                      recipient = paymentInfo;
                      recipientType = 'momo';
                    } else {
                      // Any other text input
                      recipient = paymentInfo;
                      recipientType = 'misc';
                    }

                    double amount = double.tryParse(_getRawAmount()) ?? 0.0;
                    final reason = reasonController.text.trim().isEmpty
                        ? null
                        : reasonController.text.trim();

                    // Calculate fee for valid transaction types (only if applyFee is true)
                    double? fee;
                    if (feeBreakdown != null && applyFee) {
                      fee = feeBreakdown['fee'] as double;
                    }

                    // Generate a placeholder USSD code for record-only mode
                    String ussdCode =
                        'RECORD-ONLY-${DateTime.now().millisecondsSinceEpoch}';

                    await _saveUssdRecord(ussdCode, recipient, recipientType,
                        amount, reason, fee, applyFee);

                    // Show success message
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(S.of(context).paymentRecordSaved),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }

                    // Reset the form for next payment
                    _resetForm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveUssdRecord(
      String ussdCode,
      String recipient,
      String recipientType,
      double amount,
      String? reason,
      double? fee,
      bool applyFee) async {
    final record = UssdRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ussdCode: ussdCode,
      recipient: recipient,
      recipientType: recipientType,
      amount: amount,
      timestamp: DateTime.now(),
      maskedRecipient:
          recipientType == 'phone' ? _maskPhoneNumber(recipient) : null,
      contactName: selectedName, // Save contact name if available
      reason: reason,
      fee: fee,
      applyFee: applyFee,
    );

    // Check if this is a record-only transaction (no actual USSD to dial)
    if (ussdCode.startsWith('RECORD-ONLY-')) {
      // Record-only transactions should be saved directly with success status
      // since there's no USSD response to validate
      await UssdRecordService.saveUssdRecord(
        record.copyWith(status: TransactionStatus.success),
      );
    } else {
      // For actual USSD transactions:
      // 1. Save to permanent storage immediately with pending status
      // 2. Also save to pending transaction manager for USSD validation
      // This ensures the transaction is persisted even if USSD validation fails
      await UssdRecordService.saveUssdRecord(record);
      await UssdTransactionManager.savePendingTransaction(record);
    }
  }

  /// Expands shorthand like "5k" → "5000", "2.5m" → "2500000".
  /// Returns the input unchanged if no shorthand suffix is detected.
  String _expandShorthand(String input) {
    final lower = input.toLowerCase().trim();
    if (lower.endsWith('k')) {
      final num = double.tryParse(lower.substring(0, lower.length - 1));
      if (num != null && num > 0) return (num * 1000).round().toString();
    } else if (lower.endsWith('m')) {
      final num = double.tryParse(lower.substring(0, lower.length - 1));
      if (num != null && num > 0) return (num * 1000000).round().toString();
    }
    return input;
  }

  String _getRawAmount() =>
      _expandShorthand(amountController.text.replaceAll(',', ''));

  String _formatAmountDisplay(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final n = int.tryParse(digits);
    if (n == null) return digits;
    return n.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => ',',
        );
  }

  bool _isValidAmount() {
    final raw = _getRawAmount();
    if (raw.isEmpty) return false;
    final amount = int.tryParse(raw);
    return amount != null && amount >= 1;
  }

  // Helper to get provider from phone number
  String _getProviderFromPhone(String phone) {
    final serviceType = _getServiceType(phone);
    return serviceType == '1' ? 'MTN' : 'Airtel';
  }

  // Generate QR code for payment request
  Future<void> _showQrCodeDialog(BuildContext context) async {
    if (!_isValidAmount()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).pleaseEnterValidAmount)),
      );
      return;
    }

    final theme = Theme.of(context);
    final amount = amountController.text;

    // Determine which payment method to include in QR
    String? selectedPaymentNumber;
    String? selectedPaymentType;

    if (paymentMethods.isEmpty) {
      // No payment methods - show manual entry dialog directly
      final manualMethod = await _showManualPaymentEntryDialog(context);
      if (manualMethod == null) {
        return; // User cancelled manual entry
      }
      selectedPaymentNumber = manualMethod.value;
      selectedPaymentType = manualMethod.type;
    } else {
      // Show dialog to select payment method (includes manual entry option)
      final selected = await _showPaymentMethodSelector(context);
      if (selected == null) {
        return; // User cancelled
      }
      if (selected is String && selected == 'manual_entry') {
        // Show manual entry dialog
        final manualMethod = await _showManualPaymentEntryDialog(context);
        if (manualMethod == null) {
          return; // User cancelled manual entry
        }
        selectedPaymentNumber = manualMethod.value;
        selectedPaymentType = manualMethod.type;
      } else if (selected is PaymentMethod) {
        selectedPaymentNumber = selected.value;
        selectedPaymentType = selected.type;
      }
    }

    // Create payment request data
    final paymentData = {
      'amount': amount,
      'type': 'payment_request',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      if (selectedPaymentNumber != null) 'recipient': selectedPaymentNumber,
      if (selectedPaymentType != null) 'recipientType': selectedPaymentType,
    };

    // Encode as JSON for QR code
    final qrData = jsonEncode(paymentData);

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.qr_code_2_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          S.of(context).paymentRequestQR,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 220.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.money_rounded,
                              color: theme.colorScheme.primary,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$amount RWF',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        if (selectedPaymentNumber != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                selectedPaymentType == 'mobile'
                                    ? Icons.phone_android_rounded
                                    : Icons.qr_code_rounded,
                                color: theme.colorScheme.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _maskPhoneNumber(selectedPaymentNumber),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          S.of(context).showQrToReceive,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selectedPaymentNumber != null
                        ? S.of(context).payerScanWithNumber
                        : S.of(context).payerScanQuick,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Load all contacts from device
  Future<void> _loadAllContacts({bool silent = false}) async {
    if (isLoadingContacts) return;

    setState(() {
      isLoadingContacts = true;
    });

    try {
      final status = await Permission.contacts.status;
      bool hasPermission = status.isGranted;

      // Only request permission if not yet granted (avoids repeated dialogs and
      // the "Reply already submitted" crash from FlutterPhoneDirectCaller)
      if (!hasPermission && status.isDenied) {
        hasPermission = await FlutterContacts.requestPermission();
      }

      if (hasPermission) {
        // Get all contacts with phone numbers
        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: false,
        );

        setState(() {
          allContacts = contacts;
          isLoadingContacts = false;
        });
      } else {
        setState(() {
          isLoadingContacts = false;
        });
        if (mounted && !silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).contactPermissionDenied)),
          );
        }
      }
    } catch (e) {
      setState(() {
        isLoadingContacts = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading contacts: $e')),
        );
      }
    }
  }

  void _onPhoneFocusChanged() {
    if (phoneFocusNode.hasFocus) _loadRecentCalls();
  }

  Future<void> _loadRecentCalls() async {
    if (_isLoadingRecentCalls ||
        _recentCallLog.isNotEmpty ||
        _recentCallPermissionDenied) return;
    setState(() => _isLoadingRecentCalls = true);
    try {
      final Iterable<CallLogEntry> entries = await CallLog.query();
      final Set<String> seen = {};
      final List<CallLogEntry> fresh = [];
      for (final e in entries) {
        final num = e.number ?? '';
        if (num.isEmpty) continue;
        if (e.callType != CallType.incoming && e.callType != CallType.missed)
          continue;
        final formatted = _formatPhoneNumber(num);
        if (formatted.isEmpty) continue;
        if (seen.contains(formatted)) continue;
        seen.add(formatted);
        fresh.add(e);
        if (fresh.length >= 10) break;
      }
      setState(() {
        _recentCallLog = fresh;
        _isLoadingRecentCalls = false;
      });
    } catch (_) {
      setState(() {
        _isLoadingRecentCalls = false;
        _recentCallPermissionDenied = true;
      });
    }
  }

  // Filter contacts and recent USSD records based on search query
  Future<void> _filterContacts(String query) async {
    if (query.isEmpty) {
      setState(() {
        filteredContacts = [];
      });
      return;
    }

    // Load contacts if not already loaded
    if (allContacts.isEmpty && !isLoadingContacts) {
      _loadAllContacts(silent: true);
    }

    final queryLower = query.toLowerCase();
    final queryDigits = query.replaceAll(RegExp(r'[^0-9]'), '');
    List<ContactSuggestion> suggestions = [];
    Set<String> addedKeys = {}; // Track added suggestions to avoid duplicates

    // First: suggest matching device contacts
    for (var contact in allContacts) {
      final displayName = contact.displayName;
      if (contact.phones.isNotEmpty) {
        for (var phone in contact.phones) {
          final phoneNumber = phone.number;
          if (phoneNumber.isEmpty) continue;
          final formatted = _formatPhoneNumber(phoneNumber);
          if (formatted.isEmpty) continue;

          final nameMatches = displayName.toLowerCase().contains(queryLower);
          final phoneMatches = queryDigits.isNotEmpty &&
              (phoneNumber.contains(queryDigits) ||
                  formatted.contains(queryDigits));

          final key = 'contact-${displayName}-$formatted';
          if ((nameMatches || phoneMatches) && !addedKeys.contains(key)) {
            suggestions.add(ContactSuggestion(
              name: displayName,
              phoneNumber: formatted,
              originalPhone: phoneNumber,
            ));
            addedKeys.add(key);
            if (suggestions.length >= 5) break;
          }
        }
        if (suggestions.length >= 5) break;
      }
    }

    // Second: include recent USSD records (most recent first) for momo codes or unsaved numbers
    try {
      final records = await UssdRecordService.getUssdRecords();
      for (var r in records.reversed) {
        if (suggestions.length >= 5) break;
        final recipient = r.recipient;
        final type = r.recipientType;

        // Decide a display name and phone/code to show
        String displayName;
        String showNumber;

        if (r.contactName != null && r.contactName!.trim().isNotEmpty) {
          displayName = r.contactName!;
        } else if (type == 'momo') {
          displayName = 'MoMo: $recipient';
        } else if (type == 'misc') {
          displayName = 'Code: $recipient';
        } else {
          displayName = r.maskedRecipient ?? recipient;
        }

        if (type == 'phone') {
          final formatted = _formatPhoneNumber(recipient);
          if (formatted.isEmpty) continue;
          showNumber = formatted;
        } else {
          showNumber = recipient;
        }

        // Match against query
        final matchesQuery =
            (queryDigits.isNotEmpty && showNumber.contains(queryDigits)) ||
                displayName.toLowerCase().contains(queryLower);
        final key = 'record-${type}-$recipient';
        if (matchesQuery && !addedKeys.contains(key)) {
          suggestions.add(ContactSuggestion(
            name: displayName,
            phoneNumber: showNumber,
            originalPhone: recipient,
          ));
          addedKeys.add(key);
        }
      }
    } catch (e) {
      // ignore errors reading records
    }

    // Third: include matching recent call log entries (incoming/missed callers)
    for (final e in _recentCallLog) {
      if (suggestions.length >= 5) break;
      final num = e.number ?? '';
      final formatted = _formatPhoneNumber(num);
      if (formatted.isEmpty) continue;
      final callerName =
          (e.name != null && e.name!.isNotEmpty) ? e.name! : formatted;
      final matchesQuery = (queryDigits.isNotEmpty &&
              (num.contains(queryDigits) || formatted.contains(queryDigits))) ||
          callerName.toLowerCase().contains(queryLower);
      final key = 'call-$formatted';
      if (matchesQuery && !addedKeys.contains(key)) {
        suggestions.add(ContactSuggestion(
          name: callerName,
          phoneNumber: formatted,
          originalPhone: num,
          isRecentCall: true,
        ));
        addedKeys.add(key);
      }
    }

    setState(() {
      filteredContacts = suggestions.take(5).toList();
    });
  }

  // Select a contact from suggestions
  void _selectContactSuggestion(ContactSuggestion suggestion) {
    setState(() {
      _selectedContact = suggestion;
      mobileController.text = suggestion.phoneNumber;
      selectedName = suggestion.name;
      filteredContacts = [];
      _suggestionDismissed = true;
    });
    if (_canProceedWithPayment()) {
      _processPayment(context);
    }
  }

  void _clearSelectedContact() {
    setState(() {
      _selectedContact = null;
      selectedName = null;
      mobileController.clear();
      filteredContacts = [];
      _suggestionDismissed = false;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      phoneFocusNode.requestFocus();
    });
  }

  bool _shouldShowSuggestionsOverlay() {
    if (_selectedContact != null) return false;
    if (_suggestionDismissed) return false;
    final phoneQuery = mobileController.text;
    if (filteredContacts.isNotEmpty) return true;
    if (phoneQuery.isEmpty && _recentCallLog.isNotEmpty) return true;
    if (phoneQuery.isNotEmpty &&
        (_isValidPhoneNumber(phoneQuery) || _isValidMomoCode(phoneQuery))) {
      return true;
    }
    return false;
  }

  Widget _buildSuggestionsOverlay(ThemeData theme) {
    final phoneQuery = mobileController.text;
    final bool hasExactMatch = filteredContacts.any(
      (c) => c.phoneNumber == phoneQuery || c.originalPhone == phoneQuery,
    );
    final bool showUnknown = phoneQuery.isNotEmpty &&
        (_isValidPhoneNumber(phoneQuery) || _isValidMomoCode(phoneQuery)) &&
        !hasExactMatch;

    return Positioned.fill(
      child: Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          child: Column(
            children: [
              // Header — live editable field so cursor/selection work
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => setState(() {
                      filteredContacts = [];
                      _suggestionDismissed = true;
                    }),
                  ),
                  Expanded(
                    child: TextField(
                      controller: mobileController,
                      focusNode: phoneFocusNode,
                      autofocus: true,
                      keyboardType: TextInputType.text,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: S.of(context).suggestions,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: (value) {
                        setState(() {
                          isPhoneNumberMomo = _isValidMomoCode(value) &&
                              !_isValidPhoneNumber(value);
                        });
                        _filterContacts(value);
                      },
                    ),
                  ),
                  if (mobileController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear_rounded,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5)),
                      onPressed: () => setState(() {
                        mobileController.clear();
                        filteredContacts = [];
                      }),
                    ),
                ],
              ),
              Divider(
                  height: 1,
                  color: theme.colorScheme.outline.withValues(alpha: 0.2)),
              // List
              Expanded(
                child: ListView(
                  children: [
                    // When no query typed, show recent incoming/missed callers
                    if (mobileController.text.isEmpty &&
                        _recentCallLog.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          'Recent incoming calls',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                              letterSpacing: 0.5),
                        ),
                      ),
                      ...List.generate(
                        _recentCallLog.where((e) => (e.number ?? '').isNotEmpty).take(5).length,
                        (i) {
                        final e = _recentCallLog.where((e) => (e.number ?? '').isNotEmpty).toList()[i];
                        final num = e.number!;
                        final formatted = _formatPhoneNumber(num);
                        final callerName =
                            (e.name != null && e.name!.isNotEmpty)
                                ? e.name!
                                : formatted;
                        final suggestion = ContactSuggestion(
                          name: callerName,
                          phoneNumber: formatted,
                          originalPhone: num,
                          isRecentCall: true,
                        );
                        final isFav = _favorites.any(
                            (f) => f.phoneNumber == suggestion.phoneNumber);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.tertiary
                                .withValues(alpha: 0.1),
                            child: Icon(Icons.call_received_rounded,
                                color: theme.colorScheme.tertiary, size: 20),
                          ),
                          title: Text(callerName,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          subtitle:
                              Text(formatted, style: theme.textTheme.bodySmall),
                          trailing: IconButton(
                            icon: Icon(
                              isFav
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: isFav
                                  ? Colors.amber
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                              size: 22,
                            ),
                            onPressed: () => _toggleFavorite(suggestion),
                          ),
                          onTap: () => _selectContactSuggestion(suggestion),
                        );
                      }),
                    ],
                    ...List.generate(filteredContacts.length, (index) {
                      final contact = filteredContacts[index];
                      final isFav = _favorites
                          .any((f) => f.phoneNumber == contact.phoneNumber);
                      return ListTile(
                        tileColor: index == 0
                            ? theme.colorScheme.primary.withValues(alpha: 0.1)
                            : null,
                        leading: CircleAvatar(
                          backgroundColor: contact.isRecentCall
                              ? theme.colorScheme.tertiary
                                  .withValues(alpha: 0.1)
                              : theme.colorScheme.primary
                                  .withValues(alpha: 0.1),
                          child: Icon(
                            contact.isRecentCall
                                ? Icons.call_received_rounded
                                : Icons.person,
                            color: contact.isRecentCall
                                ? theme.colorScheme.tertiary
                                : theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(contact.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: index == 0
                                    ? FontWeight.w700
                                    : FontWeight.w600)),
                        subtitle: Text(contact.phoneNumber,
                            style: theme.textTheme.bodySmall),
                        trailing: IconButton(
                          icon: Icon(
                            isFav
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: isFav
                                ? Colors.amber
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                            size: 22,
                          ),
                          onPressed: () => _toggleFavorite(contact),
                        ),
                        onTap: () => _selectContactSuggestion(contact),
                      );
                    }),
                    if (showUnknown)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.secondary
                              .withValues(alpha: 0.1),
                          child: Icon(Icons.phone_rounded,
                              color: theme.colorScheme.secondary, size: 20),
                        ),
                        title: Text(phoneQuery,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            _isValidPhoneNumber(phoneQuery)
                                ? S.of(context).phoneNumberLabel
                                : (phoneQuery.startsWith('0') &&
                                        phoneQuery
                                                .replaceAll(
                                                    RegExp(r'[^0-9]'), '')
                                                .length >
                                            10)
                                    ? S.of(context).probablyInvalidNumber
                                    : S.of(context).probablyMomoCode,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                        onTap: () {
                          setState(() {
                            mobileController.text = phoneQuery;
                            filteredContacts = [];
                            _suggestionDismissed = true;
                          });
                        },
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

  // Show payment method selector dialog
  Future<dynamic> _showPaymentMethodSelector(BuildContext context) async {
    final theme = Theme.of(context);

    return showDialog<dynamic>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                S.of(context).selectPaymentMethod,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.of(context).whichNumberReceive,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                ...paymentMethods.map((method) {
                  final isDefault = method.isDefault;
                  final icon = method.type == 'mobile'
                      ? Icons.phone_android_rounded
                      : Icons.qr_code_rounded;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 2,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(
                          icon,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        method.value,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${method.provider}${isDefault ? ' (Default)' : ''}',
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      onTap: () => Navigator.of(context).pop(method),
                    ),
                  );
                }).toList(),
                // Add manual entry option
                Card(
                  margin: const EdgeInsets.only(top: 8),
                  elevation: 2,
                  color:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.2),
                      child: Icon(
                        Icons.edit_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      S.of(context).enterManually,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    subtitle: Text(S.of(context).typeDifferentNumber),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    onTap: () {
                      // Return a special marker to indicate manual entry
                      Navigator.of(context).pop('manual_entry');
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(S.of(context).cancel),
            ),
          ],
        );
      },
    );
  }

  // Show manual payment entry dialog
  Future<PaymentMethod?> _showManualPaymentEntryDialog(
      BuildContext context) async {
    final theme = Theme.of(context);
    final manualController = TextEditingController();
    bool isPhoneDetected = false;
    bool isMomoDetected = false;

    return showDialog<PaymentMethod>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.edit_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(S.of(context).enterPaymentNumber),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context).enterPhoneOrMomoDesc,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: manualController,
                      keyboardType: TextInputType.text,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: S.of(context).phoneOrMomo,
                        hintText: S.of(context).phoneOrMomoExample,
                        prefixIcon: Icon(Icons.phone_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        helperText: manualController.text.isEmpty
                            ? S.of(context).phoneOrMomoExample
                            : (isPhoneDetected
                                ? S.of(context).phoneFormatDetected
                                : isMomoDetected
                                    ? S.of(context).momoFormatDetected
                                    : S.of(context).enterValidPhoneOrMomo),
                      ),
                      onChanged: (value) {
                        setState(() {
                          isPhoneDetected = _isValidPhoneNumber(value);
                          isMomoDetected =
                              _isValidMomoCode(value) && !isPhoneDetected;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (manualController.text.isNotEmpty &&
                        !isPhoneDetected &&
                        !isMomoDetected)
                      Text(
                        'Please enter a valid phone number (078xxxxxxx) or momo code',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 14,
                        ),
                      ),
                    if (isPhoneDetected || isMomoDetected)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPhoneDetected
                                  ? Icons.phone_rounded
                                  : Icons.qr_code_rounded,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isPhoneDetected
                                    ? S.of(context).validPhoneDetected
                                    : S.of(context).validMomoDetected,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(S.of(context).cancel),
                ),
                ElevatedButton(
                  onPressed: (isPhoneDetected || isMomoDetected)
                      ? () {
                          final value = manualController.text.trim();
                          final selectedType =
                              isPhoneDetected ? 'mobile' : 'momo';

                          // Create a temporary PaymentMethod object
                          final method = PaymentMethod(
                            id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                            type: selectedType,
                            value: value,
                            provider: selectedType == 'mobile'
                                ? _getProviderFromPhone(value)
                                : 'MoMo',
                            isDefault: false,
                          );

                          Navigator.of(context).pop(method);
                        }
                      : null,
                  child: Text(S.of(context).useThisNumber),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Helper class for contact suggestions
class ContactSuggestion {
  final String name;
  final String phoneNumber;
  final String originalPhone;
  final bool isRecentCall;

  ContactSuggestion({
    required this.name,
    required this.phoneNumber,
    required this.originalPhone,
    this.isRecentCall = false,
  });
}
