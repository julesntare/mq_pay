import 'package:intl/intl.dart';

/// Locales that have app translations but are not in CLDR's date symbol data.
/// DateFormat throws "Invalid locale" for these, so we fall back to 'en'.
const _cldrUnsupported = {'rw'};

/// Creates a [DateFormat] using the current [Intl.defaultLocale], falling back
/// to 'en' for locales that have no CLDR date symbol data (e.g. 'rw').
DateFormat safeDateFormat(String pattern) {
  final locale = Intl.defaultLocale ?? 'en';
  final safeLocale = _cldrUnsupported.contains(locale) ? 'en' : locale;
  return DateFormat(pattern, safeLocale);
}
