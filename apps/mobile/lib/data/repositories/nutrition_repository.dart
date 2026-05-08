import 'dart:io';

import '../../domain/models/nutrition_models.dart';
import '../../generated/api/cal_tracker_api.dart';

class AgentRunResult {
  const AgentRunResult({
    required this.kind,
    required this.message,
    this.proposal,
    this.meal,
    this.summary,
    this.remaining,
    this.meals,
    this.items,
    this.templates,
    this.template,
    this.matches,
    this.deleted,
    this.actionId,
    this.input,
    this.options,
    this.candidateGroups,
  });

  final String kind;
  final String message;
  final MealProposal? proposal;
  final Meal? meal;
  final DailySummary? summary;
  final NutritionSnapshot? remaining;
  final List<Meal>? meals;
  final List<MealItem>? items;
  final List<MealTemplate>? templates;
  final MealTemplate? template;
  final List<dynamic>? matches;
  final bool? deleted;
  final String? actionId;
  final dynamic input;
  final List<dynamic>? options;
  final List<FoodCandidateGroup>? candidateGroups;
}

class NutritionRepository {
  NutritionRepository({required CalTrackerApiClient apiClient})
      : _apiClient = apiClient;

  final CalTrackerApiClient _apiClient;

  Future<AgentRunResult> logText(String text) async {
    final json = await _apiClient.runAgent(text);
    final kind = json['kind'] as String;
    return AgentRunResult(
      kind: kind,
      message: json['message'] as String,
      proposal: json['proposal'] == null
          ? null
          : MealProposal.fromJson(json['proposal'] as Map<String, Object?>),
      meal: json['meal'] == null
          ? null
          : Meal.fromJson(json['meal'] as Map<String, Object?>),
      summary: json['summary'] == null
          ? null
          : DailySummary.fromJson(json['summary'] as Map<String, Object?>),
      remaining: json['remaining'] == null
          ? null
          : NutritionSnapshot.fromJson(
              json['remaining'] as Map<String, Object?>),
      meals: json['meals'] == null
          ? null
          : (json['meals'] as List<Object?>)
              .cast<Map<String, Object?>>()
              .map(Meal.fromJson)
              .toList(),
      items: json['items'] == null
          ? null
          : (json['items'] as List<Object?>)
              .cast<Map<String, Object?>>()
              .map(MealItem.fromJson)
              .toList(),
      templates: json['templates'] == null
          ? null
          : (json['templates'] as List<Object?>)
              .cast<Map<String, Object?>>()
              .map(MealTemplate.fromJson)
              .toList(),
      template: json['template'] == null
          ? null
          : MealTemplate.fromJson(json['template'] as Map<String, Object?>),
      matches: json['matches'] as List<dynamic>?,
      deleted: json['deleted'] as bool?,
      actionId: json['actionId'] as String?,
      input: json['input'],
      options: json['options'] as List<dynamic>?,
      candidateGroups: _parseCandidateGroups(json['options']),
    );
  }

  Future<Meal> commitProposal(String proposalId) async {
    final json = await _apiClient.commitProposal(proposalId);
    final output = json['output'] as Map<String, Object?>;
    return Meal.fromJson(output['meal'] as Map<String, Object?>);
  }

  Future<Meal> correctMeal(String mealId, String correctionText) async {
    final json = await _apiClient.correctMeal(mealId, correctionText);
    final output = json['output'] as Map<String, Object?>;
    return Meal.fromJson(output['meal'] as Map<String, Object?>);
  }

  Future<MealProposal> updateProposalItems(
      String proposalId, List<MealItem> items) async {
    final json = await _apiClient.correctProposal(
      proposalId: proposalId,
      correctionText: 'Manual proposal edit',
      items: items.map((item) => item.toJson()).toList(),
    );
    final output = json['output'] as Map<String, Object?>;
    return MealProposal.fromJson(output['proposal'] as Map<String, Object?>);
  }

  Future<bool> deleteMeal(String mealId, {bool confirmed = false}) async {
    final json = await _apiClient.deleteMeal(mealId, confirmed: confirmed);
    final output = json['output'] as Map<String, Object?>;
    return output['deleted'] as bool? ?? false;
  }

  Future<DailySummary> getDailySummary() async {
    final json = await _apiClient.getDailySummary(
        date: DateTime.now().toIso8601String().substring(0, 10));
    final output = json['output'] as Map<String, Object?>;
    return DailySummary.fromJson(output['summary'] as Map<String, Object?>);
  }

  Future<List<Meal>> getMealHistory() async {
    final json = await _apiClient.getMealHistory();
    final output = json['output'] as Map<String, Object?>;
    return (output['meals'] as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(Meal.fromJson)
        .toList();
  }

  Future<List<MealTemplate>> getTemplates() async {
    final json = await _apiClient.getTemplates();
    final output = json['output'] as Map<String, Object?>;
    return (output['templates'] as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(MealTemplate.fromJson)
        .toList();
  }

  Future<MealTemplate> setTemplateTrustedMode(
      MealTemplate template, bool enabled) async {
    final body = template.toUpdateJson()
      ..['trustedAutoCommitEnabled'] = enabled;
    final json = await _apiClient.updateTemplate(template.id, body);
    final output = json['output'] as Map<String, Object?>;
    return MealTemplate.fromJson(output['template'] as Map<String, Object?>);
  }

  Future<MealTemplate> createTemplate({
    required String title,
    required List<MealItem> items,
    required List<String> aliases,
  }) async {
    final json = await _apiClient.createTemplate({
      'title': title,
      'trustedAutoCommitEnabled': false,
      'items': items.map((item) => item.toJson()).toList(),
      'aliases': aliases,
    });
    final output = json['output'] as Map<String, Object?>;
    return MealTemplate.fromJson(output['template'] as Map<String, Object?>);
  }

  Future<bool> deleteTemplate(String templateId) async {
    final json = await _apiClient.deleteTemplate(templateId);
    final output = json['output'] as Map<String, Object?>;
    return output['deleted'] as bool? ?? false;
  }

  Future<String> transcribeAudio(File audioFile) async {
    final json = await _apiClient.transcribeAudio(audioFile, source: 'flutter');
    return json['transcript'] as String;
  }
}

List<FoodCandidateGroup>? _parseCandidateGroups(Object? value) {
  if (value is! List<Object?>) return null;
  final groups = <FoodCandidateGroup>[];
  for (final item in value) {
    if (item is Map<String, Object?> && item['mention'] is Map<String, Object?>) {
      groups.add(FoodCandidateGroup.fromJson(item));
    }
  }
  return groups.isEmpty ? null : groups;
}
