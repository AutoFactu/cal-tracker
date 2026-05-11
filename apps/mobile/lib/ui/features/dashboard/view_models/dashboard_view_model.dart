import 'package:flutter/foundation.dart';

import '../../../../data/repositories/nutrition_repository.dart';
import '../../../../domain/models/nutrition_models.dart';

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({required NutritionRepository nutritionRepository})
      : _nutritionRepository = nutritionRepository;

  final NutritionRepository _nutritionRepository;
  DailySummary? _summary;
  bool _isLoading = false;
  String? _error;

  DailySummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _summary = await _nutritionRepository.getDailySummary();
      _error = null;
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> correctMealItems(Meal meal, List<MealItem> items) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _nutritionRepository.correctMealItems(meal.id, items);
      _summary = await _nutritionRepository.getDailySummary();
      _error = null;
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateCalorieTarget(int calories,
      {String source = 'manual'}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _nutritionRepository.updateDailyGoals(
        calories: calories,
        calorieTargetSource: source,
      );
      _summary = await _nutritionRepository.getDailySummary();
      _error = null;
      return true;
    } catch (error) {
      _error = error.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CalorieEstimate> estimateCalories({
    required int age,
    required String sex,
    required double heightCm,
    required double weightKg,
    required String activityLevel,
    required String goal,
    String? pace,
  }) {
    return _nutritionRepository.estimateCalories(
      age: age,
      sex: sex,
      heightCm: heightCm,
      weightKg: weightKg,
      activityLevel: activityLevel,
      goal: goal,
      pace: pace,
    );
  }
}
