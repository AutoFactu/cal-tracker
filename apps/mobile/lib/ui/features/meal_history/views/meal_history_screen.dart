import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/nutrition_models.dart';
import '../../../core/content_frame.dart';
import '../../../core/design_system.dart';
import '../../../shared/meal_item_editor_sheet.dart';
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<MealHistoryViewModel>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MealHistoryViewModel>();
    final palette = context.freshPalette;
    return ContentFrame(
      title: 'Stats',
      subtitle: 'Calories and meal history',
      actions: [
        FreshIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          onPressed: viewModel.load,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (viewModel.isLoading) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: FreshSpacing.md),
          ],
          if (viewModel.error != null) ...[
            FreshStatusBanner(
              icon: Icons.error_outline_rounded,
              title: 'Could not load history',
              message: viewModel.error!,
              color: FreshColors.coral,
            ),
            const SizedBox(height: FreshSpacing.md),
          ],
          _CaloriesChartCard(
            summaries: viewModel.weekSummaries,
            selectedDate: viewModel.selectedDate,
            onSelectDate: viewModel.selectDate,
          ),
          const SizedBox(height: FreshSpacing.lg),
          FreshSectionTitle(
            title: 'Logged meals',
            trailing: Text(
              '${viewModel.meals.length} meals',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: palette.inkMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: FreshSpacing.md),
          if (viewModel.meals.isEmpty)
            const FreshEmptyState(
              icon: Icons.history_rounded,
              title: 'No meals logged',
              message: 'Meals for the selected day will appear here.',
            )
          else
            for (final meal in viewModel.meals)
              Padding(
                padding: const EdgeInsets.only(bottom: FreshSpacing.md),
                child: _HistoryMealCard(
                  meal: meal,
                  onTap: () => _showMealActions(context, viewModel, meal),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _showMealActions(
    BuildContext context,
    MealHistoryViewModel viewModel,
    Meal meal,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: context.freshPalette.rule,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: FreshSpacing.lg),
              _SheetAction(
                icon: Icons.edit_rounded,
                title: 'Edit ingredients',
                onTap: () => Navigator.of(context).pop('edit'),
              ),
              const SizedBox(height: FreshSpacing.sm),
              _SheetAction(
                icon: Icons.delete_outline_rounded,
                title: 'Delete',
                color: FreshColors.coral,
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'edit') {
      await _showMealItemEditor(context, viewModel, meal);
    } else if (action == 'delete') {
      await _confirmDelete(context, viewModel, meal);
    }
  }

  Future<void> _showMealItemEditor(
    BuildContext context,
    MealHistoryViewModel viewModel,
    Meal meal,
  ) async {
    final items = await showModalBottomSheet<List<MealItem>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => MealItemEditorSheet(
        meal: meal,
        keyPrefix: 'history',
      ),
    );
    if (!context.mounted || items == null) return;
    await viewModel.correctMealItems(meal, items);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MealHistoryViewModel viewModel,
    Meal meal,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete meal?'),
        content: Text(meal.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await viewModel.deleteMeal(meal);
    }
  }
}

class _CaloriesChartCard extends StatelessWidget {
  const _CaloriesChartCard({
    required this.summaries,
    required this.selectedDate,
    required this.onSelectDate,
  });

  final List<DailySummary> summaries;
  final String selectedDate;
  final ValueChanged<String> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final selectedSummary = summaries.firstWhere(
      (summary) => summary.date == selectedDate,
      orElse: () => summaries.isEmpty
          ? DailySummary(
              date: selectedDate,
              consumed: _emptyNutrition,
              target: _defaultTarget,
              remaining: _defaultTarget,
              hydrationGoalGlasses: 12,
              meals: const [],
            )
          : summaries.last,
    );
    final total = selectedSummary.consumed.calories;
    final target = selectedSummary.target.calories;
    final bars = _weeklyBars(summaries, selectedDate);
    final textTheme = Theme.of(context).textTheme;
    final palette = context.freshPalette;
    return FreshCard(
      radius: FreshRadii.xl,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Calories', style: textTheme.titleMedium),
          const SizedBox(height: FreshSpacing.xs),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                '$total',
                style: textTheme.displayLarge?.copyWith(
                  fontSize: 54,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Text('Kcal', style: textTheme.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Target: $target Kcal',
                  style: textTheme.bodyMedium?.copyWith(color: palette.inkSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: FreshSpacing.lg),
          SizedBox(
            key: const ValueKey('history_calorie_chart'),
            height: 230,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final bar in bars)
                  Expanded(
                    child: _ChartBar(
                      bar: bar,
                      onTap: () => onSelectDate(bar.date),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartBar extends StatelessWidget {
  const _ChartBar({
    required this.bar,
    required this.onTap,
  });

  final _BarData bar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = context.freshPalette;
    return Semantics(
      button: true,
      selected: bar.active,
      label: 'Select ${bar.label}',
      child: GestureDetector(
        key: ValueKey('stats_day_${bar.date}'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${bar.percent}%',
                style: textTheme.bodyMedium?.copyWith(
                  color: bar.active ? palette.ink : palette.inkSoft,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: FreshSpacing.sm),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: (bar.percent / 120).clamp(0, 1).toDouble(),
                    child: Container(
                      width: 18,
                      decoration: BoxDecoration(
                        color: bar.active ? palette.lime : palette.limeSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: FreshSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: bar.active ? palette.limeWash : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  bar.label,
                  style: textTheme.labelLarge?.copyWith(
                    color: bar.active ? palette.ink : palette.inkSoft,
                    fontWeight: bar.active ? FontWeight.w700 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryMealCard extends StatelessWidget {
  const _HistoryMealCard({
    required this.meal,
    required this.onTap,
  });

  final Meal meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = context.freshPalette;
    return FreshCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const FreshIconChip(
            icon: Icons.local_fire_department_rounded,
            color: FreshColors.orange,
            backgroundColor: FreshColors.yellow,
          ),
          const SizedBox(width: FreshSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.title, style: textTheme.titleMedium),
                Text(
                  _formatDate(meal.occurredAt),
                  style:
                      textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
                ),
              ],
            ),
          ),
          Text(
            '${meal.nutrition.calories} Kcal',
            style: textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color = FreshColors.limeDeep,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FreshCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      shadow: false,
      child: Row(
        children: [
          FreshIconChip(icon: icon, color: color),
          const SizedBox(width: FreshSpacing.md),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}

class _BarData {
  const _BarData({
    required this.date,
    required this.label,
    required this.percent,
    required this.active,
  });

  final String date;
  final String label;
  final int percent;
  final bool active;
}

List<_BarData> _weeklyBars(List<DailySummary> summaries, String selectedDate) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return [
    for (var index = 0; index < labels.length; index++) ...[
      if (index < summaries.length)
        _BarData(
          date: summaries[index].date,
          label: labels[index],
          percent: summaries[index].target.calories <= 0
              ? 0
              : ((summaries[index].consumed.calories /
                          summaries[index].target.calories) *
                      100)
                  .round(),
          active: summaries[index].date == selectedDate,
        )
      else
        _BarData(
          date: '',
          label: labels[index],
          percent: 0,
          active: false,
        ),
    ]
  ];
}

const _emptyNutrition = NutritionSnapshot(
  calories: 0,
  proteinGrams: 0,
  carbsGrams: 0,
  fatGrams: 0,
);

const _defaultTarget = NutritionSnapshot(
  calories: 2200,
  proteinGrams: 160,
  carbsGrams: 240,
  fatGrams: 70,
);

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
