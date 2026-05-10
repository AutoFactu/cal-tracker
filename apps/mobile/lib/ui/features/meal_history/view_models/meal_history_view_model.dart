import 'package:flutter/foundation.dart';

import '../../../../data/repositories/nutrition_repository.dart';
import '../../../../domain/models/nutrition_models.dart';

class MealHistoryViewModel extends ChangeNotifier {
  MealHistoryViewModel({
    required NutritionRepository nutritionRepository,
    Duration cacheTtl = const Duration(seconds: 60),
    DateTime Function()? now,
  })  : _nutritionRepository = nutritionRepository,
        _cacheTtl = cacheTtl,
        _now = now ?? DateTime.now;

  final NutritionRepository _nutritionRepository;
  final Duration _cacheTtl;
  final DateTime Function() _now;
  List<Meal> _meals = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  DateTime? _lastLoadedAt;
  Future<void>? _loadOperation;
  String? _error;

  List<Meal> get meals => _meals;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load({bool forceRefresh = false}) {
    final isCacheFresh =
        _lastLoadedAt != null && _now().difference(_lastLoadedAt!) < _cacheTtl;
    if (!forceRefresh && _hasLoaded && isCacheFresh) {
      return Future.value();
    }
    if (_loadOperation != null) return _loadOperation!;

    final showLoading = forceRefresh || !_hasLoaded;
    _loadOperation = _load(showLoading: showLoading).whenComplete(() {
      _loadOperation = null;
    });
    return _loadOperation!;
  }

  Future<void> _load({required bool showLoading}) async {
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      _meals = await _nutritionRepository.getMealHistory();
      _hasLoaded = true;
      _lastLoadedAt = _now();
      _error = null;
    } catch (error) {
      if (showLoading) {
        _error = error.toString();
      }
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> correctMealItems(Meal meal, List<MealItem> items) async {
    _isLoading = true;
    notifyListeners();
    try {
      final corrected =
          await _nutritionRepository.correctMealItems(meal.id, items);
      _meals = _meals
          .map((item) => item.id == corrected.id ? corrected : item)
          .toList();
      _hasLoaded = true;
      _lastLoadedAt = _now();
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
        _meals = _meals.where((item) => item.id != meal.id).toList();
      }
      _hasLoaded = true;
      _lastLoadedAt = _now();
      _error = null;
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
