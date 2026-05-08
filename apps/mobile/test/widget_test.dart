import 'package:cal_tracker_mobile/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows auth screen before a stored session exists', (tester) async {
    await tester.pumpWidget(const CalTrackerBootstrap());
    await tester.pump();

    expect(find.text('Cal Tracker'), findsOneWidget);
    expect(find.byKey(const ValueKey('email_field')), findsOneWidget);
  });
}
