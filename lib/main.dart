import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/settings.dart';
import 'screens/several_codes.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'generated/l10n.dart';
import 'helpers/localProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeProvider = LocaleProvider();
  final prefs = await SharedPreferences.getInstance();

  await localeProvider.loadLocale();

  runApp(
    ChangeNotifierProvider(
      create: (_) => localeProvider,
      child: MyApp(pref: prefs),
    ),
  );
}

class MyApp extends StatelessWidget {
  final SharedPreferences pref;

  const MyApp({super.key, required this.pref});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MQ Pay',
      debugShowCheckedModeBanner: false,
      home: MainWrapper(pref: pref),
      locale: Provider.of<LocaleProvider>(context).locale,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
        Locale('sw'),
      ],
    );
  }
}

class MainWrapper extends StatefulWidget {
  final SharedPreferences pref;

  const MainWrapper({super.key, required this.pref});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;
  late String mobileNumber;
  late String momoCode;
  late String? selectedLanguage;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    mobileNumber = widget.pref.getString('mobileNumber') ?? '';
    momoCode = widget.pref.getString('momoCode') ?? '';
    selectedLanguage = widget.pref.getString('selectedLanguage') ?? 'en';

    _pages = <Widget>[
      const Home(),
      SettingsPage(
          initialMobile: mobileNumber,
          initialMomoCode: momoCode,
          selectedLanguage: selectedLanguage!),
      const CodesPage(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Close the drawer
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(['Home', 'Settings', 'Several Codes'][_selectedIndex]),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('MQ Pay',
                  style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              selected: _selectedIndex == 0,
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Several Codes'),
              selected: _selectedIndex == 2,
              onTap: () => _onItemTapped(2),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              selected: _selectedIndex == 1,
              onTap: () => _onItemTapped(1),
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }
}
