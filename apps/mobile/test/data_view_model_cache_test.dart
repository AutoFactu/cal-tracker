import 'dart:async';

import 'package:cal_tracker_mobile/data/repositories/nutrition_repository.dart';
import 'package:cal_tracker_mobile/domain/models/nutrition_models.dart';
import 'package:cal_tracker_mobile/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:cal_tracker_mobile/ui/features/meal_history/view_models/meal_history_view_model.dart';
import 'package:cal_tracker_mobile/ui/features/meal_templates/view_models/meal_templates_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNutritionRepository extends Mock implements NutritionRepository {}

void main() {
  group('DashboardViewModel cache', () {
    late MockNutritionRepository repository;
    late DateTime now;
    late DashboardViewModel viewModel;

    setUp(() {
      repository = MockNutritionRepository();
      now = DateTime(2026, 5, 10, 10);
      viewModel = DashboardViewModel(
        nutritionRepository: repository,
        now: () => now,
      );
    });

    test('loads once while cache is fresh', () async {
      when(() => repository.getDailySummary())
          .thenAnswer((_) async => _summary('2026-05-10'));

      await viewModel.load();
      await viewModel.load();

      verify(() => repository.getDailySummary()).called(1);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.summary?.date, '2026-05-10');
    });

    test('force refresh bypasses cache and shows loading', () async {
      when(() => repository.getDailySummary())
          .thenAnswer((_) async => _summary('2026-05-10'));
      await viewModel.load();

      final completer = Completer<DailySummary>();
      when(() => repository.getDailySummary()).thenAnswer(
        (_) => completer.future,
      );

      final refresh = viewModel.load(forceRefresh: true);
      expect(viewModel.isLoading, isTrue);

      completer.complete(_summary('2026-05-11'));
      await refresh;

      verify(() => repository.getDailySummary()).called(2);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.summary?.date, '2026-05-11');
    });

    test('expired cache refreshes silently', () async {
      when(() => repository.getDailySummary())
          .thenAnswer((_) async => _summary('2026-05-10'));
      await viewModel.load();
      now = now.add(const Duration(seconds: 61));

      final completer = Completer<DailySummary>();
      when(() => repository.getDailySummary()).thenAnswer(
        (_) => completer.future,
      );

      final refresh = viewModel.load();
      expect(viewModel.isLoading, isFalse);

      completer.complete(_summary('2026-05-11'));
      await refresh;

      verify(() => repository.getDailySummary()).called(2);
      expect(viewModel.summary?.date, '2026-05-11');
    });
  });

  group('MealHistoryViewModel cache', () {
    late MockNutritionRepository repository;
    late DateTime now;
    late MealHistoryViewModel viewModel;

    setUp(() {
      repository = MockNutritionRepository();
      now = DateTime(2026, 5, 10, 10);
      viewModel = MealHistoryViewModel(
        nutritionRepository: repository,
        now: () => now,
      );
    });

    test('loads once while cache is fresh', () async {
      when(() => repository.getMealHistory())
          .thenAnswer((_) async => [_meal('meal-1')]);

      await viewModel.load();
      await viewModel.load();

      verify(() => repository.getMealHistory()).called(1);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.meals, hasLength(1));
    });

    test('force refresh bypasses cache and shows loading', () async {
      when(() => repository.getMealHistory())
          .thenAnswer((_) async => [_meal('meal-1')]);
      await viewModel.load();

      final completer = Completer<List<Meal>>();
      when(() => repository.getMealHistory()).thenAnswer(
        (_) => completer.future,
      );

      final refresh = viewModel.load(forceRefresh: true);
      expect(viewModel.isLoading, isTrue);

      completer.complete([_meal('meal-2')]);
      await refresh;

      verify(() => repository.getMealHistory()).called(2);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.meals.single.id, 'meal-2');
    });

    test('expired cache refreshes silently', () async {
      when(() => repository.getMealHistory())
          .thenAnswer((_) async => [_meal('meal-1')]);
      await viewModel.load();
      now = now.add(const Duration(seconds: 61));

      final completer = Completer<List<Meal>>();
      when(() => repository.getMealHistory()).thenAnswer(
        (_) => completer.future,
      );

      final refresh = viewModel.load();
      expect(viewModel.isLoading, isFalse);

      completer.complete([_meal('meal-2')]);
      await refresh;

      verify(() => repository.getMealHistory()).called(2);
      expect(viewModel.meals.single.id, 'meal-2');
    });
  });

  group('MealTemplatesViewModel cache', () {
    late MockNutritionRepository repository;
    late DateTime now;
    late MealTemplatesViewModel viewModel;

    setUp(() {
      repository = MockNutritionRepository();
      now = DateTime(2026, 5, 10, 10);
      viewModel = MealTemplatesViewModel(
        nutritionRepository: repository,
        now: () => now,
      );
    });

    test('loads once while cache is fresh', () async {
      when(() => repository.getTemplates())
          .thenAnswer((_) async => [_template('template-1')]);

      await viewModel.load();
      await viewModel.load();

      verify(() => repository.getTemplates()).called(1);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.templates, hasLength(1));
    });

    test('force refresh bypasses cache and shows loading', () async {
      when(() => repository.getTemplates())
          .thenAnswer((_) async => [_template('template-1')]);
      await viewModel.load();

      final completer = Completer<List<MealTemplate>>();
      when(() => repository.getTemplates()).thenAnswer(
        (_) => completer.future,
      );

      final refresh = viewModel.load(forceRefresh: true);
      expect(viewModel.isLoading, isTrue);

      completer.complete([_template('template-2')]);
      await refresh;

      verify(() => repository.getTemplates()).called(2);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.templates.single.id, 'template-2');
    });

    test('expired cache refreshes silently', () async {
      when(() => repository.getTemplates())
          .thenAnswer((_) async => [_template('template-1')]);
      await viewModel.load();
      now = now.add(const Duration(seconds: 61));

      final completer = Completer<List<MealTemplate>>();
      when(() => repository.getTemplates()).thenAnswer(
        (_) => completer.future,
      );

      final refresh = viewModel.load();
      expect(viewModel.isLoading, isFalse);

      completer.complete([_template('template-2')]);
      await refresh;

      verify(() => repository.getTemplates()).called(2);
      expect(viewModel.templates.single.id, 'template-2');
    });
  });
}

const _nutrition = NutritionSnapshot(
  calories: 400,
  proteinGrams: 30,
  carbsGrams: 45,
  fatGrams: 12,
);

DailySummary _summary(String date) {
  return DailySummary(
    date: date,
    consumed: _nutrition,
    target: _nutrition,
    remaining: _nutrition,
    meals: const [],
  );
}

Meal _meal(String id) {
  return Meal(
    id: id,
    title: 'Chicken and rice',
    occurredAt: DateTime(2026, 5, 10, 12),
    nutrition: _nutrition,
    items: const [],
  );
}

MealTemplate _template(String id) {
  return MealTemplate(
    id: id,
    title: 'Usual lunch',
    trustedAutoCommitEnabled: false,
    nutrition: _nutrition,
    items: const [],
    aliases: const [],
  );
}
