import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/nutrition_models.dart';
import '../../../core/content_frame.dart';
import '../../../core/design_system.dart';
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
    return ContentFrame(
      title: 'Statistic',
      subtitle: 'Calories and meal history',
      actions: [
        FreshIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          onPressed: viewModel.load,
        ),
        const FreshIconButton(
          icon: Icons.more_horiz_rounded,
          tooltip: 'More',
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
          _CaloriesChartCard(meals: viewModel.meals),
          const SizedBox(height: FreshSpacing.lg),
          const _HealthMetricGrid(),
          const SizedBox(height: FreshSpacing.lg),
          FreshSectionTitle(
            title: 'Recent meals',
            trailing: Text(
              '${viewModel.meals.length} meals',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: FreshColors.inkMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: FreshSpacing.md),
          if (viewModel.meals.isEmpty)
            const FreshEmptyState(
              icon: Icons.history_rounded,
              title: 'No history yet',
              message: 'Confirmed meals will build your calorie timeline.',
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
                  color: FreshColors.rule,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: FreshSpacing.lg),
              _SheetAction(
                icon: Icons.edit_rounded,
                title: 'Correct',
                onTap: () => Navigator.of(context).pop('correct'),
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
    if (action == 'correct') {
      await _showCorrectionDialog(context, viewModel, meal);
    } else if (action == 'delete') {
      await _confirmDelete(context, viewModel, meal);
    }
  }

  Future<void> _showCorrectionDialog(
    BuildContext context,
    MealHistoryViewModel viewModel,
    Meal meal,
  ) async {
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (correction == null || correction.trim().isEmpty) return;
    await viewModel.correctMeal(meal, correction.trim());
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
  const _CaloriesChartCard({required this.meals});

  final List<Meal> meals;

  @override
  Widget build(BuildContext context) {
    final total =
        meals.fold<int>(0, (sum, meal) => sum + meal.nutrition.calories);
    final target = 1920;
    final bars = _weeklyBars(meals, target);
    final textTheme = Theme.of(context).textTheme;
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
                  style: textTheme.bodyMedium
                      ?.copyWith(color: FreshColors.inkSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: FreshSpacing.lg),
          SizedBox(
            height: 230,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final bar in bars)
                  Expanded(
                    child: _ChartBar(bar: bar),
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
  const _ChartBar({required this.bar});

  final _BarData bar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${bar.percent}%',
            style: textTheme.bodyMedium?.copyWith(
              color: FreshColors.inkSoft,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: FreshSpacing.sm),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: (bar.percent / 120).clamp(0.18, 1).toDouble(),
                child: Container(
                  width: 18,
                  decoration: BoxDecoration(
                    color: bar.active ? FreshColors.lime : FreshColors.limeSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: FreshSpacing.sm),
          Text(
            bar.label,
            style: textTheme.labelLarge?.copyWith(
              color: bar.active ? FreshColors.ink : FreshColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthMetricGrid extends StatelessWidget {
  const _HealthMetricGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = FreshSpacing.md;
        final columns = constraints.maxWidth < 340 ? 1 : 2;
        final totalSpacing = spacing * (columns - 1);
        final tileWidth = (constraints.maxWidth - totalSpacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in _healthMetricCards)
              SizedBox(
                width: tileWidth,
                height: 224,
                child: card,
              ),
          ],
        );
      },
    );
  }

  static const _healthMetricCards = [
    FreshMetricCard(
      title: 'Exercise',
      value: '2.0',
      unit: 'hours',
      icon: Icons.fitness_center_rounded,
      color: FreshColors.mint,
      sparkline: FreshMiniBars(values: [4, 2, 5, 7, 3, 6, 8, 2, 1]),
    ),
    FreshMetricCard(
      title: 'BPM',
      value: '86',
      unit: 'bpm',
      icon: Icons.monitor_heart_rounded,
      color: FreshColors.coral,
    ),
    FreshMetricCard(
      title: 'Weight',
      value: '72',
      unit: 'kg',
      icon: Icons.scale_rounded,
      color: FreshColors.orange,
    ),
    FreshMetricCard(
      title: 'Water',
      value: '12',
      unit: 'glass',
      icon: Icons.water_drop_rounded,
      color: FreshColors.water,
    ),
  ];
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
                  style: textTheme.bodyMedium
                      ?.copyWith(color: FreshColors.inkMuted),
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
    required this.label,
    required this.percent,
    required this.active,
  });

  final String label;
  final int percent;
  final bool active;
}

List<_BarData> _weeklyBars(List<Meal> meals, int target) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final now = DateTime.now();
  final totals = List<int>.filled(7, 0);
  for (final meal in meals) {
    final local = meal.occurredAt.toLocal();
    final index = local.weekday - 1;
    if (index >= 0 && index < 7) {
      totals[index] += meal.nutrition.calories;
    }
  }
  return [
    for (var index = 0; index < labels.length; index++)
      _BarData(
        label: labels[index],
        percent: totals[index] == 0
            ? [44, 34, 110, 47, 32, 79, 24][index]
            : ((totals[index] / target) * 100).round(),
        active: index == now.weekday - 1,
      ),
  ];
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
