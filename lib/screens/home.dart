import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../generated/l10n.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart' as picker;
import 'package:flutter_contacts/flutter_contacts.dart';
import '../helpers/launcher.dart';
import '../helpers/app_theme.dart';
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
import '../widgets/scroll_indicator.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController reasonController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController recipientNameController = TextEditingController();
  final TextEditingController manualMobileController = TextEditingController();
  final TextEditingController momoCodeController = TextEditingController();
  final FlutterNativeContactPicker _contactPicker =
      FlutterNativeContactPicker();
  final FocusNode amountFocusNode = FocusNode();
  final FocusNode phoneFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String? selectedNumber;
  String? selectedName;
  bool showManualInput = true;

  // Multistep form variables
  int currentStep = 0;
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

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
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

      // Focus on phone number field when moving to step 2
      if (currentStep == 1) {
        Future.delayed(const Duration(milliseconds: 350), () {
          phoneFocusNode.requestFocus();

          // Scroll to ensure the input field is visible when keyboard appears
          Future.delayed(const Duration(milliseconds: 300), () {
            if (context.mounted) {
              Scrollable.ensureVisible(
                phoneFocusNode.context!,
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

      // Focus on amount field when going back to step 1
      if (currentStep == 0) {
        Future.delayed(const Duration(milliseconds: 350), () {
          amountFocusNode.requestFocus();
        });
      }
    }
  }

  void _resetForm() {
    setState(() {
      currentStep = 0;
      amountController.clear();
      mobileController.clear();
      recipientNameController.clear();
      reasonController.clear();
      isPhoneNumberMomo = false;
      isRecordOnlyMode = false; // Reset to Dial Now mode
      selectedName = null;
      filteredContacts = [];
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
    recipientNameController.dispose();
    manualMobileController.dispose();
    momoCodeController.dispose();
    amountFocusNode.dispose();
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
            currentStep = 1; // Move to recipient step
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
          currentStep = 1;
        });

        // Focus on amount field for next input
        WidgetsBinding.instance.addPostFrameCallback((_) {
          phoneFocusNode.requestFocus();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scanned: $result'),
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
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: ScrollIndicatorWrapper(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 20 +
                  keyboardHeight *
                      0.1, // Add small padding when keyboard is open
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Title
                _buildAppHeader(context, theme),
                const SizedBox(height: 30),

                // Quick Actions (Scan QR & Load Contact)
                _buildQuickActions(context, theme),
                const SizedBox(height: 30),

                // Streamlined Payment Form
                _buildStreamlinedPaymentForm(context, theme),

                // Add extra space when keyboard is visible
                if (keyboardHeight > 0) SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppHeader(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MQ Pay',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              'Quick Payment',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        Row(
          children: [
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
                // Reload payment methods after returning from settings
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

  Widget _buildStreamlinedPaymentForm(BuildContext context, ThemeData theme) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;

    return Container(
      constraints: BoxConstraints(maxWidth: 400),
      width: double.infinity,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: EdgeInsets.all(isKeyboardOpen ? 20 : 30),
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
                                Text(
                                  'Send Money',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: !isReceiveMode
                                        ? Colors.white
                                        : theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5),
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
                                Text(
                                  'Get Paid',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isReceiveMode
                                        ? Colors.white
                                        : theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5),
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
                    Text(
                      'Send Money',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Step ${currentStep + 1} of 2',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ] else ...[
                Text(
                  'Generate Payment QR',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a QR code for someone to pay you',
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
                // Send Mode - Full 2-step flow
                // Step Progress Indicator
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: currentStep >= 1
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline
                                  .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Step Content
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: currentStep == 0
                      ? _buildAmountStep(theme)
                      : _buildPhoneStep(theme),
                ),

                const SizedBox(height: 30),

                // Navigation Buttons
                Row(
                  children: [
                    if (currentStep > 0)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _previousStep,
                          icon: Icon(Icons.arrow_back_rounded),
                          label: Text('Back'),
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
                              ? 'Next'
                              : (isRecordOnlyMode ? 'Save Record' : 'Pay Now'),
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
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            labelText: 'Amount (RWF)',
            hintText: 'Enter amount...',
            prefixIcon: Icon(Icons.attach_money_rounded),
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
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 20,
            ),
          ),
          onChanged: (value) => setState(() {}),
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
            'Generate QR Code',
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
                  'Enter the amount you want to receive, then generate a QR code to show the payer',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter Amount',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'How much do you want to send?',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 24),

        // NEW: Card-based payment mode selector
        _buildPaymentModeSelector(theme),

        const SizedBox(height: 24),
        TextField(
          controller: amountController,
          focusNode: amountFocusNode,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            labelText: 'Amount (RWF)',
            hintText: 'Enter amount...',
            prefixIcon: Icon(Icons.attach_money_rounded),
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
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 20,
            ),
          ),
          onChanged: (value) => setState(() {}),
          onSubmitted: (value) {
            if (_isValidAmount()) {
              _nextStep();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recipient Information',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isRecordOnlyMode
              ? 'Enter recipient details (optional for side payments)'
              : 'Enter phone number or momo code',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 24),
        Column(
          children: [
            // Contact suggestions dropdown
            if (filteredContacts.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredContacts.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  itemBuilder: (context, index) {
                    final contact = filteredContacts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.person,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        contact.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        contact.phoneNumber,
                        style: theme.textTheme.bodySmall,
                      ),
                      onTap: () => _selectContactSuggestion(contact),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    );
                  },
                ),
              ),
            // Name field (optional)
            TextField(
              controller: recipientNameController,
              keyboardType: TextInputType.text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: 'Recipient Name (Optional)',
                hintText: 'Enter name for this recipient',
                prefixIcon: Icon(Icons.person_rounded),
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
                // Update selectedName when user types in the name field
                setState(() {
                  selectedName = value.trim().isEmpty ? null : value.trim();
                });
                // Also filter contacts based on name
                _filterContacts(value);
              },
            ),
            const SizedBox(height: 16),
            // Phone number or momo code field
            TextField(
              controller: mobileController,
              focusNode: phoneFocusNode,
              keyboardType: TextInputType.text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: isRecordOnlyMode
                    ? 'Phone Number or Momo Code (Optional)'
                    : 'Phone Number or Momo Code',
                hintText: isRecordOnlyMode
                    ? 'Optional - leave blank for side payments'
                    : 'Type name, phone or momo code',
                prefixIcon: Icon(Icons.phone_rounded),
                suffixIcon: isLoadingContacts
                    ? Padding(
                        padding: const EdgeInsets.all(12.0),
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
                            onPressed: () {
                              setState(() {
                                mobileController.clear();
                                filteredContacts = [];
                                selectedName = null;
                                recipientNameController
                                    .clear(); // Also clear name field
                              });
                            },
                            tooltip: 'Clear',
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
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                helperText: _getInputHelperText(),
              ),
              onChanged: (value) {
                setState(() {
                  isPhoneNumberMomo =
                      _isValidMomoCode(value) && !_isValidPhoneNumber(value);
                });

                // Filter contacts for autocomplete
                _filterContacts(value);
              },
              onSubmitted: (value) {
                if (_canProceedWithPayment()) {
                  _processPayment(context);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (mobileController.text.isNotEmpty &&
            !_isValidPhoneNumber(mobileController.text) &&
            !_isValidMomoCode(mobileController.text))
          Text(
            'Please enter a valid phone number (078xxxxxxx) or momo code',
            style: TextStyle(
              color: theme.colorScheme.error,
              fontSize: 14,
            ),
          ),
        if (mobileController.text.isNotEmpty &&
            (_isValidPhoneNumber(mobileController.text) ||
                _isValidMomoCode(mobileController.text)))
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _isValidPhoneNumber(mobileController.text)
                      ? Icons.phone_rounded
                      : Icons.qr_code_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isValidPhoneNumber(mobileController.text)
                        ? 'Valid phone number detected'
                        : 'Valid momo code detected',
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
    );
  }

  String _getInputHelperText() {
    if (mobileController.text.isEmpty) {
      return 'Phone: 078xxxxxxx or Momo: 123456';
    } else if (_isValidPhoneNumber(mobileController.text)) {
      return 'Phone number format detected';
    } else if (_isValidMomoCode(mobileController.text)) {
      return 'Momo code format detected';
    } else {
      return 'Enter valid phone number or momo code';
    }
  }

  VoidCallback? _getNextButtonAction() {
    if (currentStep == 0) {
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
    // Update selectedName with the value from the name field if provided
    if (recipientNameController.text.trim().isNotEmpty) {
      selectedName = recipientNameController.text.trim();
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
      ussdCode =
          '*182*1*$serviceType*$formattedPhone*${amountController.text}#';
    } else if (_isValidMomoCode(input)) {
      // Process as momo code
      ussdCode = '*182*8*1*$input*${amountController.text}#';
      serviceType = null; // MoMo codes don't have service type
    } else {
      // Should not reach here due to validation, but handle gracefully
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid phone number or momo code')),
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
    double amount = double.tryParse(amountController.text) ?? 0.0;
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
                    'USSD Code',
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
                      'Payment Details:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Amount: ${amountController.text} RWF',
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
                                  'Apply Transaction Fee',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  applyFee
                                      ? 'Fee will be added to total'
                                      : 'No fee will be applied',
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
                      Text('Fee: ${feeBreakdown['formattedFee']}',
                          style: TextStyle(
                            color: theme.colorScheme.secondary,
                            fontSize: 14,
                          )),
                      Divider(height: 12, thickness: 1),
                      Text('Total: ${feeBreakdown['formattedTotal']}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          )),
                      Text('Tariff Type: ${feeBreakdown['tariffType']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          )),
                      SizedBox(height: 8),
                    ],
                    if (selectedName != null && selectedName!.isNotEmpty)
                      Text('To: $selectedName'),
                    Text(isPhoneNumber
                        ? 'Phone: ${_maskPhoneNumber(paymentInfo)}'
                        : 'Momo Code: ${paymentInfo.length > 3 ? paymentInfo.substring(0, 3) + "***" : paymentInfo}'),
                    SizedBox(height: 20),
                    Text(
                      'Dial this USSD code:',
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
                              // Copy to clipboard functionality can be added here
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('USSD code copied!')),
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
                                hintText: 'Why are you sending this money?',
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
                  child: Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.phone_rounded),
                  label: Text('Dial'),
                  onPressed: () async {
                    Navigator.of(context).pop();

                    // Save the USSD record before dialing
                    String recipientType =
                        _isValidPhoneNumber(paymentInfo) ? 'phone' : 'momo';
                    double amount =
                        double.tryParse(amountController.text) ?? 0.0;
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
    double amount = double.tryParse(amountController.text) ?? 0.0;
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
                    Icons.save_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Save Payment Record',
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
                      'Payment Details:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Amount: ${amountController.text} RWF',
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
                                  'Apply Transaction Fee',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  feeBreakdown != null
                                      ? (applyFee
                                          ? 'Fee will be added to total'
                                          : 'No fee will be applied')
                                      : (applyFee
                                          ? 'Fee tracking enabled (no fee calculated for this type)'
                                          : 'No fee will be tracked'),
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
                          'To: $selectedName',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    if (paymentInfo.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _isValidPhoneNumber(paymentInfo)
                              ? 'Phone: ${_maskPhoneNumber(paymentInfo)}'
                              : _isValidMomoCode(paymentInfo)
                                  ? 'Momo Code: ${paymentInfo.length > 3 ? paymentInfo.substring(0, 3) + "***" : paymentInfo}'
                                  : 'Recipient: $paymentInfo',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    if (paymentInfo.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Type: Side Payment',
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
                                hintText: 'Why was this payment made?',
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
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.save_rounded),
                  label: Text('Save Record'),
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

                    double amount =
                        double.tryParse(amountController.text) ?? 0.0;
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
                          content: Text('Payment record saved successfully!'),
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

  bool _isValidAmount() {
    if (amountController.text.isEmpty) return false;
    final amount = int.tryParse(amountController.text);
    return amount != null && amount >= 1; // Minimum 1 RWF for testing
  }

  Widget _buildQuickActions(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            context: context,
            theme: theme,
            icon: Icons.qr_code_scanner_rounded,
            title: S.of(context).scanNow,
            onTap: _scanQrCode,
            gradient: AppTheme.secondaryGradient,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            context: context,
            theme: theme,
            icon: Icons.contacts_rounded,
            title: 'Contact',
            onTap: _loadContact,
            gradient: LinearGradient(
              colors: [
                AppTheme.warningColor,
                AppTheme.warningColor.withValues(alpha: 0.8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Gradient gradient,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadContact() async {
    try {
      picker.Contact? contact = await _contactPicker.selectContact();
      if (contact != null) {
        List<String>? phoneNumbers = contact.phoneNumbers;
        selectedNumber = phoneNumbers?.first;
        if (selectedNumber != null) {
          if (_isValidPhoneNumber(selectedNumber!) ||
              _isValidMomoCode(selectedNumber!)) {
            String formattedNumber = _formatPhoneNumber(selectedNumber!);
            setState(() {
              // Set the phone number in the multistep form
              mobileController.text = formattedNumber;
              // If we're on step 1, advance to step 2
              if (currentStep == 0) {
                currentStep = 1;
              }
            });
            // Focus on the phone field in step 2
            Future.delayed(const Duration(milliseconds: 100), () {
              phoneFocusNode.requestFocus();
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Contact loaded: ${formattedNumber}'),
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            _showErrorDialog(
              context: context,
              title: 'Invalid Phone Number',
              message:
                  'The selected contact has an invalid phone number format. Please select a contact with a valid Rwanda phone number.',
            );
          }
        }
      }
    } catch (e) {
      _showErrorDialog(
        context: context,
        title: 'Error',
        message: 'Failed to load contact: $e',
      );
    }
  }

  void _showErrorDialog({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
        const SnackBar(content: Text('Please enter a valid amount first')),
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
                          'Payment Request QR',
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
                          'Show this QR code to receive payment',
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
                        ? 'The payer can scan this code to pay you the exact amount at the specified number'
                        : 'The payer can scan this code to quickly pay you the exact amount',
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
  Future<void> _loadAllContacts() async {
    if (isLoadingContacts) return;

    setState(() {
      isLoadingContacts = true;
    });

    try {
      // Request permission
      if (await FlutterContacts.requestPermission()) {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact permission denied')),
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
      _loadAllContacts();
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

    setState(() {
      filteredContacts = suggestions.take(5).toList();
    });
  }

  // Select a contact from suggestions
  void _selectContactSuggestion(ContactSuggestion suggestion) {
    setState(() {
      mobileController.text = suggestion.phoneNumber;
      recipientNameController.text = suggestion.name;
      filteredContacts = [];
      selectedName = suggestion.name;
    });
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
                'Select Payment Method',
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
                  'Which number should receive the payment?',
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
                      'Enter manually',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    subtitle: const Text('Type a different number'),
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
              child: const Text('Cancel'),
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
                  const Text('Enter Payment Number'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter the phone number or momo code to receive payment',
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
                        labelText: 'Phone Number or Momo Code',
                        hintText: 'Phone: 078xxxxxxx or Momo: 123456',
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
                            ? 'Phone: 078xxxxxxx or Momo: 123456'
                            : (isPhoneDetected
                                ? 'Phone number format detected'
                                : isMomoDetected
                                    ? 'Momo code format detected'
                                    : 'Enter valid phone number or momo code'),
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
                                    ? 'Valid phone number detected'
                                    : 'Valid momo code detected',
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
                  child: const Text('Cancel'),
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
                  child: const Text('Use This Number'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Enhanced payment mode toggle with subtle improvements
  Widget _buildPaymentModeSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  'Record Only',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Record Only Mode'),
                        content: const Text(
                          'When enabled, transactions are saved as records without executing the payment. This is useful for tracking side payments or manually handled transactions.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isRecordOnlyMode,
            onChanged: (value) {
              setState(() => isRecordOnlyMode = value);
            },
          ),
        ],
      ),
    );
  }
}

// Helper class for contact suggestions
class ContactSuggestion {
  final String name;
  final String phoneNumber;
  final String originalPhone;

  ContactSuggestion({
    required this.name,
    required this.phoneNumber,
    required this.originalPhone,
  });
}
