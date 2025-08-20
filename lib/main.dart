import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/several_codes.dart';
import 'screens/simple_nearest_stores.dart';
import 'screens/settings.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'generated/l10n.dart';
import 'helpers/localProvider.dart';
import 'helpers/app_theme.dart';
import 'helpers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeProvider = LocaleProvider();
  final themeProvider = ThemeProvider();
  final prefs = await SharedPreferences.getInstance();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await localeProvider.loadLocale();

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
      CodesPage(),
      SimpleNearestStoresPage(),
      SettingsPage(
          initialMobile: mobileNumber,
          initialMomoCode: momoCode,
          selectedLanguage: selectedLanguage!),
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          ['Home', 'QR Codes', 'Nearby Stores', 'Settings'][_selectedIndex],
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.menu_rounded,
                color: theme.colorScheme.primary,
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.notifications_rounded,
                color: theme.colorScheme.primary,
              ),
              onPressed: () {
                // Add notification functionality
              },
            ),
          ),
        ],
      ),
      drawer: _buildModernDrawer(context, theme),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withOpacity(0.02),
              theme.colorScheme.background,
            ],
          ),
        ),
        child: _pages[_selectedIndex],
      ),
    );
  }

  Widget _buildModernDrawer(BuildContext context, ThemeData theme) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withOpacity(0.8),
            ],
          ),
        ),
        child: Column(
          children: [
            // Modern Drawer Header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'MQ Pay',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Mobile Payment Solution',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Navigation Items
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  children: [
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.home_rounded,
                      title: 'Home',
                      index: 0,
                      theme: theme,
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.qr_code_rounded,
                      title: 'QR Codes',
                      index: 1,
                      theme: theme,
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.location_on_rounded,
                      title: 'Nearby Stores',
                      index: 2,
                      theme: theme,
                    ),
                    const Spacer(),
                    const Divider(),
                    const SizedBox(height: 4),

                    // Theme Toggle
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, child) {
                        return Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: Icon(
                              themeProvider.themeIcon,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                            title: Text(
                              '${themeProvider.themeModeString} Theme',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            onTap: () => themeProvider.toggleTheme(),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),

                    _buildDrawerItem(
                      context: context,
                      icon: Icons.settings_rounded,
                      title: 'Settings',
                      index: 3,
                      theme: theme,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int index,
    required ThemeData theme,
  }) {
    final isSelected = _selectedIndex == index;

    return Container(
      decoration: BoxDecoration(
        gradient: isSelected ? AppTheme.primaryGradient : null,
        color: isSelected ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : theme.colorScheme.primary,
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 16,
          ),
        ),
        onTap: () => _onItemTapped(index),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
    );
  }
}
