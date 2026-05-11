import 'package:cal_tracker_mobile/app/theme_mode_view_model.dart';
import 'package:cal_tracker_mobile/data/services/app_preferences_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to light mode before loading preferences', () {
    final viewModel = ThemeModeViewModel(
      preferencesRepository: _FakePreferencesRepository(),
    );

    expect(viewModel.themeMode, ThemeMode.light);
    expect(viewModel.isDarkMode, isFalse);
  });

  test('load keeps light default without notifying when no preference exists',
      () async {
    final viewModel = ThemeModeViewModel(
      preferencesRepository: _FakePreferencesRepository(),
    );
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    await viewModel.load();

    expect(viewModel.themeMode, ThemeMode.light);
    expect(notifications, 0);
  });

  test('load applies stored dark mode and notifies listeners', () async {
    final repository = _FakePreferencesRepository(ThemeMode.dark);
    final viewModel = ThemeModeViewModel(
      preferencesRepository: repository,
    );
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    await viewModel.load();

    expect(viewModel.themeMode, ThemeMode.dark);
    expect(viewModel.isDarkMode, isTrue);
    expect(notifications, 1);
  });

  test('setDarkMode persists, toggles, and avoids duplicate notifications',
      () async {
    final repository = _FakePreferencesRepository();
    final viewModel = ThemeModeViewModel(
      preferencesRepository: repository,
    );
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    await viewModel.setDarkMode(true);

    expect(viewModel.themeMode, ThemeMode.dark);
    expect(repository.savedModes, [ThemeMode.dark]);
    expect(notifications, 1);

    await viewModel.setDarkMode(true);

    expect(repository.savedModes, [ThemeMode.dark]);
    expect(notifications, 1);

    await viewModel.setDarkMode(false);

    expect(viewModel.themeMode, ThemeMode.light);
    expect(repository.savedModes, [ThemeMode.dark, ThemeMode.light]);
    expect(notifications, 2);
  });
}

class _FakePreferencesRepository implements AppPreferencesRepository {
  _FakePreferencesRepository([this.savedThemeMode = ThemeMode.light]);

  ThemeMode savedThemeMode;
  String? savedLocaleCode;
  final List<ThemeMode> savedModes = [];

  @override
  Future<ThemeMode> loadThemeMode() async => savedThemeMode;

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    savedThemeMode = mode;
    savedModes.add(mode);
  }

  @override
  Future<String?> loadLocaleCode() async => savedLocaleCode;

  @override
  Future<void> saveLocaleCode(String code) async {
    savedLocaleCode = code;
  }

  @override
  Future<int> nextAuthHeroIndex({int count = 5}) async => 0;
}
