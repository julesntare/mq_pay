import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'l10n/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class LocaleProvider extends ChangeNotifier {
  Locale? _locale;
  Locale? get locale => _locale;

  void setLocale(Locale locale) async {
    if (!L10n.supportedLocales.contains(locale)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', locale.languageCode);

    _locale = locale;
    notifyListeners();
  }

  Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language') ?? 'rw';
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
      child: const UssdApp(),
    ),
  );
}

class UssdApp extends StatelessWidget {
  const UssdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        ...L10n.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L10n.supportedLocales,
      localeResolutionCallback: (locale, supportedLocales) {
        // Use device locale if supported, otherwise fallback to English
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        return const Locale('en');
      },
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
  final TextEditingController momoCodeController = TextEditingController();

  String? generatedUssdCode;
  bool showQrCode = false;

  String mobileNumber = '';
  String momoCode = '';
  String scannedData = '';

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
        SnackBar(content: Text(context.loc.invalidAmount)),
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
        SnackBar(content: Text('Unable to launch USSD code: $ussdCode')),
      );
    }
  }

  void _openSettings() {
    mobileController.text = mobileNumber;
    momoCodeController.text = momoCode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.loc.settings),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: mobileController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.loc.mobileNumber),
            ),
            TextField(
              controller: momoCodeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.loc.momoCode),
            ),
            const SizedBox(height: 20),
            DropdownButton<Locale>(
              isExpanded: true,
              value: Provider.of<LocaleProvider>(context).locale,
              items: L10n.supportedLocales.map((Locale locale) {
                final flag = _getFlag(locale.languageCode);
                return DropdownMenuItem<Locale>(
                  value: locale,
                  child: Row(
                    children: [
                      Text(flag),
                      const SizedBox(width: 10),
                      Text(_getLanguageName(locale.languageCode)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (Locale? locale) {
                if (locale != null) {
                  Provider.of<LocaleProvider>(context, listen: false)
                      .setLocale(locale);
                }
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
            child: Text(context.loc.save),
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
    return Scaffold(
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Welcome Here', style: TextStyle(fontSize: 24)),
            SizedBox(height: 8),
            Text('Make your payments quick & smoothly!',
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.loc.amount,
                hintText: context.loc.enterAmount,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed:
                      mobileNumber.isEmpty || amountController.text.isEmpty
                          ? null
                          : () => _generateQrCode('Mobile Number'),
                  child: Text(context.loc.mobileNumber),
                ),
                ElevatedButton(
                  onPressed: momoCode.isEmpty || amountController.text.isEmpty
                      ? null
                      : () => _generateQrCode('Momo Code'),
                  child: Text(context.loc.momoCode),
                ),
                ElevatedButton(
                  onPressed: _scanQrCode,
                  child: Text(context.loc.scanNow),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (showQrCode && generatedUssdCode != null) ...[
              Text(
                '${context.loc.generate} QR Code:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  child: Text(context.loc.reset),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
