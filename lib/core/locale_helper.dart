import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyLocale = 'app_locale';
const String _localeTr = 'tr_TR';
const String _localeEn = 'en_US';

/// Persists and restores app locale. Auto-detects: if system is not Turkish, default to English.
class LocaleHelper {
  LocaleHelper._();

  /// Returns the locale to use at app start: saved preference, or system locale (Turkish → tr_TR, else en_US).
  static Future<Locale> getStartLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyLocale);
    if (saved != null && saved.isNotEmpty) {
      if (saved == _localeTr) return const Locale('tr', 'TR');
      if (saved == _localeEn) return const Locale('en', 'US');
    }
    final systemLocale = ui.PlatformDispatcher.instance.locale;
    if (systemLocale.languageCode == 'tr') return const Locale('tr', 'TR');
    return const Locale('en', 'US');
  }

  /// Saves the selected locale and returns it.
  static Future<Locale> setLocale(String languageCode, [String? countryCode]) async {
    final locale = countryCode != null
        ? Locale(languageCode, countryCode)
        : Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    final toSave = countryCode != null ? '${languageCode}_$countryCode' : languageCode;
    await prefs.setString(_keyLocale, toSave);
    return locale;
  }

  static String get localeTr => _localeTr;
  static String get localeEn => _localeEn;
}
