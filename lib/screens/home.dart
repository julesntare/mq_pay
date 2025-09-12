import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../generated/l10n.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import '../helpers/launcher.dart';
import '../helpers/app_theme.dart';
import 'settings.dart';
import 'qr_scanner_screen.dart';
import 'dart:convert';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController manualMobileController = TextEditingController();
  final TextEditingController momoCodeController = TextEditingController();
  final FlutterNativeContactPicker _contactPicker =
      FlutterNativeContactPicker();
  final FocusNode amountFocusNode = FocusNode();
  final FocusNode phoneFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _qrCodeKey = GlobalKey();
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

  String _maskUssdCode(String ussdCode) {
    // Pattern: *182*1*serviceType*phoneNumber*amount#
    RegExp ussdPattern = RegExp(r'\*182\*(\d+)\*(\d+)\*(\d+)\*(\d+)#');
    Match? match = ussdPattern.firstMatch(ussdCode);

    if (match != null) {
      String prefix = match.group(1)!; // 1
      String serviceType = match.group(2)!; // serviceType
      String phoneNumber = match.group(3)!; // phoneNumber
      String amount = match.group(4)!; // amount

      String maskedPhone = _maskPhoneNumber(phoneNumber);
      return '*182*$prefix*$serviceType*$maskedPhone*$amount#';
    }

    return ussdCode; // Return original if pattern doesn't match
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

  void _generateQrCode(String type) {
    final amount = amountController.text.trim();
    if (amount.isEmpty ||
        int.tryParse(amount) == null ||
        int.parse(amount) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).invalidAmount)),
      );
      return;
    }

    String ussdCode;
    if (type == 'Mobile Number') {
      String serviceType = _getServiceType(mobileNumber);
      ussdCode = '*182*1*$serviceType*$mobileNumber*$amount#';
    } else if (type == 'Momo Code') {
      ussdCode = '*182*8*1*$momoCode*$amount#';
    } else {
      return;
    }

    setState(() {
      generatedUssdCode = ussdCode;
      showQrCode = true;
    });
  }

  void _generateQrCodeForReceiving() {
    final amount = amountController.text.trim();

    if (amount.isEmpty ||
        int.tryParse(amount) == null ||
        int.parse(amount) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).invalidAmount)),
      );
      return;
    }

    // Check if user has payment details set up
    if (paymentMethods.isEmpty && mobileNumber.isEmpty && momoCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set up your payment details in Settings first'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    String ussdCode;

    if (selectedPaymentMethod == 'auto') {
      // Auto-select: use default payment method if available, otherwise use first available
      PaymentMethod? defaultMethod = paymentMethods.isNotEmpty
          ? paymentMethods.firstWhere((m) => m.isDefault,
              orElse: () => paymentMethods.first)
          : null;

      if (defaultMethod != null) {
        ussdCode = _generateUssdForPaymentMethod(defaultMethod, amount);
      } else if (mobileNumber.isNotEmpty) {
        // Fallback to old mobile number
        String serviceType = _getServiceType(mobileNumber);
        ussdCode = '*182*1*$serviceType*$mobileNumber*$amount#';
      } else {
        // Fallback to old momo code
        ussdCode = '*182*8*1*$momoCode*$amount#';
      }
    } else {
      // User selected a specific payment method
      PaymentMethod? selectedMethod = paymentMethods.firstWhere(
        (method) => method.id == selectedPaymentMethod,
        orElse: () => PaymentMethod(id: '', type: '', value: '', provider: ''),
      );

      if (selectedMethod.id.isNotEmpty) {
        ussdCode = _generateUssdForPaymentMethod(selectedMethod, amount);
      } else if (selectedPaymentMethod == 'mobile' && mobileNumber.isNotEmpty) {
        // Fallback to old mobile method
        String serviceType = _getServiceType(mobileNumber);
        ussdCode = '*182*1*$serviceType*$mobileNumber*$amount#';
      } else if (selectedPaymentMethod == 'momo' && momoCode.isNotEmpty) {
        // Fallback to old momo method
        ussdCode = '*182*8*1*$momoCode*$amount#';
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected payment method is not available'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    setState(() {
      generatedUssdCode = ussdCode;
      showQrCode = true;
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR Code generated! Others can scan it to pay you.'),
        duration: Duration(seconds: 2),
      ),
    );

    // Auto-scroll to QR code after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      _scrollToQrCode();
    });
  }

  String _generateUssdForPaymentMethod(PaymentMethod method, String amount) {
    if (method.type == 'mobile') {
      String serviceType = _getServiceType(method.value);
      return '*182*1*$serviceType*${method.value}*$amount#';
    } else {
      // momo type
      return '*182*8*1*${method.value}*$amount#';
    }
  }

  void _scrollToQrCode() {
    if (_qrCodeKey.currentContext != null) {
      Scrollable.ensureVisible(
        _qrCodeKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _generateQrCodeForManualPayment() {
    final amount = amountController.text.trim();
    final mobileNumber = manualMobileController.text.trim();

    if (amount.isEmpty ||
        int.tryParse(amount) == null ||
        int.parse(amount) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).invalidAmount)),
      );
      return;
    }

    if (mobileNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a mobile number')),
      );
      return;
    }

    String serviceType = _getServiceType(mobileNumber);
    String ussdCode = '*182*1*$serviceType*$mobileNumber*$amount#';

    setState(() {
      generatedUssdCode = ussdCode;
      showQrCode = true;
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR Code generated! Scroll down to see it.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showPhoneNumberDialog(BuildContext context) async {
    final theme = Theme.of(context);
    TextEditingController phoneController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.phone_rounded,
                color: theme.colorScheme.primary,
              ),
              SizedBox(width: 12),
              Text(
                'Enter Phone Number',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Amount: ${amountController.text} RWF',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Enter recipient\'s phone number or momo code',
                  prefixIcon: Icon(Icons.phone_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  helperText: 'Phone: 078xxxxxxx or Momo: 123456',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: theme.colorScheme.error,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.send_rounded),
              label: Text('Proceed'),
              onPressed: () {
                if (phoneController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a phone number')),
                  );
                  return;
                }

                if (!_isValidPhoneNumber(phoneController.text) &&
                    !_isValidMomoCode(phoneController.text)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Please enter a valid phone number or momo code')),
                  );
                  return;
                }

                Navigator.of(context).pop();

                // Process the payment
                String input = phoneController.text;
                String ussdCode;

                if (_isValidPhoneNumber(input)) {
                  String formattedPhone = _formatPhoneNumber(input);
                  String serviceType = _getServiceType(formattedPhone);
                  ussdCode =
                      '*182*1*$serviceType*$formattedPhone*${amountController.text}#';
                } else {
                  // Must be momo code since validation passed
                  ussdCode = '*182*8*1*$input*${amountController.text}#';
                }

                // Launch USSD or show QR code
                _showPaymentOptions(context, ussdCode, input);
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

  Future<void> _showPaymentOptions(
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
                Icons.payment_rounded,
                color: theme.colorScheme.primary,
              ),
              SizedBox(width: 12),
              Text(
                'Payment Options',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Payment Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('Amount: ${amountController.text} RWF'),
                    Text(isPhoneNumber
                        ? 'To: ${_maskPhoneNumber(paymentInfo)}'
                        : 'Momo Code: ${paymentInfo.length > 3 ? paymentInfo.substring(0, 3) + "***" : paymentInfo}'),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Choose how you want to proceed:',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.phone_rounded),
              label: Text('Dial USSD'),
              onPressed: () {
                Navigator.of(context).pop();
                launchUSSD(ussdCode, context);
                // Clear form after successful operation
                setState(() {
                  amountController.clear();
                });
              },
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.qr_code_rounded),
              label: Text('Show QR'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  generatedUssdCode = ussdCode;
                  showQrCode = true;
                });
              },
            ),
          ],
        );
      },
    );
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
              const SizedBox(height: 40),

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
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
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
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            size: 28,
          ),
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
                      color: theme.colorScheme.primary.withOpacity(0.1),
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
                            : theme.colorScheme.outline.withOpacity(0.3),
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
                            theme.colorScheme.onSurface.withOpacity(0.12),
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
            color: theme.colorScheme.onSurface.withOpacity(0.7),
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
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 24),
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
            hintText: '078xxxxxxx or 123456',
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
          },
          onSubmitted: (value) {
            if (_canProceedWithPayment()) {
              _processPayment(context);
            }
          },
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
              color: theme.colorScheme.primary.withOpacity(0.1),
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
          content: Column(
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
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
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
            ],
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
              onPressed: () {
                Navigator.of(context).pop();
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

  Widget _buildWelcomeSection(BuildContext context, ThemeData theme) {
    return GradientCard(
      gradient: AppTheme.primaryGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context).welcomeHere,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      S.of(context).shortDesc,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInputSection(BuildContext context, ThemeData theme) {
    return GradientCard(
      gradient: LinearGradient(
        colors: [
          theme.colorScheme.primary,
          theme.colorScheme.primary.withOpacity(0.8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.attach_money_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Enter Amount',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Amount Input with immediate focus and numeric keypad
          TextField(
            controller: amountController,
            focusNode: amountFocusNode,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: 'Enter amount...',
              hintStyle: TextStyle(
                color: Colors.white70,
                fontSize: 24,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.white30),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.white30),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.white, width: 2),
              ),
              prefixIcon: Icon(
                Icons.payments_rounded,
                color: Colors.white70,
                size: 28,
              ),
              suffixIcon: amountController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: Colors.white70),
                      onPressed: () {
                        amountController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            ),
            onChanged: (value) => setState(() {}),
          ),

          const SizedBox(height: 20),

          // Proceed Button (only show when amount is entered)
          if (amountController.text.isNotEmpty && _isValidAmount())
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showPhoneNumberDialog(context),
                icon: Icon(Icons.arrow_forward_rounded),
                label: Text(
                  'Proceed with Payment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: theme.colorScheme.primary,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          // Helper text when no amount entered
          if (amountController.text.isEmpty)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Enter the amount you want to pay and proceed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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
                    AppTheme.warningColor.withOpacity(0.8),
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
              color: gradient.colors.first.withOpacity(0.3),
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

  Widget _buildPaymentOptions(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.qr_code_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Receive Payment',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'Generate QR codes for others to pay you',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),

            // Amount Input for receiving payments
            TextField(
              controller:
                  TextEditingController(), // Separate controller for receiving
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount to Receive',
                hintText: 'Enter amount to receive',
                prefixIcon: const Icon(Icons.attach_money_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 20),

            // Payment Method Selection for receiving
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.5),
                ),
              ),
              child: DropdownButtonFormField<String>(
                value: selectedPaymentMethod,
                decoration: InputDecoration(
                  labelText: 'Your Payment Method',
                  prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: _getAvailablePaymentMethods(),
                isExpanded: true,
                menuMaxHeight: MediaQuery.of(context).size.height * 0.3,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedPaymentMethod = newValue ?? 'auto';
                  });
                },
              ),
            ),
            const SizedBox(height: 20),

            // Generate QR Code Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement QR generation for receiving payments
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'QR code generation for receiving payments - coming soon!'),
                    ),
                  );
                },
                icon: Icon(Icons.qr_code_rounded),
                label: Text('Generate QR to Receive'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Info container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.secondary.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: theme.colorScheme.secondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Use the amount input above for sending payments. This section is for receiving payments from others.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
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

  Widget _buildPaymentButton({
    required BuildContext context,
    required ThemeData theme,
    required String title,
    required IconData icon,
    required bool isEnabled,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: isEnabled ? onPressed : null,
      icon: Icon(icon),
      label: Text(title),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildQrCodeSection(BuildContext context, ThemeData theme) {
    return Card(
      key: _qrCodeKey,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.qr_code_rounded,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'QR Code for Receiving Payment',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Payment Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Request:',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Amount to receive:',
                              style: theme.textTheme.bodyMedium),
                          Text(
                            '${amountController.text} RWF',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Pay to:', style: theme.textTheme.bodyMedium),
                          Text(
                            _getSelectedPaymentMethodDisplay(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Method:', style: theme.textTheme.bodyMedium),
                          Text(
                            _getPaymentMethodName(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: theme.colorScheme.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Share this QR code with someone who needs to pay you. They can scan it with their MQ Pay app to automatically initiate the payment.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: QrImageView(
                    data: generatedUssdCode!,
                    version: QrVersions.auto,
                    size: MediaQuery.of(context).size.width *
                        0.4, // Responsive size
                    foregroundColor: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    _maskUssdCode(generatedUssdCode!),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        generatedUssdCode = null;
                        showQrCode = false;
                        amountController.clear();
                        // Don't clear manualMobileController since it's for different purpose
                      });

                      // Scroll back to top smoothly
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(S.of(context).reset),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Quick Tips',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTipItem(
              context: context,
              theme: theme,
              icon: Icons.security_rounded,
              title: 'Secure Payments',
              subtitle: 'All transactions are encrypted and secure',
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              context: context,
              theme: theme,
              icon: Icons.speed_rounded,
              title: 'Instant Transfer',
              subtitle: 'Payments are processed in real-time',
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              context: context,
              theme: theme,
              icon: Icons.support_agent_rounded,
              title: '24/7 Support',
              subtitle: 'Get help whenever you need it',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _getAvailablePaymentMethods() {
    List<DropdownMenuItem<String>> items = [
      const DropdownMenuItem(
        value: 'auto',
        child: Row(
          children: [
            Text('Select Payment ID'),
          ],
        ),
      ),
    ];

    // Add payment methods from configuration
    for (PaymentMethod method in paymentMethods) {
      IconData icon = method.type == 'mobile'
          ? Icons.phone_rounded
          : Icons.qr_code_2_rounded;
      String displayText = method.type == 'mobile'
          ? '${method.provider}: ${_maskPhoneNumber(method.value)}'
          : '${method.provider}: ${method.value.length > 3 ? method.value.substring(0, 3) + "***" : method.value}';

      items.add(
        DropdownMenuItem(
          value: method.id,
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(displayText, overflow: TextOverflow.ellipsis)),
              if (method.isDefault) ...[
                const SizedBox(width: 4),
                const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
              ],
            ],
          ),
        ),
      );
    }

    // Fallback to old method for backward compatibility
    if (paymentMethods.isEmpty) {
      if (mobileNumber.isNotEmpty) {
        items.add(
          DropdownMenuItem(
            value: 'mobile',
            child: Row(
              children: [
                const Icon(Icons.phone_rounded, size: 20),
                const SizedBox(width: 8),
                Text('Mobile: ${_maskPhoneNumber(mobileNumber)}'),
              ],
            ),
          ),
        );
      }

      if (momoCode.isNotEmpty) {
        items.add(
          DropdownMenuItem(
            value: 'momo',
            child: Row(
              children: [
                const Icon(Icons.qr_code_2_rounded, size: 20),
                const SizedBox(width: 8),
                Text('Momo: ${momoCode.substring(0, 3)}***'),
              ],
            ),
          ),
        );
      }
    }

    return items;
  }

  String _getSelectedPaymentMethodDisplay() {
    if (selectedPaymentMethod == 'auto') {
      // Auto-select: use default payment method if available
      PaymentMethod? defaultMethod = paymentMethods.isNotEmpty
          ? paymentMethods.firstWhere((m) => m.isDefault,
              orElse: () => paymentMethods.first)
          : null;

      if (defaultMethod != null) {
        return defaultMethod.type == 'mobile'
            ? _maskPhoneNumber(defaultMethod.value)
            : '${defaultMethod.provider}: ${defaultMethod.value.substring(0, 3)}***';
      } else if (mobileNumber.isNotEmpty) {
        return _maskPhoneNumber(mobileNumber);
      } else if (momoCode.isNotEmpty) {
        return 'Momo: ${momoCode.substring(0, 3)}***';
      }
    } else {
      // User selected a specific payment method
      PaymentMethod? selectedMethod = paymentMethods.firstWhere(
        (method) => method.id == selectedPaymentMethod,
        orElse: () => PaymentMethod(id: '', type: '', value: '', provider: ''),
      );

      if (selectedMethod.id.isNotEmpty) {
        return selectedMethod.type == 'mobile'
            ? _maskPhoneNumber(selectedMethod.value)
            : '${selectedMethod.provider}: ${selectedMethod.value.length > 3 ? selectedMethod.value.substring(0, 3) + "***" : selectedMethod.value}';
      } else if (selectedPaymentMethod == 'mobile' && mobileNumber.isNotEmpty) {
        return _maskPhoneNumber(mobileNumber);
      } else if (selectedPaymentMethod == 'momo' && momoCode.isNotEmpty) {
        return 'Momo: ${momoCode.substring(0, 3)}***';
      }
    }
    return 'Not set';
  }

  String _getPaymentMethodName() {
    if (selectedPaymentMethod == 'auto') {
      PaymentMethod? defaultMethod = paymentMethods.isNotEmpty
          ? paymentMethods.firstWhere((m) => m.isDefault,
              orElse: () => paymentMethods.first)
          : null;

      if (defaultMethod != null) {
        return '${defaultMethod.provider} ${defaultMethod.type == 'mobile' ? 'Mobile' : 'Momo'} (Auto)';
      } else {
        return mobileNumber.isNotEmpty
            ? 'Mobile Number (Auto)'
            : 'Momo Code (Auto)';
      }
    } else {
      PaymentMethod? selectedMethod = paymentMethods.firstWhere(
        (method) => method.id == selectedPaymentMethod,
        orElse: () => PaymentMethod(id: '', type: '', value: '', provider: ''),
      );

      if (selectedMethod.id.isNotEmpty) {
        return '${selectedMethod.provider} ${selectedMethod.type == 'mobile' ? 'Mobile' : 'Momo'}';
      } else {
        switch (selectedPaymentMethod) {
          case 'mobile':
            return 'Mobile Number';
          case 'momo':
            return 'Momo Code';
          default:
            return 'Unknown';
        }
      }
    }
  }

  bool _isValidAmount() {
    if (amountController.text.isEmpty) return false;
    final amount = int.tryParse(amountController.text);
    return amount != null && amount >= 1; // Minimum 1 RWF for testing
  }

  Future<void> _loadContact() async {
    try {
      Contact? contact = await _contactPicker.selectContact();
      if (contact != null) {
        List<String>? phoneNumbers = contact.phoneNumbers;
        selectedNumber = phoneNumbers?.first;
        if (selectedNumber != null) {
          if (_isValidPhoneNumber(selectedNumber!) ||
              _isValidMomoCode(selectedNumber!)) {
            String formattedNumber = _formatPhoneNumber(selectedNumber!);
            setState(() {
              manualMobileController.text = formattedNumber;
            });
            Future.delayed(const Duration(milliseconds: 100), () {
              amountFocusNode.requestFocus();
            });
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
}
