import 'package:flutter/foundation.dart';

import '../../../../data/repositories/nutrition_repository.dart';
import '../../../../domain/models/nutrition_models.dart';

class MealHistoryViewModel extends ChangeNotifier {
  MealHistoryViewModel({required NutritionRepository nutritionRepository}) : _nutritionRepository = nutritionRepository;

  final NutritionRepository _nutritionRepository;
  List<Meal> _meals = const [];
  bool _isLoading = false;
  String? _error;

  List<Meal> get meals => _meals;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _meals = await _nutritionRepository.getMealHistory();
      _error = null;
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> correctMeal(Meal meal, String correctionText) async {
    _isLoading = true;
    notifyListeners();
    try {
      final corrected = await _nutritionRepository.correctMeal(meal.id, correctionText);
      _meals = _meals.map((item) => item.id == corrected.id ? corrected : item).toList();
      _error = null;
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteMeal(Meal meal) async {
    _isLoading = true;
    notifyListeners();
    try {
      final deleted = await _nutritionRepository.deleteMeal(meal.id, confirmed: true);
      if (deleted) {
        _meals = _meals.where((item) => item.id != meal.id).toList();
      }
      _error = null;
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
