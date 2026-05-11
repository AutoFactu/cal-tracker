import 'dart:convert';

import 'package:cal_tracker_mobile/app/app.dart';
import 'package:cal_tracker_mobile/data/services/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:patrol/patrol.dart';

const patrolApiConfig = ApiConfig(baseUrl: 'http://10.0.2.2:3000');

Future<void> runFixedMealLabelScenario(
  PatrolIntegrationTester $,
  ValueKey<String> optionKey,
  String expectedLabel,
) async {
  await pumpAndAuthenticate($);
  await submitBreadProposal($);
  await chooseFixedLabel($, optionKey);
  await expectLoggedMealOnHome($, expectedLabel);
}

Future<void> runOtherMealLabelScenario(PatrolIntegrationTester $) async {
  await pumpAndAuthenticate($);
  await submitBreadProposal($);

  await $(const ValueKey('confirm_proposal_button')).scrollTo().tap();
  await $(const ValueKey('meal_label_sheet')).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
  await $(const ValueKey('meal_label_other_option')).tap();
  await $(const ValueKey('meal_label_other_field')).enterText('Brunch');
  await $(const ValueKey('meal_label_other_save_button')).tap();

  await expectLoggedMealOnHome($, 'Brunch');
}

Future<void> runSkipMealLabelScenario(PatrolIntegrationTester $) async {
  await pumpAndAuthenticate($);
  await submitBreadProposal($);

  await $(const ValueKey('confirm_proposal_button')).scrollTo().tap();
  await $(const ValueKey('meal_label_sheet')).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
  await $(const ValueKey('meal_label_skip_button')).tap();
  await $('Logged. You can correct it from history.').waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );

  await $('Home').tap();
  await $(const ValueKey('dashboard_progress_card')).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
  expect(find.textContaining('Bread', findRichText: true), findsWidgets);
  expect($('Breakfast'), findsNothing);
  expect($('Lunch'), findsNothing);
  expect($('Dinner'), findsNothing);
  expect($('Snack'), findsNothing);
  expect($('Pre-workout'), findsNothing);
  expect($('Post-workout'), findsNothing);
  expect($('Brunch'), findsNothing);
}

Future<void> runOtherRequiresTextScenario(PatrolIntegrationTester $) async {
  await pumpAndAuthenticate($);
  await submitBreadProposal($);

  await $(const ValueKey('confirm_proposal_button')).scrollTo().tap();
  await $(const ValueKey('meal_label_sheet')).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
  await $(const ValueKey('meal_label_other_option')).tap();
  expect($(const ValueKey('meal_label_other_field')), findsOneWidget);
  expect($('Logged. You can correct it from history.'), findsNothing);
}

Future<void> runCancelMealLabelScenario(PatrolIntegrationTester $) async {
  await pumpAndAuthenticate($);
  await submitBreadProposal($);

  await $(const ValueKey('confirm_proposal_button')).scrollTo().tap();
  await $(const ValueKey('meal_label_sheet')).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
  await $(const ValueKey('meal_label_cancel_button')).tap();
  await $.pumpAndSettle();

  expect($(const ValueKey('confirm_proposal_button')), findsOneWidget);
  expect($('Logged. You can correct it from history.'), findsNothing);

  await $(const ValueKey('confirm_proposal_button')).scrollTo().tap();
  await $(const ValueKey('meal_label_breakfast_option')).tap();
  await expectLoggedMealOnHome($, 'Breakfast');
}

Future<void> runEditPreservesMealLabelScenario(
  PatrolIntegrationTester $,
) async {
  await pumpAndAuthenticate($);
  await submitBreadProposal($);
  await chooseFixedLabel($, const ValueKey('meal_label_breakfast_option'));
  await expectLoggedMealOnHome($, 'Breakfast');

  await $(find.byTooltip('Edit ingredients')).tap();
  await $('Edit ingredients').waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
  await $(const ValueKey('dashboard_item_calories_0')).enterText('300');
  await $(const ValueKey('save_dashboard_item_edits_button')).scrollTo().tap();
  await $(const ValueKey('dashboard_progress_card')).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );

  expect(find.textContaining('Bread', findRichText: true), findsWidgets);
}

Future<void> pumpAndAuthenticate(PatrolIntegrationTester $) async {
  await $.pumpWidgetAndSettle(
    const CalTrackerBootstrap(apiConfig: patrolApiConfig),
  );
  if ($(const ValueKey('meal_text_field')).exists) {
    await ensureEnglishLanguage($);
    return;
  }

  final email = 'label-${DateTime.now().microsecondsSinceEpoch}@example.com';
  await registerPatrolUser(email);
  await $(const ValueKey('email_field')).enterText(email);
  await $(const ValueKey('password_field')).enterText('password123');
  FocusManager.instance.primaryFocus?.unfocus();
  await $.pumpAndSettle();
  await $(const ValueKey('auth_submit_button')).scrollTo().tap();
  await $(const ValueKey('meal_text_field')).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
  await ensureEnglishLanguage($);
}

Future<void> ensureEnglishLanguage(PatrolIntegrationTester $) async {
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

Future<void> submitBreadProposal(PatrolIntegrationTester $) async {
  await $(const ValueKey('meal_text_field')).scrollTo();
  await $(const ValueKey('meal_text_field')).enterText(
    'Add 100 grams of bread.',
  );
  await $(const ValueKey('submit_meal_button')).tap();
  await $(const ValueKey('confirm_proposal_button')).waitUntilExists(
    timeout: const Duration(seconds: 120),
  );
  expect(find.textContaining('Bread', findRichText: true), findsWidgets);
}

Future<void> chooseFixedLabel(
  PatrolIntegrationTester $,
  ValueKey<String> optionKey,
) async {
  await $(const ValueKey('confirm_proposal_button')).scrollTo().tap();
  await $(const ValueKey('meal_label_sheet')).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
  await $(optionKey).tap();
}

Future<void> expectLoggedMealOnHome(
  PatrolIntegrationTester $,
  String label,
) async {
  await $.pumpAndSettle();
  await $('Home').tap();
  await $(const ValueKey('dashboard_progress_card')).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
  expect(find.textContaining('Bread', findRichText: true), findsWidgets);
}

Future<void> registerPatrolUser(String email) async {
  final response = await http.post(
    Uri.parse('${patrolApiConfig.baseUrl}/v1/auth/register'),
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
