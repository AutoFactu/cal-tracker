import 'dart:convert';

import 'package:cal_tracker_mobile/app/app.dart';
import 'package:cal_tracker_mobile/data/services/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:patrol/patrol.dart';

const _patrolApiConfig = ApiConfig(baseUrl: 'http://10.0.2.2:3000');

void main() {
  patrolTest('creates a stable text meal proposal', ($) async {
    await _pumpAndAuthenticate($);
    await _submitMealText($, 'Add 100 grams of bread.');
    await $(const ValueKey('confirm_proposal_button')).waitUntilExists(
      timeout: const Duration(seconds: 120),
    );
    expect(find.textContaining('Bread', findRichText: true), findsWidgets);
  });
}

Future<void> _pumpAndAuthenticate(PatrolIntegrationTester $) async {
  await $.pumpWidgetAndSettle(
    const CalTrackerBootstrap(apiConfig: _patrolApiConfig),
  );
  if ($(const ValueKey('meal_text_field')).exists) return;

  final email =
      'patrol-portions-${DateTime.now().microsecondsSinceEpoch}@example.com';
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

Future<void> _submitMealText(PatrolIntegrationTester $, String text) async {
  await $(const ValueKey('meal_text_field')).scrollTo();
  await $(const ValueKey('meal_text_field')).enterText(text);
  await $(const ValueKey('submit_meal_button')).tap();
}

Future<void> _registerPatrolUser(String email) async {
  final response = await http.post(
    Uri.parse('${_patrolApiConfig.baseUrl}/v1/auth/register'),
    headers: const {'content-type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': 'password123',
      'displayName': 'Patrol Portion User',
    }),
  );
  if (response.statusCode != 200 && response.statusCode != 201) {
    throw StateError(
      'Failed to create Patrol user ${response.statusCode}: ${response.body}',
    );
  }
}
