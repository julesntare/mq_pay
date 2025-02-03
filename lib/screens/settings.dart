import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../generated/l10n.dart';
import '../helpers/localProvider.dart';

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

  @override
  void initState() {
    super.initState();
    mobileController = TextEditingController(text: widget.initialMobile);
    momoCodeController = TextEditingController(text: widget.initialMomoCode);
    selectedLanguage = widget.selectedLanguage;
  }

  String _getFlag(String languageCode) {
    switch (languageCode) {
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: mobileController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: S.of(context).mobileNumber,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: momoCodeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: S.of(context).momoCode,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: Provider.of<LocaleProvider>(context).locale!.languageCode,
              decoration: InputDecoration(
                labelText: S.of(context).selectLanguage,
                border: const OutlineInputBorder(),
              ),
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
                  selectedLanguage = newValue!;
                });
                final locale = Locale(newValue!);
                Provider.of<LocaleProvider>(context, listen: false)
                    .setLocale(locale);
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
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

                _saveSettings();
              },
              child: Text(S.of(context).save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved'),
      ),
    );
  }
}
