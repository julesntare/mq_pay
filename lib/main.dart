import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'generated/l10n.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';

class LocaleProvider extends ChangeNotifier {
  Locale? _locale;
  Locale? get locale => _locale;

  void setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', locale.languageCode);

    _locale = locale;
    notifyListeners();
  }

  Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language') ?? 'en';
    _locale = Locale(languageCode);
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeProvider = LocaleProvider();
  await localeProvider.loadLocale();

  runApp(
    ChangeNotifierProvider(
      create: (_) => localeProvider,
      child: const MQPayApp(),
    ),
  );
}

class MQPayApp extends StatelessWidget {
  const MQPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Provider.of<LocaleProvider>(context).locale,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('en'),
        const Locale('rw'),
        const Locale('fr'),
        const Locale('sw'),
      ],
      home: UssdScreen(),
    );
  }
}

class UssdScreen extends StatefulWidget {
  const UssdScreen({super.key});

  @override
  _UssdScreenState createState() => _UssdScreenState();
}

class _UssdScreenState extends State<UssdScreen> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController manualMobileController = TextEditingController();
  final TextEditingController momoCodeController = TextEditingController();
  final FlutterNativeContactPicker _contactPicker =
      FlutterNativeContactPicker();
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
        generatedUssdCode = null;
        showQrCode = false;
        amountController.clear();
        _launchUSSD(scannedData);
      });
    } catch (e) {
      setState(() {
        scannedData = 'Error: $e';
      });
    }
  }

  void _launchUSSD(String ussdCode) async {
    final formattedCode = ussdCode.replaceAll('#', Uri.encodeComponent('#'));
    final ussdUrl = 'tel:$formattedCode';
    if (await canLaunch(ussdUrl)) {
      await launch(ussdUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${S.of(context).launchError}: $ussdCode')),
      );
    }
  }

  void _openSettings() {
    mobileController.text = mobileNumber;
    momoCodeController.text = momoCode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).settings),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: mobileController,
              keyboardType: TextInputType.number,
              decoration:
                  InputDecoration(labelText: S.of(context).mobileNumber),
            ),
            TextField(
              controller: momoCodeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: S.of(context).momoCode),
            ),
            const SizedBox(height: 20),
            DropdownButton<String>(
              isExpanded: true,
              value: selectedLanguage,
              items: ['en', 'fr', 'sw'].map((String locale) {
                final flag = _getFlag(locale);
                return DropdownMenuItem<String>(
                  value: locale,
                  child: Row(
                    children: [
                      Text(flag),
                      const SizedBox(width: 10),
                      Text(_getLanguageName(locale)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedLanguage = newValue;
                });
                Locale locale = Locale(newValue!);
                Provider.of<LocaleProvider>(context, listen: false)
                    .setLocale(locale);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final newMobile = mobileController.text.trim();
              final newMomo = momoCodeController.text.trim();
              final prefs = await SharedPreferences.getInstance();

              if (newMobile.isEmpty) {
                await prefs.remove('mobileNumber');
              } else {
                await prefs.setString('mobileNumber', newMobile);
              }

              if (newMomo.isEmpty) {
                await prefs.remove('momoCode');
              } else {
                await prefs.setString('momoCode', newMomo);
              }

              setState(() {
                mobileNumber = newMobile;
                momoCode = newMomo;
              });
              Navigator.pop(context);
            },
            child: Text(S.of(context).save),
          ),
        ],
      ),
    );
  }

  String _getFlag(String languageCode) {
    switch (languageCode) {
      case 'rw':
        return '🇷🇼';
      case 'fr':
        return '🇫🇷';
      case 'sw':
        return '🇹🇿';
      default:
        return '🇺🇸';
    }
  }

  String _getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'rw':
        return 'Kinyarwanda';
      case 'en':
        return 'English';
      case 'fr':
        return 'Français';
      case 'sw':
        return 'Kiswahili';
      default:
        return 'English';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MQ Pay'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _openSettings,
            ),
          ],
        ),
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
                                      amountController.text.isEmpty
                                  ? null
                                  : () => _generateQrCode('Mobile Number'),
                              child: Text(S.of(context).mobileNumber),
                            ),
                            ElevatedButton(
                              onPressed: momoCode.isEmpty ||
                                      amountController.text.isEmpty
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
                                setState(() {
                                  List<String>? phoneNumbers =
                                      contact.phoneNumbers;
                                  selectedNumber = phoneNumbers?.first;
                                  manualMobileController.text = selectedNumber!;
                                });
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
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: S.of(context).amount,
                            hintText: S.of(context).enterAmount,
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: manualMobileController.text.isEmpty ||
                                  amountController.text.isEmpty
                              ? null
                              : () {
                                  _launchUSSD(
                                      "*182*1*1*${manualMobileController.text}*${amountController.text}#");
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
