import 'package:flutter/foundation.dart';

import '../../../../data/repositories/nutrition_repository.dart';
import '../../../../domain/models/nutrition_models.dart';

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({required NutritionRepository nutritionRepository}) : _nutritionRepository = nutritionRepository;

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
}
