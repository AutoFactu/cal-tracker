import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/dark_mode_toggle.dart';
import '../../../../domain/models/nutrition_models.dart';
import '../../../core/content_frame.dart';
import '../../../core/design_system.dart';
import '../../../shared/meal_item_editor_sheet.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../dashboard_time_labels.dart';
import '../view_models/dashboard_view_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<DashboardViewModel>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();
    final user = context.watch<AuthViewModel>().user;
    final summary = viewModel.summary;
    final displayName = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName
        : 'Cal Tracker';
    return ContentFrame(
      title: displayName,
      subtitle: dashboardGreeting(DateTime.now()),
      leading: const _Avatar(),
      actions: const [DarkModeToggle()],
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
              title: 'Could not load today',
              message: viewModel.error!,
              color: FreshColors.coral,
              action: TextButton.icon(
                onPressed: viewModel.load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ),
            const SizedBox(height: FreshSpacing.md),
          ],
          _DailyProgressCard(summary: summary),
          const SizedBox(height: FreshSpacing.lg),
          _MetricGrid(summary: summary),
          const SizedBox(height: FreshSpacing.lg),
          _MealSection(
            summary: summary,
            onEditMeal: (meal) => _showMealItemEditor(context, viewModel, meal),
          ),
        ],
      ),
    );
  }

  Future<void> _showMealItemEditor(
    BuildContext context,
    DashboardViewModel viewModel,
    Meal meal,
  ) async {
    final items = await showModalBottomSheet<List<MealItem>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => MealItemEditorSheet(
        meal: meal,
        keyPrefix: 'dashboard',
      ),
    );
    if (!context.mounted || items == null) return;
    await viewModel.correctMealItems(meal, items);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: palette.limeWash,
        shape: BoxShape.circle,
        border: Border.all(color: palette.surface, width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/images/leaf_accent.webp', fit: BoxFit.cover),
    );
  }
}

class _DailyProgressCard extends StatelessWidget {
  const _DailyProgressCard({required this.summary});

  final DailySummary? summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = context.freshPalette;
    final consumed = summary?.consumed.calories ?? 0;
    final target = summary?.target.calories ?? 2200;
    final hydrationGoal = summary?.hydrationGoalGlasses ?? 12;
    final progress =
        target <= 0 ? 0.0 : (consumed / target).clamp(0, 1).toDouble();
    return FreshCard(
      key: const ValueKey('dashboard_progress_card'),
      color: palette.limeSoft,
      radius: FreshRadii.xl,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FreshIconChip(
                      icon: Icons.bolt_rounded,
                      color: palette.limeDeep,
                      backgroundColor: palette.surface,
                      size: 34,
                    ),
                    const SizedBox(width: FreshSpacing.sm),
                    Text(
                      dashboardDayMonthLabel(DateTime.now()),
                      style: textTheme.bodyMedium?.copyWith(color: palette.ink),
                    ),
                  ],
                ),
                const SizedBox(height: FreshSpacing.md),
                Text(
                  'Your Daily\nProgress',
                  style: textTheme.headlineMedium?.copyWith(
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: FreshSpacing.sm),
                Text(
                  'Target $target Kcal, $hydrationGoal glasses',
                  key: const ValueKey('dashboard_goal_line'),
                  style: textTheme.bodyMedium?.copyWith(color: palette.inkSoft),
                ),
              ],
            ),
          ),
          FreshProgressRing(
            progress: progress,
            size: 96,
            trackColor: palette.surface,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(progress * 100).round()}%',
                  style: textTheme.titleLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'today',
                  style:
                      textTheme.labelMedium?.copyWith(color: palette.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary});

  final DailySummary? summary;

  @override
  Widget build(BuildContext context) {
    final consumed = summary?.consumed.calories ?? 0;
    final remaining = summary?.remaining.calories ?? 0;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 152,
            child: FreshMetricCard(
              title: 'Calories',
              value: '$consumed',
              unit: 'Kcal',
              icon: Icons.local_fire_department_rounded,
              color: FreshColors.orange,
            ),
          ),
        ),
        const SizedBox(width: FreshSpacing.md),
        Expanded(
          child: SizedBox(
            height: 152,
            child: FreshMetricCard(
              title: 'Remaining',
              value: '$remaining',
              unit: 'Kcal',
              icon: Icons.water_drop_rounded,
              color: FreshColors.water,
            ),
          ),
        ),
      ],
    );
  }
}

class _MealSection extends StatelessWidget {
  const _MealSection({
    required this.summary,
    required this.onEditMeal,
  });

  final DailySummary? summary;
  final ValueChanged<Meal> onEditMeal;

  @override
  Widget build(BuildContext context) {
    final meals = summary?.meals ?? const <Meal>[];
    return Column(
      children: [
        if (meals.isEmpty)
          const FreshEmptyState(
            icon: Icons.restaurant_menu_rounded,
            title: 'No meals logged today',
            message: 'Use the center voice action to log your next meal.',
          )
        else
          for (final meal in meals)
            Padding(
              padding: const EdgeInsets.only(bottom: FreshSpacing.md),
              child: _MealRow(
                meal: meal,
                onEdit: () => onEditMeal(meal),
              ),
            ),
      ],
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({
    required this.meal,
    required this.onEdit,
  });

  final Meal meal;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = context.freshPalette;
    return FreshCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (meal.mealLabel != null) ...[
                  _MealLabelChip(label: meal.mealLabel!),
                  const SizedBox(height: FreshSpacing.xs),
                ],
                Text(meal.title, style: textTheme.titleMedium),
                Text(
                  '${meal.nutrition.calories} kcal',
                  style:
                      textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: FreshSpacing.sm),
          FreshIconButton(
            key: ValueKey('dashboard_edit_meal_${meal.id}'),
            icon: Icons.edit_rounded,
            tooltip: 'Edit ingredients',
            size: 42,
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class _MealLabelChip extends StatelessWidget {
  const _MealLabelChip({required this.label});

  final MealLabel label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = context.freshPalette;
    return Container(
      key: ValueKey('dashboard_meal_label_${label.type}_${label.label}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.limeWash,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.label,
        style: textTheme.labelMedium?.copyWith(
          color: palette.limeDeep,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
