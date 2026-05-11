import 'package:cal_tracker_mobile/app/theme.dart';
import 'package:cal_tracker_mobile/data/repositories/nutrition_repository.dart';
import 'package:cal_tracker_mobile/data/services/api_config.dart';
import 'package:cal_tracker_mobile/data/services/secure_token_storage.dart';
import 'package:cal_tracker_mobile/domain/models/nutrition_models.dart';
import 'package:cal_tracker_mobile/generated/api/cal_tracker_api.dart';
import 'package:cal_tracker_mobile/l10n/generated/app_localizations.dart';
import 'package:cal_tracker_mobile/ui/features/meal_templates/view_models/meal_templates_view_model.dart';
import 'package:cal_tracker_mobile/ui/features/meal_templates/views/meal_templates_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
      'creates a usual meal from the add dialog without lifecycle errors',
      (tester) async {
    final repository = _FakeNutritionRepository();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => MealTemplatesViewModel(
          nutritionRepository: repository,
        ),
        child: const _TestApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add usual meal'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('template_title_field')),
      'Protein breakfast',
    );
    await tester.enterText(
      find.byKey(const ValueKey('template_aliases_field')),
      'breakfast, eggs',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Protein breakfast'), findsOneWidget);
    expect(repository.createdAliases, ['breakfast', 'eggs']);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildLightTheme(),
      home: const Scaffold(body: MealTemplatesScreen()),
    );
  }
}

class _FakeNutritionRepository extends NutritionRepository {
  _FakeNutritionRepository() : super(apiClient: _unusedApiClient());

  List<MealTemplate> templates = const [];
  List<String> createdAliases = const [];

  @override
  Future<List<MealTemplate>> getTemplates() async => templates;

  @override
  Future<MealTemplate> createTemplate({
    required String title,
    required List<String> aliases,
    required List<MealItem> items,
  }) async {
    createdAliases = aliases;
    final template = MealTemplate(
      id: 'template-${templates.length + 1}',
      title: title,
      aliases: aliases,
      nutrition: const NutritionSnapshot(
        calories: 443,
        proteinGrams: 50.6,
        carbsGrams: 42,
        fatGrams: 5.9,
      ),
      items: items,
      trustedAutoCommitEnabled: false,
    );
    templates = [...templates, template];
    return template;
  }
}

class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<StoredTokens?> read() async => null;

  @override
  Future<void> write(StoredTokens tokens) async {}
}

CalTrackerApiClient _unusedApiClient() {
  return CalTrackerApiClient(
    config: const ApiConfig(baseUrl: 'http://localhost'),
    tokenStorage: _MemoryTokenStorage(),
  );
}
