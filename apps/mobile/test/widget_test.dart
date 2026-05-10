import 'package:cal_tracker_mobile/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('shows auth screen before a stored session exists',
      (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    await tester.pumpWidget(const CalTrackerBootstrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Better Calories'), findsOneWidget);
    expect(find.byKey(const ValueKey('email_field')), findsOneWidget);
  });
}
