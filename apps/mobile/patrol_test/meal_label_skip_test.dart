import 'package:patrol/patrol.dart';

import 'meal_label_helpers.dart';

void main() {
  patrolTest('skips meal labeling and shows no Home label chip', ($) async {
    await runSkipMealLabelScenario($);
  });
}
