import 'package:patrol/patrol.dart';

import 'meal_label_helpers.dart';

void main() {
  patrolTest('editing a labeled Home meal preserves its label', ($) async {
    await runEditPreservesMealLabelScenario($);
  });
}
