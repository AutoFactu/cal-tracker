import 'package:cal_tracker_mobile/data/repositories/nutrition_repository.dart';
import 'package:cal_tracker_mobile/generated/api/cal_tracker_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCalTrackerApiClient extends Mock implements CalTrackerApiClient {}

void main() {
  group('NutritionRepository', () {
    test('parses all 10 food candidates from agent options', () async {
      final apiClient = MockCalTrackerApiClient();
      final repository = NutritionRepository(apiClient: apiClient);
      when(() => apiClient.runAgent('100 gramos de queso')).thenAnswer(
        (_) async => {
          'kind': 'clarification_required',
          'message': 'Choose a food match.',
          'options': [
            {
              'mention': {
                'originalText': 'queso',
                'canonicalEnglishName': 'cheese',
                'quantity': 100,
                'unit': 'g',
                'confidence': 0.92,
                'marketProduct': false,
              },
              'candidates': [
                for (var index = 0; index < 10; index++)
                  {
                    'name': 'Cheese candidate ${index + 1}',
                    'quantity': 100,
                    'unit': 'g',
                    'calories': 100 + index,
                    'proteinGrams': 7,
                    'carbsGrams': 1,
                    'fatGrams': 8,
                    'source': 'open_food_facts',
                    'externalSource': 'Open Food Facts',
                    'externalId': 'cheese_${index + 1}',
                    'confidence': 0.9 - (index * 0.02),
                  },
              ],
            },
          ],
        },
      );

      final result = await repository.logText('100 gramos de queso');

      expect(result.candidateGroups, hasLength(1));
      expect(result.candidateGroups!.single.candidates, hasLength(10));
      expect(
        result.candidateGroups!.single.candidates[9].name,
        'Cheese candidate 10',
      );
    });
  });
}
