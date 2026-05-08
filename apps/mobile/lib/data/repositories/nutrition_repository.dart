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
    this.actionId,
    this.input,
    this.options,
  });

  final String kind;
  final String message;
  final MealProposal? proposal;
  final Meal? meal;
  final DailySummary? summary;
  final NutritionSnapshot? remaining;
  final List<Meal>? meals;
  final String? actionId;
  final dynamic input;
  final List<dynamic>? options;
}

class NutritionRepository {
  NutritionRepository({required CalTrackerApiClient apiClient}) : _apiClient = apiClient;

  final CalTrackerApiClient _apiClient;

  Future<AgentRunResult> logText(String text) async {
    final json = await _apiClient.runAgent(text);
    final kind = json['kind'] as String;
    return AgentRunResult(
      kind: kind,
      message: json['message'] as String,
      proposal: json['proposal'] == null ? null : MealProposal.fromJson(json['proposal'] as Map<String, Object?>),
      meal: json['meal'] == null ? null : Meal.fromJson(json['meal'] as Map<String, Object?>),
      summary: json['summary'] == null ? null : DailySummary.fromJson(json['summary'] as Map<String, Object?>),
      remaining: json['remaining'] == null ? null : NutritionSnapshot.fromJson(json['remaining'] as Map<String, Object?>),
      meals: json['meals'] == null ? null : (json['meals'] as List<Object?>).cast<Map<String, Object?>>().map(Meal.fromJson).toList(),
      actionId: json['actionId'] as String?,
      input: json['input'],
      options: json['options'] as List<dynamic>?,
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

  Future<bool> deleteMeal(String mealId, {bool confirmed = false}) async {
    final json = await _apiClient.deleteMeal(mealId, confirmed: confirmed);
    final output = json['output'] as Map<String, Object?>;
    return output['deleted'] as bool? ?? false;
  }

  Future<DailySummary> getDailySummary() async {
    final json = await _apiClient.getDailySummary(date: DateTime.now().toIso8601String().substring(0, 10));
    final output = json['output'] as Map<String, Object?>;
    return DailySummary.fromJson(output['summary'] as Map<String, Object?>);
  }

  Future<List<Meal>> getMealHistory() async {
    final json = await _apiClient.getMealHistory();
    final output = json['output'] as Map<String, Object?>;
    return (output['meals'] as List<Object?>).cast<Map<String, Object?>>().map(Meal.fromJson).toList();
  }

  Future<List<MealTemplate>> getTemplates() async {
    final json = await _apiClient.getTemplates();
    final output = json['output'] as Map<String, Object?>;
    return (output['templates'] as List<Object?>).cast<Map<String, Object?>>().map(MealTemplate.fromJson).toList();
  }

  Future<MealTemplate> setTemplateTrustedMode(MealTemplate template, bool enabled) async {
    final body = template.toUpdateJson()..['trustedAutoCommitEnabled'] = enabled;
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
