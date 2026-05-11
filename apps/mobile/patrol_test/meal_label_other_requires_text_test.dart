import 'package:patrol/patrol.dart';

import 'meal_label_helpers.dart';

void main() {
  patrolTest('Other requires text before the meal can be logged', ($) async {
    await runOtherRequiresTextScenario($);
  });
}
