import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';

import 'meal_label_helpers.dart';

void main() {
  patrolTest('logs a Dinner meal label', ($) async {
    await runFixedMealLabelScenario(
      $,
      const ValueKey('meal_label_dinner_option'),
      'Dinner',
    );
  });
}
