import 'package:cal_tracker_mobile/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'meal_label_helpers.dart';

void main() {
  patrolTest('switches language from Menu and persists after app restart',
      ($) async {
    final email = await _pumpAndAuthenticate($);
    await _openMenu($);

    await _chooseLanguage($, const ValueKey('language_option_en'));
    await $('Language').waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );

    await _chooseLanguage($, const ValueKey('language_option_es'));
    await $('Idioma').waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );
    await $('Inicio').waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );

    await $.pumpWidgetAndSettle(
      const CalTrackerBootstrap(apiConfig: patrolApiConfig),
    );
    final restartSurface = await _waitForRestartSurface($);
    if (restartSurface == _RestartSurface.auth) {
      await $('Correo').waitUntilVisible(timeout: const Duration(seconds: 20));
      await _loginFromAuthScreen($, email ?? await _createLanguageUser());
    } else if (restartSurface == _RestartSurface.log) {
      await $(const ValueKey('meal_text_field'))
          .waitUntilVisible(timeout: const Duration(seconds: 20));
    }
    if (restartSurface != _RestartSurface.menu) {
      await _openMenu($);
    }
    await $('Idioma').waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );

    await _chooseLanguage($, const ValueKey('language_option_en'));
    await $('Language').waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );
  });
}

enum _RestartSurface { auth, log, menu }

Future<_RestartSurface> _waitForRestartSurface(
    PatrolIntegrationTester $) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await $.pump(const Duration(milliseconds: 500));
    if ($(const ValueKey('email_field')).exists) return _RestartSurface.auth;
    if ($(const ValueKey('meal_text_field')).exists) return _RestartSurface.log;
    if ($(const ValueKey('language_settings_row')).exists) {
      return _RestartSurface.menu;
    }
  }
  throw StateError('Restart did not show auth, log, or menu surface.');
}

Future<String?> _pumpAndAuthenticate(PatrolIntegrationTester $) async {
  await $.pumpWidgetAndSettle(
    const CalTrackerBootstrap(apiConfig: patrolApiConfig),
  );
  if ($(const ValueKey('meal_text_field')).exists) return null;

  final email = await _createLanguageUser();
  await _loginFromAuthScreen($, email);
  return email;
}

Future<String> _createLanguageUser() async {
  final email = 'language-${DateTime.now().microsecondsSinceEpoch}@example.com';
  await registerPatrolUser(email);
  return email;
}

Future<void> _loginFromAuthScreen(
    PatrolIntegrationTester $, String email) async {
  await $(const ValueKey('email_field')).enterText(email);
  await $(const ValueKey('password_field')).enterText('password123');
  FocusManager.instance.primaryFocus?.unfocus();
  await $.pumpAndSettle();
  await $(const ValueKey('auth_submit_button')).scrollTo().tap();
  await $(const ValueKey('meal_text_field')).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
}

Future<void> _openMenu(PatrolIntegrationTester $) async {
  await $(const ValueKey('nav_menu_button')).tap();
  await $(const ValueKey('language_settings_row')).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
}

Future<void> _chooseLanguage(
  PatrolIntegrationTester $,
  ValueKey<String> optionKey,
) async {
  await $(const ValueKey('language_settings_row')).tap();
  await $(optionKey).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
  await $(optionKey).tap();
  await $.pumpAndSettle();
}
