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
import '../services/ussd_record_service.dart';
import 'dart:convert';

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
      isPhoneNumberMomo = false;
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

      // Check if scanned data is a phone number or momo code pattern
      if (_isValidPhoneNumber(result) || _isValidMomoCode(result)) {
        // Populate the mobile field and advance to step 2
        setState(() {
          mobileController.text = result;
          currentStep = 2;
        });

        // Focus on amount field for next input
        WidgetsBinding.instance.addPostFrameCallback((_) {
          amountFocusNode.requestFocus();
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
      backgroundColor: theme.colorScheme.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 +
                keyboardHeight * 0.1, // Add small padding when keyboard is open
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
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => SettingsPage(
                          initialMobile: mobileNumber,
                          initialMomoCode: momoCode,
                          selectedLanguage: selectedLanguage ?? 'en',
                        )),
              ),
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
              // Form Title with Step Indicator
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Step Content (without fixed height)
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
                          : Icons.send_rounded),
                      label: Text(
                        currentStep == 0 ? 'Next' : 'Pay Now',
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
          ),
        ),
      ),
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
          'Enter phone number or momo code',
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
            TextField(
              controller: mobileController,
              focusNode: phoneFocusNode,
              keyboardType: TextInputType.text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: 'Phone Number or Momo Code',
                hintText: 'Type name or 078xxxxxxx',
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
    return _isValidAmount() &&
        mobileController.text.isNotEmpty &&
        (_isValidPhoneNumber(mobileController.text) ||
            _isValidMomoCode(mobileController.text));
  }

  void _processPayment(BuildContext context) {
    String input = mobileController.text.trim();
    String ussdCode;

    // Determine if input is phone number or momo code
    if (_isValidPhoneNumber(input)) {
      // Process as phone number
      String formattedPhone = _formatPhoneNumber(input);
      String serviceType = _getServiceType(formattedPhone);
      ussdCode =
          '*182*1*$serviceType*$formattedPhone*${amountController.text}#';
    } else if (_isValidMomoCode(input)) {
      // Process as momo code
      ussdCode = '*182*8*1*$input*${amountController.text}#';
    } else {
      // Should not reach here due to validation, but handle gracefully
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid phone number or momo code')),
      );
      return;
    }

    // Show the USSD code in a dialog
    _showUssdDialog(context, ussdCode, input);
  }

  Future<void> _showUssdDialog(
      BuildContext context, String ussdCode, String paymentInfo) async {
    final theme = Theme.of(context);
    bool isPhoneNumber = _isValidPhoneNumber(paymentInfo);

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
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
                Text('Amount: ${amountController.text} RWF'),
                Text(isPhoneNumber
                    ? 'To: ${_maskPhoneNumber(paymentInfo)}'
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
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
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
                // Optional reason field
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: 'Reason (optional)',
                    hintText: 'Why are you sending this money?',
                    prefixIcon: Icon(Icons.note_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
                // Reset the form for next payment
                _resetForm();
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
                double amount = double.tryParse(amountController.text) ?? 0.0;
                final reason = reasonController.text.trim().isEmpty
                    ? null
                    : reasonController.text.trim();

                await _saveUssdRecord(
                    ussdCode, paymentInfo, recipientType, amount, reason);

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
  }

  Widget _buildQuickActions(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context: context,
                theme: theme,
                icon: Icons.qr_code_scanner_rounded,
                title: S.of(context).scanNow,
                subtitle: 'Scan QR codes',
                onTap: _scanQrCode,
                gradient: AppTheme.secondaryGradient,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                context: context,
                theme: theme,
                icon: Icons.contacts_rounded,
                title: 'Contact',
                subtitle: 'Select contact',
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
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Gradient gradient,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  bool _isValidAmount() {
    if (amountController.text.isEmpty) return false;
    final amount = int.tryParse(amountController.text);
    return amount != null && amount >= 1; // Minimum 1 RWF for testing
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

  Future<void> _saveUssdRecord(String ussdCode, String recipient,
      String recipientType, double amount, String? reason) async {
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
    );

    await UssdRecordService.saveUssdRecord(record);
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

  // Filter contacts based on search query (supports both name and phone number search)
  void _filterContacts(String query) {
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
    // Remove spaces and special characters from query for phone number matching
    final queryDigits = query.replaceAll(RegExp(r'[^0-9]'), '');
    List<ContactSuggestion> suggestions = [];
    Set<String> addedContacts = {}; // Track added contacts to avoid duplicates

    for (var contact in allContacts) {
      String displayName = contact.displayName;

      // Get phone numbers
      if (contact.phones.isNotEmpty) {
        for (var phone in contact.phones) {
          String phoneNumber = phone.number;
          if (phoneNumber.isNotEmpty) {
            // Format and validate phone number
            String formatted = _formatPhoneNumber(phoneNumber);
            if (formatted.isNotEmpty) {
              // Check if name matches OR phone number matches
              bool nameMatches = displayName.toLowerCase().contains(queryLower);
              bool phoneMatches = queryDigits.isNotEmpty &&
                  (phoneNumber.contains(queryDigits) ||
                      formatted.contains(queryDigits));

              // Create unique key to prevent duplicates
              String uniqueKey = '$displayName-$formatted';

              if ((nameMatches || phoneMatches) &&
                  !addedContacts.contains(uniqueKey)) {
                suggestions.add(ContactSuggestion(
                  name: displayName,
                  phoneNumber: formatted,
                  originalPhone: phoneNumber,
                ));
                addedContacts.add(uniqueKey);
              }
            }
          }
        }
      }
    }

    setState(() {
      filteredContacts = suggestions.take(5).toList(); // Limit to 5 suggestions
    });
  }

  // Select a contact from suggestions
  void _selectContactSuggestion(ContactSuggestion suggestion) {
    setState(() {
      mobileController.text = suggestion.phoneNumber;
      filteredContacts = [];
      selectedName = suggestion.name;
    });
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
