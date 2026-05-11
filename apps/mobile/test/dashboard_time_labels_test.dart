import 'package:cal_tracker_mobile/ui/features/dashboard/dashboard_time_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dashboardGreeting', () {
    test('uses night before 5 AM', () {
      expect(dashboardGreeting(DateTime(2026, 5, 9, 4, 59)), 'Good night!');
    });

    test('uses morning from 5 AM until noon', () {
      expect(dashboardGreeting(DateTime(2026, 5, 9, 5)), 'Good morning!');
      expect(dashboardGreeting(DateTime(2026, 5, 9, 11, 59)), 'Good morning!');
    });

    test('uses afternoon from noon until 6 PM', () {
      expect(dashboardGreeting(DateTime(2026, 5, 9, 12)), 'Good afternoon!');
      expect(
          dashboardGreeting(DateTime(2026, 5, 9, 17, 59)), 'Good afternoon!');
    });

    test('uses night from 6 PM', () {
      expect(dashboardGreeting(DateTime(2026, 5, 9, 18)), 'Good night!');
    });
  });

  test('dashboardDayMonthLabel formats day and short month', () {
    expect(dashboardDayMonthLabel(DateTime(2026, 5, 9)), '9 May');
  });
}
