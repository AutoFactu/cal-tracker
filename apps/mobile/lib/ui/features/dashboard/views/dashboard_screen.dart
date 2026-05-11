import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/dark_mode_toggle.dart';
import '../../../../domain/models/nutrition_models.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../../l10n/meal_label_localizations.dart';
import '../../../core/content_frame.dart';
import '../../../core/design_system.dart';
import '../../../shared/meal_item_editor_sheet.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../meal_history/view_models/meal_history_view_model.dart';
import '../../settings/view_models/settings_view_model.dart';
import '../dashboard_time_labels.dart';
import '../view_models/dashboard_view_model.dart';
import 'calorie_target_sheet.dart';

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
    final l10n = context.l10n;
    final summary = viewModel.summary;
    final displayName = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName
        : l10n.fallbackUserName;
    return ContentFrame(
      title: displayName,
      subtitle: dashboardGreeting(DateTime.now(), l10n),
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
              title: l10n.dashboardCouldNotLoadToday,
              message: viewModel.error!,
              color: FreshColors.coral,
              action: TextButton.icon(
                onPressed: () => viewModel.load(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.commonTryAgain),
              ),
            ),
            const SizedBox(height: FreshSpacing.md),
          ],
          _DailyProgressCard(
            summary: summary,
            onSetup: () => _showCalorieTargetSheet(context, viewModel),
          ),
          const SizedBox(height: FreshSpacing.md),
          _MacroSummaryRow(summary: summary),
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

  Future<void> _showCalorieTargetSheet(
    BuildContext context,
    DashboardViewModel viewModel,
  ) async {
    final summary = viewModel.summary;
    final selection = await showModalBottomSheet<CalorieTargetSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CalorieTargetSheet(
        initialValue: summary?.target.calories ?? 2200,
        estimateCalories: viewModel.estimateCalories,
      ),
    );
    if (!context.mounted || selection == null) return;
    await viewModel.updateCalorieTarget(
      selection.calories,
      source: selection.source,
    );
    if (!context.mounted) return;
    await Future.wait([
      context.read<MealHistoryViewModel>().load(),
      context.read<SettingsViewModel>().load(),
    ]);
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
  const _DailyProgressCard({
    required this.summary,
    required this.onSetup,
  });

  final DailySummary? summary;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = context.freshPalette;
    final l10n = context.l10n;
    final consumed = summary?.consumed.calories ?? 0;
    final target = summary?.target.calories ?? 2200;
    final hasConfiguredTarget = summary?.calorieTargetConfigured ?? true;
    if (!hasConfiguredTarget) {
      return _CalorieSetupProgressCard(onTap: onSetup);
    }
    final remaining = (summary?.remaining.calories ?? target - consumed)
        .clamp(0, target)
        .toInt();
    final progress =
        target <= 0 ? 0.0 : (consumed / target).clamp(0, 1).toDouble();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 380;
    final ringSize = compact ? 118.0 : 132.0;
    final cardHeight = compact ? 124.0 : 136.0;
    return FreshCard(
      key: const ValueKey('dashboard_progress_card'),
      color: palette.limeSoft,
      radius: FreshRadii.xl,
      padding: EdgeInsets.fromLTRB(
        compact ? 20 : 24,
        compact ? 22 : 26,
        compact ? 18 : 22,
        compact ? 22 : 26,
      ),
      child: SizedBox(
        height: cardHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.dashboardTodayCalories,
                    key: const ValueKey('dashboard_today_calories_label'),
                    style: textTheme.titleSmall?.copyWith(
                      color: palette.inkSoft,
                      fontSize: compact ? 19 : 21,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$consumed',
                          key: const ValueKey('dashboard_consumed_calories'),
                          style: textTheme.displayLarge?.copyWith(
                            fontSize: compact ? 56 : 64,
                            height: 0.92,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Padding(
                          padding: EdgeInsets.only(bottom: compact ? 8 : 9),
                          child: Text(
                            l10n.commonKcal,
                            style: textTheme.titleMedium?.copyWith(
                              color: palette.inkSoft,
                              fontSize: compact ? 16 : 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: FreshSpacing.lg),
            FreshProgressRing(
              progress: progress,
              size: ringSize,
              trackColor: palette.surface,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$remaining',
                      key: const ValueKey('dashboard_remaining_calories'),
                      style: textTheme.headlineMedium?.copyWith(
                        fontSize: compact ? 23 : 27,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Text(
                    '${l10n.commonKcal} ${l10n.dashboardCaloriesLeft}',
                    key: const ValueKey('dashboard_remaining_label'),
                    textAlign: TextAlign.center,
                    style: textTheme.labelSmall?.copyWith(
                      color: palette.inkSoft,
                      fontSize: compact ? 10 : 11,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalorieSetupProgressCard extends StatelessWidget {
  const _CalorieSetupProgressCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardHeight = (screenWidth * 0.48).clamp(184.0, 206.0);
    final ringSize = screenWidth < 380 ? 122.0 : 138.0;
    final titleStyle = textTheme.headlineSmall?.copyWith(
      color: palette.ink,
      fontSize: screenWidth < 380 ? 31 : 35,
      height: 1.12,
      fontWeight: FontWeight.w900,
      letterSpacing: 0,
    );
    final radius = BorderRadius.circular(30);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('dashboard_progress_card'),
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xffeffadc),
                Color(0xfff7fde9),
                Color(0xffe9f8c9),
              ],
            ),
            borderRadius: radius,
            border: Border.all(
              color: const Color(0xffc5e994),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.055),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: palette.lime.withValues(alpha: 0.12),
                blurRadius: 26,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: SizedBox(
              height: cardHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 48,
                    right: 4,
                    child: _SetupCaloriesRing(size: ringSize),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: _SetupDatePill(
                      label: dashboardDayMonthLabel(DateTime.now(), l10n),
                    ),
                  ),
                  Positioned(
                    top: 78,
                    left: 0,
                    right: ringSize + 18,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Set your\ndaily calories.',
                        maxLines: 2,
                        style: titleStyle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupDatePill extends StatelessWidget {
  const _SetupDatePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    final textTheme = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: 36,
        padding: const EdgeInsets.only(left: 0, right: 17),
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: palette.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bolt_rounded,
                color: palette.limeDeep,
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
            Text(
              label,
              style: textTheme.titleMedium?.copyWith(
                color: palette.ink,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupCaloriesRing extends StatelessWidget {
  const _SetupCaloriesRing({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    return SizedBox.square(
      dimension: size,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.055),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: size * 0.68,
            height: size * 0.68,
            decoration: BoxDecoration(
              color: palette.limeWash.withValues(alpha: 0.72),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.settings_outlined,
              color: palette.limeDeep,
              size: size * 0.42,
            ),
          ),
        ),
      ),
    );
  }
}

class _MacroSummaryRow extends StatelessWidget {
  const _MacroSummaryRow({required this.summary});

  final DailySummary? summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final consumedNutrition = summary?.consumed ?? _emptyNutrition;
    final targetNutrition = summary?.target ?? _defaultTarget;
    final hasConfiguredTarget = summary?.calorieTargetConfigured ?? true;
    return Row(
      children: [
        Expanded(
          child: _MacroSummaryPill(
            icon: Icons.bakery_dining_rounded,
            label: l10n.commonCarbs,
            value: hasConfiguredTarget
                ? _macroRatio(
                    consumedNutrition.carbsGrams,
                    targetNutrition.carbsGrams,
                  )
                : '',
            color: FreshColors.orange,
          ),
        ),
        const SizedBox(width: FreshSpacing.sm),
        Expanded(
          child: _MacroSummaryPill(
            icon: Icons.local_drink_rounded,
            label: l10n.localeName.startsWith('es') ? 'Proteínas' : 'Proteins',
            value: hasConfiguredTarget
                ? _macroRatio(
                    consumedNutrition.proteinGrams,
                    targetNutrition.proteinGrams,
                  )
                : '',
            color: FreshColors.mint,
          ),
        ),
        const SizedBox(width: FreshSpacing.sm),
        Expanded(
          child: _MacroSummaryPill(
            icon: Icons.egg_alt_rounded,
            label: l10n.localeName.startsWith('es') ? 'Grasas' : 'Fats',
            value: hasConfiguredTarget
                ? _macroRatio(
                    consumedNutrition.fatGrams,
                    targetNutrition.fatGrams,
                  )
                : '',
            color: FreshColors.yellow,
          ),
        ),
      ],
    );
  }
}

class _MacroSummaryPill extends StatelessWidget {
  const _MacroSummaryPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = context.freshPalette;
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(FreshRadii.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: palette.ink),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: palette.inkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (value.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: textTheme.labelLarge?.copyWith(
                        color: palette.ink,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
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

String _macroRatio(double consumed, double target) {
  return '${_formatMacro(consumed)}/${_formatMacro(target)}';
}

String _formatMacro(double value) {
  return value.round().toString();
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
    final l10n = context.l10n;
    final meals = summary?.meals ?? const <Meal>[];
    return Column(
      children: [
        if (meals.isEmpty)
          FreshEmptyState(
            icon: Icons.restaurant_menu_rounded,
            title: l10n.dashboardNoMealsLoggedToday,
            message: l10n.dashboardNoMealsMessage,
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
    final l10n = context.l10n;
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
                  l10n.caloriesValue(meal.nutrition.calories),
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
            tooltip: l10n.dashboardEditIngredientsTooltip,
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
        localizedMealLabel(context.l10n, label),
        style: textTheme.labelMedium?.copyWith(
          color: palette.limeDeep,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
