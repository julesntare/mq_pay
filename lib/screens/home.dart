import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../generated/l10n.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import '../helpers/launcher.dart';

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
  String? selectedNumber;
  String? selectedName;

  String? generatedUssdCode;
  bool showQrCode = false;

  String mobileNumber = '';
  String momoCode = '';
  String scannedData = '';
  String? selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
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

  @override
  void dispose() {
    amountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      mobileNumber = prefs.getString('mobileNumber') ?? '';
      momoCode = prefs.getString('momoCode') ?? '';
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
      ussdCode = '*182*1*1*$mobileNumber*$amount#';
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

  Future<void> _scanQrCode() async {
    try {
      var result = await BarcodeScanner.scan();

      if (result.type == ResultType.Cancelled) {
        return;
      }

      setState(() {
        scannedData = result.rawContent;
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.of(context).welcomeHere,
                      style: TextStyle(fontSize: 24)),
                  SizedBox(height: 8),
                  Text(S.of(context).shortDesc, style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
            TabBar(
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: S.of(context).viaScan),
                Tab(text: S.of(context).viaContact),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: S.of(context).amount,
                            hintText: S.of(context).enterAmount,
                            border: OutlineInputBorder(),
                            suffixIcon: amountController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      amountController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              onPressed: mobileNumber.isEmpty ||
                                      amountController.text.isEmpty ||
                                      int.tryParse(amountController.text) ==
                                          null ||
                                      int.parse(amountController.text) < 100
                                  ? null
                                  : () => _generateQrCode('Mobile Number'),
                              child: Text(S.of(context).mobileNumber),
                            ),
                            ElevatedButton(
                              onPressed: momoCode.isEmpty ||
                                      amountController.text.isEmpty ||
                                      int.tryParse(amountController.text) ==
                                          null ||
                                      int.parse(amountController.text) < 100
                                  ? null
                                  : () => _generateQrCode('Momo Code'),
                              child: Text(S.of(context).momoCode),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (!showQrCode && generatedUssdCode == null) ...[
                          ElevatedButton(
                            onPressed: _scanQrCode,
                            child: Text(S.of(context).scanNow),
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (showQrCode && generatedUssdCode != null) ...[
                          Text(
                            '${S.of(context).generate} QR Code:',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: QrImageView(
                              data: generatedUssdCode!,
                              version: QrVersions.auto,
                              size: 200.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: SelectableText(
                              generatedUssdCode!,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Center(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  generatedUssdCode = null;
                                  showQrCode = false;
                                  amountController.clear();
                                });
                              },
                              child: Text(S.of(context).reset),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: ElevatedButton(
                            onPressed: () async {
                              Contact? contact =
                                  await _contactPicker.selectContact();
                              if (contact != null) {
                                List<String>? phoneNumbers =
                                    contact.phoneNumbers;
                                selectedNumber = phoneNumbers?.first;
                                if (selectedNumber != null) {
                                  if (_isValidPhoneNumber(selectedNumber!)) {
                                    String formattedNumber =
                                        _formatPhoneNumber(selectedNumber!);
                                    setState(() {
                                      manualMobileController.text =
                                          formattedNumber;
                                    });
                                    // Focus on amount field after successful contact load
                                    Future.delayed(Duration(milliseconds: 100),
                                        () {
                                      amountFocusNode.requestFocus();
                                    });
                                  } else {
                                    // Show error alert for invalid number
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: Text('Invalid Phone Number'),
                                          content: Text(
                                              'The selected contact has an invalid phone number format. Please select a contact with a valid Rwanda phone number (+25078/9/2/3xxxxxxx, 078/9/2/3xxxxxxx, or 78/9/2/3xxxxxxx).'),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: Text('OK'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  }
                                }
                              }
                            },
                            child: Text(S.of(context).loadFromContacts),
                          ),
                        ),
                        TextField(
                          controller: manualMobileController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: S.of(context).mobileNumber,
                            hintText: S.of(context).mobileNumber,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: amountController,
                          focusNode: amountFocusNode,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: S.of(context).amount,
                            hintText: S.of(context).enterAmount,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: manualMobileController.text.isEmpty ||
                                  amountController.text.isEmpty
                              ? null
                              : () {
                                  launchUSSD(
                                      "*182*${RegExp(r'^(?:\+2507|2507|07|7)[0-9]{8}$').hasMatch(manualMobileController.text) ? '1' : '8'}*1*${manualMobileController.text}*${amountController.text}#",
                                      context);
                                },
                          child: Text(S.of(context).proceed),
                        )
                      ],
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
}
