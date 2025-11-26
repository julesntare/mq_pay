import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/settings.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'generated/l10n.dart';
import 'helpers/localProvider.dart';
import 'helpers/app_theme.dart';
import 'helpers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/backup_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:workmanager/workmanager.dart';
import 'services/daily_total_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await DailyTotalService.sendDailyTotal();
      return Future.value(true);
    } catch (e) {
      return Future.value(false);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Workmanager
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  // Schedule daily task at 11:59 PM CAT
  await DailyTotalService.scheduleDailyTask();

  final localeProvider = LocaleProvider();
  final themeProvider = ThemeProvider();
  final prefs = await SharedPreferences.getInstance();

  await localeProvider.loadLocale();

  // Check and perform auto-backup if needed
  BackupService.performAutoBackupIfNeeded();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => localeProvider),
        ChangeNotifierProvider(create: (_) => themeProvider),
      ],
      child: MyApp(pref: prefs),
    ),
  );
}

class MyApp extends StatelessWidget {
  final SharedPreferences pref;

  const MyApp({super.key, required this.pref});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'MQ Pay',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
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
      },
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
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          ['MQ Pay', 'Settings'][_selectedIndex],
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.02),
              theme.colorScheme.background,
            ],
          ),
        ),
        child: _pages[_selectedIndex],
      ),
    );
  }
}
