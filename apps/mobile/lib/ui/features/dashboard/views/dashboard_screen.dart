import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/nutrition_models.dart';
import '../../../core/content_frame.dart';
import '../../../core/design_system.dart';
import '../../auth/view_models/auth_view_model.dart';
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
      subtitle: 'Good morning!',
      leading: const _Avatar(),
      actions: [
        FreshIconButton(
          icon: Icons.calendar_month_rounded,
          tooltip: 'Calendar',
          onPressed: viewModel.load,
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            FreshIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifications',
              onPressed: viewModel.load,
            ),
            const Positioned(
              right: 12,
              top: 11,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: FreshColors.lime,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: 8),
              ),
            ),
          ],
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
          _WeeklyProgressCard(summary: summary),
          const SizedBox(height: FreshSpacing.lg),
          _MetricGrid(summary: summary),
          const SizedBox(height: FreshSpacing.lg),
          const _CalendarStrip(),
          const SizedBox(height: FreshSpacing.lg),
          _MealSection(summary: summary),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: FreshColors.limeWash,
        shape: BoxShape.circle,
        border: Border.all(color: FreshColors.surface, width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/images/leaf_accent.webp', fit: BoxFit.cover),
    );
  }
}

class _WeeklyProgressCard extends StatelessWidget {
  const _WeeklyProgressCard({required this.summary});

  final DailySummary? summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final consumed = summary?.consumed.calories ?? 0;
    final target = summary?.target.calories ?? 1920;
    final progress =
        target <= 0 ? 0.0 : (consumed / target).clamp(0, 1).toDouble();
    return FreshCard(
      color: FreshColors.limeSoft,
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
                    const FreshIconChip(
                      icon: Icons.bolt_rounded,
                      color: FreshColors.limeDeep,
                      backgroundColor: FreshColors.surface,
                      size: 34,
                    ),
                    const SizedBox(width: FreshSpacing.sm),
                    Text(
                      'Daily intake',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: FreshColors.ink),
                    ),
                  ],
                ),
                const SizedBox(height: FreshSpacing.md),
                Text(
                  'Your Weekly\nProgress',
                  style: textTheme.headlineMedium?.copyWith(
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          FreshProgressRing(
            progress: progress,
            size: 96,
            trackColor: FreshColors.surface,
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
                  style: textTheme.labelMedium
                      ?.copyWith(color: FreshColors.inkSoft),
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

class _CalendarStrip extends StatelessWidget {
  const _CalendarStrip();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (index) => start.add(Duration(days: index)));
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return FreshCard(
      child: Column(
        children: [
          FreshSectionTitle(
            title: _monthLabel(now),
            trailing: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FreshIconButton(icon: Icons.arrow_back_rounded, size: 38),
                SizedBox(width: FreshSpacing.sm),
                FreshIconButton(icon: Icons.arrow_forward_rounded, size: 38),
              ],
            ),
          ),
          const SizedBox(height: FreshSpacing.md),
          Row(
            children: [
              for (var index = 0; index < days.length; index++)
                Expanded(
                  child: _DayCell(
                    label: labels[index],
                    day: days[index].day,
                    selected: _isSameDay(days[index], now),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.label,
    required this.day,
    required this.selected,
  });

  final String label;
  final int day;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: selected ? FreshColors.limeSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Column(
        children: [
          Text(label,
              style:
                  textTheme.labelMedium?.copyWith(color: FreshColors.inkSoft)),
          const SizedBox(height: FreshSpacing.sm),
          Text(
            '$day',
            style: textTheme.bodyLarge?.copyWith(
              color: FreshColors.ink,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  const _MealSection({required this.summary});

  final DailySummary? summary;

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
              child: _MealRow(meal: meal),
            ),
      ],
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FreshCard(
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
                  '${meal.nutrition.calories} - ${meal.nutrition.calories + 56} kcal',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: FreshColors.inkMuted),
                ),
              ],
            ),
          ),
          const FreshFoodStack(),
          const SizedBox(width: FreshSpacing.sm),
          const FreshIconButton(icon: Icons.add_rounded, size: 42),
        ],
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _monthLabel(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}
