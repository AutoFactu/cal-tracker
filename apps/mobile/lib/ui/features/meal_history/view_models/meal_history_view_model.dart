import 'package:flutter/foundation.dart';

import '../../../../data/repositories/nutrition_repository.dart';
import '../../../../domain/models/nutrition_models.dart';

class MealHistoryViewModel extends ChangeNotifier {
  MealHistoryViewModel({required NutritionRepository nutritionRepository})
      : _nutritionRepository = nutritionRepository;

  final NutritionRepository _nutritionRepository;
  List<DailySummary> _weekSummaries = const [];
  String _selectedDate = _formatDateOnly(DateTime.now());
  bool _isLoading = false;
  String? _error;

  List<DailySummary> get weekSummaries => _weekSummaries;
  String get selectedDate => _selectedDate;
  DailySummary? get selectedSummary {
    for (final summary in _weekSummaries) {
      if (summary.date == _selectedDate) return summary;
    }
    return _weekSummaries.isEmpty ? null : _weekSummaries.last;
  }

  List<Meal> get meals => selectedSummary?.meals ?? const [];
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _weekSummaries = await Future.wait(
        _weekDates(DateTime.now()).map(
          (date) => _nutritionRepository.getDailySummary(
            date: _formatDateOnly(date),
          ),
        ),
      );
      if (!_weekSummaries.any((summary) => summary.date == _selectedDate)) {
        _selectedDate = _formatDateOnly(DateTime.now());
      }
      _error = null;
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectDate(String date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> correctMealItems(Meal meal, List<MealItem> items) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _nutritionRepository.correctMealItems(meal.id, items);
      _weekSummaries = await Future.wait(
        _weekDates(DateTime.now()).map(
          (date) => _nutritionRepository.getDailySummary(
            date: _formatDateOnly(date),
          ),
        ),
      );
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
      final deleted =
          await _nutritionRepository.deleteMeal(meal.id, confirmed: true);
      if (deleted) {
        _weekSummaries = await Future.wait(
          _weekDates(DateTime.now()).map(
            (date) => _nutritionRepository.getDailySummary(
              date: _formatDateOnly(date),
            ),
          ),
        );
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

List<DateTime> _weekDates(DateTime anchor) {
  final today = DateTime(anchor.year, anchor.month, anchor.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  return List.generate(7, (index) => monday.add(Duration(days: index)));
}

String _formatDateOnly(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
