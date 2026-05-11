import 'package:patrol/patrol.dart';

import 'meal_label_helpers.dart';

void main() {
  patrolTest('logs a user-named Other meal label', ($) async {
    await runOtherMealLabelScenario($);
  });
}
