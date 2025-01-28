import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

extension LocalizationExtension on BuildContext {
  AppLocalizations get loc => AppLocalizations.of(this)!;
}

class L10n {
  static final supportedLocales = [
    const Locale('rw'),
    const Locale('en', 'US'),
    const Locale('fr', 'FR'),
    const Locale('sw'),
  ];

  static const localizationsDelegates = AppLocalizations.localizationsDelegates;
}
