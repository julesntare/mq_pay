import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/settings.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'generated/l10n.dart';
import 'helpers/localProvider.dart';
import 'helpers/app_theme.dart';
import 'helpers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/backup_service.dart';
import 'services/supabase_backup_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:workmanager/workmanager.dart';
import 'services/daily_total_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/sms_listener_service.dart';
import 'services/notification_service.dart';
import 'services/ussd_detector_service.dart';
import 'services/ussd_transaction_manager.dart';
import 'services/service_polling_scheduler.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await dotenv.load(fileName: ".env");
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (task == ServicePollingScheduler.taskName) {
        await NotificationService.initialize();
        await SmsListenerService.pollServiceTransactions();
      } else {
        await DailyTotalService.sendDailyTotal();
      }
      return Future.value(true);
    } catch (e) {
      return Future.value(false);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // dotenv must load before Firebase (firebase_options.dart reads from it).
  await dotenv.load(fileName: ".env");

  final localeProvider = LocaleProvider();

  // Only block on SharedPreferences and locale — the bare minimum needed
  // before the first frame. Everything else is deferred to the background.
  final results = await Future.wait<dynamic>([
    SharedPreferences.getInstance(),
    localeProvider.loadLocale(),
  ]);

  final prefs = results[0] as SharedPreferences;
  final themeProvider = ThemeProvider();

  // Start background services after runApp so they don't delay the UI.
  Future(() async {
    // Date formatting first — needed before the history screen renders dates.
    await Future.wait([
      for (final locale in ['en', 'fr', 'sw', 'rw'])
        initializeDateFormatting(locale).catchError((_) => null),
    ]);

    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {}
    try {
      await SupabaseBackupService.initialize();
    } catch (_) {}
    try {
      await Workmanager().initialize(callbackDispatcher);
      await DailyTotalService.scheduleDailyTask();
      await NotificationService.initialize();
      await SmsListenerService.initialize();
      UssdTransactionManager.initialize();
      await UssdDetectorService.initialize();
      BackupService.performAutoBackupIfNeeded();
      SupabaseBackupService.performAutoBackupIfNeeded();
    } catch (_) {}
  });

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

/// Falls back to English MaterialLocalizations for locales not supported by
/// GlobalMaterialLocalizations (e.g. 'rw' / Kinyarwanda).
class _MaterialLocalizationsFallbackDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _MaterialLocalizationsFallbackDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    final effectiveLocale =
        GlobalMaterialLocalizations.delegate.isSupported(locale)
            ? locale
            : const Locale('en');
    return GlobalMaterialLocalizations.delegate.load(effectiveLocale);
  }

  @override
  bool shouldReload(_MaterialLocalizationsFallbackDelegate old) => false;
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
            _MaterialLocalizationsFallbackDelegate(),
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('fr'),
            Locale('sw'),
            Locale('rw'),
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

class _MainWrapperState extends State<MainWrapper> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  late String mobileNumber;
  late String momoCode;
  late String? selectedLanguage;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

    // Defer retry to after first frame — retryPendingTransactionMatching() does
    // up to 100× JSON-decode of all records (once per SMS via matchSmsToTransaction),
    // which was blocking the UI thread during the first frame render (~1800ms jank).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _retryPendingTransactions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground - retry matching pending transactions
      _retryPendingTransactions();
    }
  }

  Future<void> _retryPendingTransactions() async {
    final matchedCount =
        await SmsListenerService.retryPendingTransactionMatching();
    if (matchedCount > 0) {
      // Show notification that transactions were matched
      await NotificationService.showTransactionStatusNotification();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
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
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: _pages[_selectedIndex],
      ),
    );
  }
}
