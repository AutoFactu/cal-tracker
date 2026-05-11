import 'package:cal_tracker_mobile/app/app.dart';
import 'package:cal_tracker_mobile/data/services/app_preferences_repository.dart';
import 'package:cal_tracker_mobile/ui/core/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows auth screen before a stored session exists',
      (tester) async {
    await tester.pumpWidget(
      CalTrackerBootstrap(preferencesRepository: _FakePreferencesRepository()),
    );
    await tester.pump();

    expect(find.text('Better Calories'), findsOneWidget);
    expect(
        find.textContaining('Track your', findRichText: true), findsOneWidget);
    expect(find.textContaining('calories better', findRichText: true),
        findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.byKey(const ValueKey('email_field')), findsOneWidget);
  });

  testWidgets('starts in Spanish when saved locale preference is Spanish',
      (tester) async {
    await tester.pumpWidget(
      CalTrackerBootstrap(
        preferencesRepository: _FakePreferencesRepository(
          ThemeMode.light,
          'es',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Correo'), findsOneWidget);
    expect(find.textContaining('Controla mejor', findRichText: true),
        findsOneWidget);
  });

  testWidgets('keeps auth screen light when saved theme mode is dark',
      (tester) async {
    await tester.pumpWidget(
      CalTrackerBootstrap(
        preferencesRepository: _FakePreferencesRepository(ThemeMode.dark),
      ),
    );
    await tester.pump();
    await tester.pump();

    final emailFieldContext =
        tester.element(find.byKey(const ValueKey('email_field')));

    expect(Theme.of(emailFieldContext).brightness, Brightness.light);
    expect(emailFieldContext.freshPalette, FreshPalette.light);
  });
}

class _FakePreferencesRepository implements AppPreferencesRepository {
  _FakePreferencesRepository([
    this.savedThemeMode = ThemeMode.light,
    this.savedLocaleCode,
  ]);

  ThemeMode savedThemeMode;
  String? savedLocaleCode;
  int nextHeroIndex = 0;

  @override
  Future<ThemeMode> loadThemeMode() async => savedThemeMode;

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    savedThemeMode = mode;
  }

  @override
  Future<String?> loadLocaleCode() async => savedLocaleCode;

  @override
  Future<void> saveLocaleCode(String code) async {
    savedLocaleCode = code;
  }

  @override
  Future<int> nextAuthHeroIndex({int count = 5}) async {
    final value = nextHeroIndex % count;
    nextHeroIndex++;
    return value;
  }
}
