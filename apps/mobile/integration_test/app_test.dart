import 'package:cal_tracker_mobile/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login screen accepts text input', (tester) async {
    await tester.pumpWidget(const CalTrackerBootstrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('email_field')), 'test@example.com');
    await tester.enterText(find.byKey(const ValueKey('password_field')), 'password123');

    expect(find.byKey(const ValueKey('auth_submit_button')), findsOneWidget);
  });
}
