import 'dart:convert';

import 'package:cal_tracker_mobile/app/app.dart';
import 'package:cal_tracker_mobile/data/services/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:patrol/patrol.dart';

const _patrolApiConfig = ApiConfig(baseUrl: 'http://10.0.2.2:3000');

void main() {
  patrolTest('auth screen accepts typed credentials', ($) async {
    await $.pumpWidgetAndSettle(
      const CalTrackerBootstrap(apiConfig: _patrolApiConfig),
    );

    await $(const ValueKey('email_field')).enterText('demo@example.com');
    await $(const ValueKey('password_field')).enterText('password123');

    expect($(const ValueKey('auth_submit_button')), findsOneWidget);
  });

  patrolTest('logs a stable bread meal through the agent', ($) async {
    await _pumpAndAuthenticate($);

    await $(const ValueKey('meal_text_field')).enterText(
      'Add 100 grams of bread.',
    );
    await $(const ValueKey('submit_meal_button')).tap();

    await $(const ValueKey('confirm_proposal_button')).waitUntilExists(
      timeout: const Duration(seconds: 120),
    );
    await $(const ValueKey('confirm_proposal_button')).scrollTo();
    expect(find.text('Needs a little more detail'), findsNothing);
    expect(find.textContaining('Bread', findRichText: true), findsWidgets);
    await $(const ValueKey('confirm_proposal_button')).scrollTo().tap();

    await $.pumpAndSettle();
    expect(find.textContaining('Bread', findRichText: true), findsWidgets);
  });

  patrolTest('opens the proposal editor for a stable bread meal', ($) async {
    await _pumpAndAuthenticate($);

    await $(const ValueKey('meal_text_field')).enterText(
      'Add 100 grams of bread.',
    );
    await $(const ValueKey('submit_meal_button')).tap();

    await $(const ValueKey('confirm_proposal_button')).waitUntilExists(
      timeout: const Duration(seconds: 120),
    );
    expect(find.textContaining('Bread', findRichText: true), findsWidgets);

    await $(const ValueKey('edit_proposal_button')).scrollTo().tap();
    expect($('Edit ingredients'), findsOneWidget);
    expect($(const ValueKey('proposal_item_name_0')), findsOneWidget);
    expect($(const ValueKey('proposal_item_quantity_0')), findsOneWidget);
    expect($(const ValueKey('add_proposal_item_button')), findsOneWidget);
  });

  patrolTest('shows resolver clarification for unresolved ingredients',
      ($) async {
    await _pumpAndAuthenticate($);

    await $(const ValueKey('meal_text_field')).enterText(
      'Añade 100 gramos de pan y 100 gramos de zzzzzzz',
    );
    await $(const ValueKey('submit_meal_button')).tap();

    await $(const ValueKey('resolver_clarification_card')).waitUntilExists(
      timeout: const Duration(seconds: 120),
    );
    await $(const ValueKey('resolver_clarification_card')).scrollTo();
    expect($(const ValueKey('resolver_clarification_card')), findsOneWidget);
    expect($('Needs a little more detail'), findsOneWidget);
    expect($('Food matches'), findsOneWidget);
  });

  patrolTest('home cleanup keeps dark mode toggle and removed shortcuts absent',
      ($) async {
    await _pumpAndAuthenticate($);

    await $(const ValueKey('nav_home_button')).tap();
    await $(const ValueKey('dark_mode_toggle')).waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );
    expect($(const ValueKey('dark_mode_toggle')), findsOneWidget);
    expect($(const ValueKey('dashboard_progress_card')), findsOneWidget);

    await $(const ValueKey('dark_mode_toggle')).tap();
    await $.pumpAndSettle();

    expect($(const ValueKey('dashboard_progress_card')), findsOneWidget);
    expect($('Log meal'), findsNothing);
    expect($('Calendar'), findsNothing);
    expect($('Notifications'), findsNothing);
    expect($('Exercise'), findsNothing);
    expect($('BPM'), findsNothing);
    expect($('Weight'), findsNothing);
    expect($('Water'), findsNothing);
  });
}

Future<void> _pumpAndAuthenticate(PatrolIntegrationTester $) async {
  await $.pumpWidgetAndSettle(
    const CalTrackerBootstrap(apiConfig: _patrolApiConfig),
  );
  if ($(const ValueKey('meal_text_field')).exists) {
    await _setEnglishLanguage($);
    return;
  }

  final email = 'patrol-${DateTime.now().microsecondsSinceEpoch}@example.com';
  await _registerPatrolUser(email);
  await $(const ValueKey('email_field')).enterText(email);
  await $(const ValueKey('password_field')).enterText('password123');
  FocusManager.instance.primaryFocus?.unfocus();
  await $.pumpAndSettle();
  await $(const ValueKey('auth_submit_button')).scrollTo().tap();
  await $(const ValueKey('meal_text_field')).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
  await _setEnglishLanguage($);
}

Future<void> _setEnglishLanguage(PatrolIntegrationTester $) async {
  await $(const ValueKey('nav_menu_button')).tap();
  await $(const ValueKey('language_settings_row')).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
  await $(const ValueKey('language_settings_row')).tap();
  await $(const ValueKey('language_option_en')).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
  await $(const ValueKey('language_option_en')).tap();
  await $.pumpAndSettle();
  await $(const ValueKey('nav_log_button')).tap();
  await $(const ValueKey('meal_text_field')).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
}

Future<void> _registerPatrolUser(String email) async {
  final response = await http.post(
    Uri.parse('${_patrolApiConfig.baseUrl}/v1/auth/register'),
    headers: const {'content-type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': 'password123',
      'displayName': 'Patrol User',
    }),
  );
  if (response.statusCode != 200 && response.statusCode != 201) {
    throw StateError(
      'Failed to create Patrol user ${response.statusCode}: ${response.body}',
    );
  }
}
