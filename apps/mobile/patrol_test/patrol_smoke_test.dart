import 'dart:convert';

import 'package:cal_tracker_mobile/app/app.dart';
import 'package:cal_tracker_mobile/data/services/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
    expect($(const ValueKey('google_sign_in_button')), findsOneWidget);
  });

  patrolTest('switches main tabs through the shell navigation', ($) async {
    await _pumpAndAuthenticate($, openMealCreate: false);

    await $(const ValueKey('main_nav_stats')).tap();
    await $.pumpAndSettle();
    expect($('Statistic'), findsOneWidget);

    await $(const ValueKey('main_nav_usual')).tap();
    await $.pumpAndSettle();
    expect($('Usual meals'), findsOneWidget);

    await $(const ValueKey('main_nav_menu')).tap();
    await $.pumpAndSettle();
    expect($('Account and preferences'), findsOneWidget);

    await $(const ValueKey('main_nav_home')).tap();
    await $.pumpAndSettle();
    expect($(const ValueKey('dashboard_progress_card')), findsOneWidget);
  }, tags: 'navigation');

  patrolTest('logs a Spanish bread and butter meal through the agent',
      ($) async {
    await _pumpAndAuthenticate($);

    await $(const ValueKey('meal_text_field')).enterText(
      'quiero añadir un desayuno de 100g de pan y 20g de mantequilla',
    );
    await $(const ValueKey('submit_meal_button')).tap();

    expect($('Bread and Butter'), findsOneWidget);
    await $(const ValueKey('confirm_proposal_button')).scrollTo().tap();

    expect($('Logged. You can correct it from history.'), findsOneWidget);
    expect($('Bread and Butter'), findsOneWidget);
  });

  patrolTest('logs a Spanish bread and ham meal through the agent', ($) async {
    await _pumpAndAuthenticate($);

    await $(const ValueKey('meal_text_field')).enterText(
      'Añade a mi desayuno 100 gramos de pan y 100 gramos de jamón.',
    );
    await $(const ValueKey('submit_meal_button')).tap();

    expect($('Bread and Ham'), findsOneWidget);
    expect($('Bread 100 g'), findsOneWidget);
    expect($('Ham 100 g'), findsOneWidget);
  });

  patrolTest('preserves Spanish meat and rice quantities and opens editor',
      ($) async {
    await _pumpAndAuthenticate($);

    await $(const ValueKey('meal_text_field')).enterText(
      'Añada al almuerzo 100 gramos de carne y 100 gramos de arroz',
    );
    await $(const ValueKey('submit_meal_button')).tap();

    expect($('Chicken breast and Cooked rice'), findsOneWidget);
    expect($('Chicken breast 100 g'), findsOneWidget);
    expect($('Cooked rice 100 g'), findsOneWidget);

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

    await $(const ValueKey('resolver_clarification_card')).scrollTo();
    expect($(const ValueKey('resolver_clarification_card')), findsOneWidget);
    expect($('Needs a little more detail'), findsOneWidget);
    expect($('Food matches'), findsOneWidget);
  });
}

Future<void> _pumpAndAuthenticate(
  PatrolIntegrationTester $, {
  bool openMealCreate = true,
}) async {
  await $.pumpWidgetAndSettle(
    const CalTrackerBootstrap(apiConfig: _patrolApiConfig),
  );
  if ($(const ValueKey('meal_text_field')).exists) return;

  if (!$(const ValueKey('dashboard_progress_card')).exists) {
    final email = 'patrol-${DateTime.now().microsecondsSinceEpoch}@example.com';
    await _registerPatrolUser(email);
    await $(const ValueKey('email_field')).enterText(email);
    await $(const ValueKey('password_field')).enterText('password123');
    FocusManager.instance.primaryFocus?.unfocus();
    await $.pumpAndSettle();
    await $(const ValueKey('auth_submit_button')).scrollTo().tap();
    await $(const ValueKey('dashboard_progress_card')).waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );
  }

  if (openMealCreate) {
    await _openMealCreate($);
  }
}

Future<void> _openMealCreate(PatrolIntegrationTester $) async {
  if ($(const ValueKey('meal_text_field')).exists) return;
  final context = $.tester.element(
    find.byKey(const ValueKey('dashboard_progress_card')),
  );
  GoRouter.of(context).go('/meal/create');
  await $.pumpAndSettle();
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
