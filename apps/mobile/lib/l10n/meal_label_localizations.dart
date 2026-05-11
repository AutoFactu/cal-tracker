import '../domain/models/nutrition_models.dart';
import 'generated/app_localizations.dart';

String localizedMealLabel(AppLocalizations l10n, MealLabel label) {
  return switch (label.type) {
    'breakfast' => l10n.mealLabelBreakfast,
    'lunch' => l10n.mealLabelLunch,
    'dinner' => l10n.mealLabelDinner,
    'snack' => l10n.mealLabelSnack,
    'pre_workout' => l10n.mealLabelPreWorkout,
    'post_workout' => l10n.mealLabelPostWorkout,
    'other' => label.label,
    _ => label.label,
  };
}
