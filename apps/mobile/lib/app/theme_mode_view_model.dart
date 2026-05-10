import 'package:flutter/material.dart';

import '../data/services/app_preferences_repository.dart';

class ThemeModeViewModel extends ChangeNotifier {
  ThemeModeViewModel({required AppPreferencesRepository preferencesRepository})
      : _preferencesRepository = preferencesRepository;

  final AppPreferencesRepository _preferencesRepository;

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> load() async {
    final savedThemeMode = await _preferencesRepository.loadThemeMode();
    if (savedThemeMode == _themeMode) return;
    _themeMode = savedThemeMode;
    notifyListeners();
  }

  Future<void> setDarkMode(bool enabled) async {
    final nextThemeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    if (nextThemeMode == _themeMode) return;
    _themeMode = nextThemeMode;
    notifyListeners();
    await _preferencesRepository.saveThemeMode(nextThemeMode);
  }
}
