import 'dart:convert';

import 'package:cal_tracker_mobile/app/app.dart';
import 'package:cal_tracker_mobile/data/services/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:patrol/patrol.dart';

const _patrolApiConfig = ApiConfig(baseUrl: 'http://10.0.2.2:3000');

void main() {
  patrolTest('edits a committed history meal with explicit item details',
      ($) async {
    final user = await _createPatrolUser();
    await _seedCommittedMeal(user.accessToken);

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

    await $('Stats').tap();
    await $('Recent meals').waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );
    await $('Patrol breakfast').tap();

    expect($('Correct'), findsNothing);
    await $('Edit ingredients').tap();
    expect($(const ValueKey('history_item_name_0')), findsOneWidget);
    expect($(const ValueKey('meal_correction_field')), findsNothing);

    await $(const ValueKey('history_item_quantity_0')).enterText('120');
    await $(const ValueKey('history_item_calories_0')).enterText('300');
    await $(const ValueKey('save_history_item_edits_button')).scrollTo().tap();

    expect($('443 Kcal'), findsOneWidget);
  });
}

Future<_PatrolUser> _createPatrolUser() async {
  final email = 'history-${DateTime.now().microsecondsSinceEpoch}@example.com';
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
  final body = jsonDecode(response.body) as Map<String, Object?>;
  return _PatrolUser(
    email: email,
    accessToken: body['accessToken'] as String,
  );
}

Future<void> _seedCommittedMeal(String accessToken) async {
  await _executeAction(accessToken, 'create_meal_template', {
    'title': 'Patrol breakfast',
    'trustedAutoCommitEnabled': false,
    'aliases': ['patrol seeded breakfast'],
    'items': _items,
  });
  final created = await _executeAction(accessToken, 'propose_meal_log', {
    'text': 'patrol seeded breakfast',
  });
  final createdProposal = created['proposal'] as Map<String, Object?>;
  final proposalId = createdProposal['id'] as String;
  final response = await _postJson(
    Uri.parse(
        '${_patrolApiConfig.baseUrl}/v1/meals/proposals/$proposalId/commit'),
    headers: {
      'authorization': 'Bearer $accessToken',
      'content-type': 'application/json',
    },
    body: '{}',
  );
  if (response.statusCode != 200) {
    throw StateError(
        'Failed to commit meal ${response.statusCode}: ${response.body}');
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
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      return await http.post(uri, headers: headers, body: body);
    } catch (error) {
      lastError = error;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }
  throw StateError('Failed to POST $uri: $lastError');
}

const _items = [
  {
    'name': 'Bread',
    'quantity': 100,
    'unit': 'g',
    'calories': 265,
    'proteinGrams': 9,
    'carbsGrams': 49,
    'fatGrams': 3.2,
    'source': 'patrol_fixture',
  },
  {
    'name': 'Butter',
    'quantity': 20,
    'unit': 'g',
    'calories': 143,
    'proteinGrams': 0.2,
    'carbsGrams': 0,
    'fatGrams': 16.2,
    'source': 'patrol_fixture',
  },
];

class _PatrolUser {
  const _PatrolUser({
    required this.email,
    required this.accessToken,
  });

  final String email;
  final String accessToken;
}
