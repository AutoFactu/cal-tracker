import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';

import 'meal_label_helpers.dart';

void main() {
  patrolTest('logs a Snack meal label', ($) async {
    await runFixedMealLabelScenario(
      $,
      const ValueKey('meal_label_snack_option'),
      'Snack',
    );
  });
}
