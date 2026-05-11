import 'dart:convert';

import 'package:cal_tracker_mobile/app/app.dart';
import 'package:cal_tracker_mobile/data/services/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:patrol/patrol.dart';

const _patrolApiConfig = ApiConfig(baseUrl: 'http://10.0.2.2:3000');

const _scenarios = [
  _MealScenario(
    name: 'bread',
    input: 'Añade 100 gramos de pan.',
    expectedTerms: ['Bread'],
  ),
];

void main() {
  for (final scenario in _scenarios) {
    patrolTest('logs Spanish ${scenario.name} meal', ($) async {
      await _pumpAndAuthenticate($);

      await $(const ValueKey('meal_text_field')).enterText(scenario.input);
      await $(const ValueKey('submit_meal_button')).tap();

      await $(const ValueKey('confirm_proposal_button')).waitUntilExists(
        timeout: const Duration(seconds: 120),
      );
      await $(const ValueKey('confirm_proposal_button')).scrollTo();
      expect(find.text('Needs a little more detail'), findsNothing);
      for (final term in scenario.expectedTerms) {
        expect(find.textContaining(term, findRichText: true), findsWidgets);
      }
    });
  }
}

class _MealScenario {
  const _MealScenario({
    required this.name,
    required this.input,
    required this.expectedTerms,
  });

  final String name;
  final String input;
  final List<String> expectedTerms;
}

Future<void> _pumpAndAuthenticate(PatrolIntegrationTester $) async {
  await $.pumpWidgetAndSettle(
    const CalTrackerBootstrap(apiConfig: _patrolApiConfig),
  );
  if ($(const ValueKey('meal_text_field')).exists) return;

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
