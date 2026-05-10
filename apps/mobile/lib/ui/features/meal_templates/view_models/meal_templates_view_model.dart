import 'package:flutter/foundation.dart';

import '../../../../data/repositories/nutrition_repository.dart';
import '../../../../domain/models/nutrition_models.dart';

class MealTemplatesViewModel extends ChangeNotifier {
  MealTemplatesViewModel({required NutritionRepository nutritionRepository})
      : _nutritionRepository = nutritionRepository;

  final NutritionRepository _nutritionRepository;
  List<MealTemplate> _templates = const [];
  bool _isLoading = false;
  String? _error;

  List<MealTemplate> get templates => _templates;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _templates = await _nutritionRepository.getTemplates();
      _error = null;
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setTrustedMode(MealTemplate template, bool enabled) async {
    final updated =
        await _nutritionRepository.setTemplateTrustedMode(template, enabled);
    _templates = _templates
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
    notifyListeners();
  }

  Future<void> createBasicTemplate(
      {required String title, required List<String> aliases}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final template = await _nutritionRepository.createTemplate(
        title: title,
        aliases: aliases,
        items: const [
          MealItem(
            name: 'Chicken breast',
            quantity: 150,
            unit: 'g',
            calories: 248,
            proteinGrams: 46.5,
            carbsGrams: 0,
            fatGrams: 5.4,
            source: 'manual',
          ),
          MealItem(
            name: 'Cooked rice',
            quantity: 150,
            unit: 'g',
            calories: 195,
            proteinGrams: 4.1,
            carbsGrams: 42,
            fatGrams: 0.5,
            source: 'manual',
          ),
        ],
      );
      _templates = [..._templates, template];
      _error = null;
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteTemplate(MealTemplate template) async {
    _isLoading = true;
    notifyListeners();
    try {
      final deleted = await _nutritionRepository.deleteTemplate(template.id);
      if (deleted) {
        _templates =
            _templates.where((item) => item.id != template.id).toList();
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
