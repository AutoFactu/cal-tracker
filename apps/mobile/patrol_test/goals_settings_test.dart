import 'dart:convert';

import 'package:cal_tracker_mobile/app/app.dart';
import 'package:cal_tracker_mobile/data/services/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:patrol/patrol.dart';

const _patrolApiConfig = ApiConfig(baseUrl: 'http://10.0.2.2:3000');

void main() {
  patrolTest('edits goals from Menu and updates Home immediately', ($) async {
    final user = await _createPatrolUser('goals-menu');
    await _login($, user);

    await $('Menu').tap();
    await $(const ValueKey('calorie_target_row')).waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );

    await $(const ValueKey('calorie_target_row')).tap();
    await $(const ValueKey('calorie_target_field')).enterText('2300');
    await $(const ValueKey('save_goal_button')).scrollTo().tap();
    await $('2300 Kcal daily target').waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );

    await $(const ValueKey('hydration_goal_row')).tap();
    await $(const ValueKey('hydration_goal_field')).enterText('15');
    await $(const ValueKey('save_goal_button')).scrollTo().tap();
    await $('15 glasses per day').waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );

    await $('Home').tap();
    await $('Target 2300 Kcal, 15 glasses').waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );
  });

  patrolTest('shows the same target calories on Home and Stats', ($) async {
    final user = await _createPatrolUser('goals-consistency');
    final today = _formatDateOnly(DateTime.now());
    await _putGoals(
      accessToken: user.accessToken,
      date: today,
      calories: 2450,
      hydrationGoalGlasses: 13,
    );
    await _login($, user);

    await $('Home').tap();
    await $('Target 2450 Kcal, 13 glasses').waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );

    await $('Stats').tap();
    await $('Target: 2450 Kcal').waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );
  });

  patrolTest('keeps previous day target after today target changes', ($) async {
    final user = await _createPatrolUser('goals-history');
    final today = DateTime.now();
    final previous = today.subtract(const Duration(days: 1));
    final todayDate = _formatDateOnly(today);
    final previousDate = _formatDateOnly(previous);

    await _putGoals(
      accessToken: user.accessToken,
      date: previousDate,
      calories: 1800,
      hydrationGoalGlasses: 10,
    );
    await _getDailySummary(user.accessToken, previousDate);
    await _seedCommittedMeal(
      accessToken: user.accessToken,
      title: 'Previous target meal',
      occurredAt: '${previousDate}T12:00:00.000Z',
      calories: 360,
    );
    await _seedCommittedMeal(
      accessToken: user.accessToken,
      title: 'Today target meal',
      occurredAt: '${todayDate}T12:00:00.000Z',
      calories: 420,
    );
    await _putGoals(
      accessToken: user.accessToken,
      date: todayDate,
      calories: 2400,
      hydrationGoalGlasses: 14,
    );

    await _login($, user);
    await $('Stats').tap();
    await $('Target: 2400 Kcal').waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );
    await $('Logged meals').waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );
    expect($('Today target meal'), findsWidgets);

    await $(ValueKey('stats_day_$previousDate')).tap();
    await $('Target: 1800 Kcal').waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );
    expect($('Previous target meal'), findsWidgets);
    expect($('Today target meal'), findsNothing);
  });
}

Future<void> _login(PatrolIntegrationTester $, _PatrolUser user) async {
  await $.pumpWidgetAndSettle(
    const CalTrackerBootstrap(apiConfig: _patrolApiConfig),
  );
  await $(const ValueKey('email_field')).enterText(user.email);
  await $(const ValueKey('password_field')).enterText('password123');
  FocusManager.instance.primaryFocus?.unfocus();
  await $.pumpAndSettle();
  await $(const ValueKey('auth_submit_button')).scrollTo().tap();
  await $(const ValueKey('meal_text_field')).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
}

Future<_PatrolUser> _createPatrolUser(String prefix) async {
  final email = '$prefix-${DateTime.now().microsecondsSinceEpoch}@example.com';
  final response = await _postJson(
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
  final body = jsonDecode(response.body) as Map<String, Object?>;
  return _PatrolUser(
    email: email,
    accessToken: body['accessToken'] as String,
  );
}

Future<void> _putGoals({
  required String accessToken,
  required String date,
  required int calories,
  required int hydrationGoalGlasses,
}) async {
  final response = await http.put(
    Uri.parse('${_patrolApiConfig.baseUrl}/v1/goals'),
    headers: {
      'authorization': 'Bearer $accessToken',
      'content-type': 'application/json',
    },
    body: jsonEncode({
      'date': date,
      'calories': calories,
      'hydrationGoalGlasses': hydrationGoalGlasses,
    }),
  );
  if (response.statusCode != 200) {
    throw StateError(
      'Failed to update goals ${response.statusCode}: ${response.body}',
    );
  }
}

Future<void> _getDailySummary(String accessToken, String date) async {
  final response = await http.get(
    Uri.parse('${_patrolApiConfig.baseUrl}/v1/summary/daily?date=$date'),
    headers: {'authorization': 'Bearer $accessToken'},
  );
  if (response.statusCode != 200) {
    throw StateError(
      'Failed to fetch summary ${response.statusCode}: ${response.body}',
    );
  }
}

Future<void> _seedCommittedMeal({
  required String accessToken,
  required String title,
  required String occurredAt,
  required int calories,
}) async {
  final created =
      await _executeAction(accessToken, 'create_meal_proposal_from_items', {
    'phrase': title,
    'title': title,
    'items': [
      {
        'name': title,
        'quantity': 1,
        'unit': 'serving',
        'calories': calories,
        'proteinGrams': 10,
        'carbsGrams': 30,
        'fatGrams': 8,
        'source': 'patrol_fixture',
      }
    ],
  });
  final proposal = created['proposal'] as Map<String, Object?>;
  final response = await _postJson(
    Uri.parse(
      '${_patrolApiConfig.baseUrl}/v1/meals/proposals/${proposal['id']}/commit',
    ),
    headers: {
      'authorization': 'Bearer $accessToken',
      'content-type': 'application/json',
    },
    body: jsonEncode({'occurredAt': occurredAt}),
  );
  if (response.statusCode != 200) {
    throw StateError(
      'Failed to commit meal ${response.statusCode}: ${response.body}',
    );
  }
}

Future<Map<String, Object?>> _executeAction(
  String accessToken,
  String actionId,
  Map<String, Object?> input,
) async {
  final response = await _postJson(
    Uri.parse('${_patrolApiConfig.baseUrl}/v1/actions/$actionId/execute'),
    headers: {
      'authorization': 'Bearer $accessToken',
      'content-type': 'application/json',
    },
    body: jsonEncode({'input': input, 'source': 'flutter'}),
  );
  if (response.statusCode != 200) {
    throw StateError(
      'Failed to execute $actionId ${response.statusCode}: ${response.body}',
    );
  }
  final body = jsonDecode(response.body) as Map<String, Object?>;
  return body['output'] as Map<String, Object?>;
}

Future<http.Response> _postJson(
  Uri uri, {
  required Map<String, String> headers,
  required Object body,
}) async {
  Object? lastError;
  for (var attempt = 0; attempt < 8; attempt++) {
    try {
      return await http.post(uri, headers: headers, body: body);
    } catch (error) {
      lastError = error;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }
  throw StateError('Failed to POST $uri: $lastError');
}

String _formatDateOnly(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class _PatrolUser {
  const _PatrolUser({
    required this.email,
    required this.accessToken,
  });

  final String email;
  final String accessToken;
}
