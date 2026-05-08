import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/nutrition_models.dart';
import '../../../core/content_frame.dart';
import '../view_models/meal_history_view_model.dart';

class MealHistoryScreen extends StatefulWidget {
  const MealHistoryScreen({super.key});

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<MealHistoryViewModel>().load());
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MealHistoryViewModel>();
    return ContentFrame(
      title: 'History',
      actions: [IconButton(onPressed: viewModel.load, icon: const Icon(Icons.refresh))],
      child: Column(
        children: [
          if (viewModel.isLoading) const LinearProgressIndicator(),
          if (viewModel.error != null) Text(viewModel.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          for (final meal in viewModel.meals)
            ListTile(
              title: Text(meal.title),
              subtitle: Text(meal.occurredAt.toLocal().toString()),
              trailing: Text('${meal.nutrition.calories} kcal'),
              onTap: () => _showMealActions(context, viewModel, meal),
            ),
        ],
      ),
    );
  }

  Future<void> _showMealActions(BuildContext context, MealHistoryViewModel viewModel, Meal meal) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Correct'),
              onTap: () => Navigator.of(context).pop('correct'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'correct') {
      await _showCorrectionDialog(context, viewModel, meal);
    } else if (action == 'delete') {
      await _confirmDelete(context, viewModel, meal);
    }
  }

  Future<void> _showCorrectionDialog(BuildContext context, MealHistoryViewModel viewModel, Meal meal) async {
    final controller = TextEditingController();
    final correction = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Correct meal'),
        content: TextField(
          key: const ValueKey('meal_correction_field'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Correction'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Apply')),
        ],
      ),
    );
    controller.dispose();
    if (correction == null || correction.trim().isEmpty) return;
    await viewModel.correctMeal(meal, correction.trim());
  }

  Future<void> _confirmDelete(BuildContext context, MealHistoryViewModel viewModel, Meal meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete meal?'),
        content: Text(meal.title),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await viewModel.deleteMeal(meal);
    }
  }
}
