import 'package:patrol/patrol.dart';

import 'meal_label_helpers.dart';

void main() {
  patrolTest('canceling meal label selection keeps proposal uncommitted',
      ($) async {
    await runCancelMealLabelScenario($);
  });
}
