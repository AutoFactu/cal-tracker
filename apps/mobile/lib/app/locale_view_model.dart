import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../data/services/app_preferences_repository.dart';

class LocaleViewModel extends ChangeNotifier {
  LocaleViewModel({required AppPreferencesRepository preferencesRepository})
      : _preferencesRepository = preferencesRepository;

  static const supportedLocales = [
    Locale('en'),
    Locale('es'),
  ];

  static const supportedLocaleCodes = {'en', 'es'};

  final AppPreferencesRepository _preferencesRepository;

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  String get localeCode => _locale.languageCode;

  Future<void> load() async {
    final savedCode = await _preferencesRepository.loadLocaleCode();
    final nextLocale = Locale(_normalizeCode(savedCode));
    if (nextLocale == _locale) return;
    _locale = nextLocale;
    notifyListeners();
  }

  Future<void> setLocaleCode(String code) async {
    final nextLocale = Locale(_normalizeCode(code));
    if (nextLocale == _locale) return;
    _locale = nextLocale;
    notifyListeners();
    await _preferencesRepository.saveLocaleCode(nextLocale.languageCode);
  }

  static String _normalizeCode(String? code) {
    final normalized = code?.toLowerCase().split(RegExp('[-_]')).first;
    if (normalized == null || !supportedLocaleCodes.contains(normalized)) {
      return 'en';
    }
    return normalized;
  }
}
