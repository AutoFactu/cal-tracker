import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/content_frame.dart';
import '../../../core/design_system.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../dashboard/view_models/dashboard_view_model.dart';
import '../../meal_history/view_models/meal_history_view_model.dart';
import '../view_models/settings_view_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<SettingsViewModel>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final settings = context.watch<SettingsViewModel>();
    final user = auth.user;
    final goals = settings.goals;
    final limeCardTextColor = FreshPalette.dark.limeWash;
    return ContentFrame(
      title: 'Menu',
      subtitle: 'Account and preferences',
      actions: const [
        FreshIconButton(icon: Icons.more_horiz_rounded, tooltip: 'More'),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FreshCard(
            radius: FreshRadii.xl,
            color: FreshColors.limeSoft,
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: FreshColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: FreshColors.limeDeep,
                    size: 30,
                  ),
                ),
                const SizedBox(width: FreshSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Cal Tracker',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: limeCardTextColor),
                      ),
                      if (user != null)
                        Text(
                          user.email,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: limeCardTextColor),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: FreshSpacing.lg),
          if (settings.isLoading) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: FreshSpacing.md),
          ],
          if (settings.error != null) ...[
            FreshStatusBanner(
              icon: Icons.error_outline_rounded,
              title: 'Could not update goals',
              message: settings.error!,
              color: FreshColors.coral,
            ),
            const SizedBox(height: FreshSpacing.md),
          ],
          _SettingsGoalRow(
            key: const ValueKey('hydration_goal_row'),
            icon: Icons.water_drop_rounded,
            color: FreshColors.water,
            title: 'Hydration goal',
            subtitle: '${goals?.hydrationGoalGlasses ?? 12} glasses per day',
            onTap: settings.isLoading
                ? null
                : () => _editGoal(
                      context,
                      title: 'Hydration goal',
                      fieldKey: const ValueKey('hydration_goal_field'),
                      initialValue: goals?.hydrationGoalGlasses ?? 12,
                      unit: 'glasses',
                      minValue: 1,
                      maxValue: 40,
                      onSave: (value) => context
                          .read<SettingsViewModel>()
                          .updateGoals(hydrationGoalGlasses: value),
                    ),
          ),
          const SizedBox(height: FreshSpacing.md),
          _SettingsGoalRow(
            key: const ValueKey('calorie_target_row'),
            icon: Icons.flag_rounded,
            color: FreshColors.orange,
            title: 'Calorie target',
            subtitle: '${goals?.target.calories ?? 2200} Kcal daily target',
            onTap: settings.isLoading
                ? null
                : () => _editGoal(
                      context,
                      title: 'Calorie target',
                      fieldKey: const ValueKey('calorie_target_field'),
                      initialValue: goals?.target.calories ?? 2200,
                      unit: 'Kcal',
                      minValue: 800,
                      maxValue: 10000,
                      onSave: (value) => context
                          .read<SettingsViewModel>()
                          .updateGoals(calories: value),
                    ),
          ),
          const SizedBox(height: FreshSpacing.xl),
          OutlinedButton.icon(
            onPressed: auth.logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  Future<void> _editGoal(
    BuildContext context, {
    required String title,
    required ValueKey<String> fieldKey,
    required int initialValue,
    required String unit,
    required int minValue,
    required int maxValue,
    required Future<Object?> Function(int value) onSave,
  }) async {
    final value = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _GoalEditSheet(
        title: title,
        fieldKey: fieldKey,
        initialValue: initialValue,
        unit: unit,
        minValue: minValue,
        maxValue: maxValue,
      ),
    );
    if (!context.mounted || value == null) return;
    final updated = await onSave(value);
    if (!context.mounted || updated == null) return;
    await Future.wait([
      context.read<DashboardViewModel>().load(),
      context.read<MealHistoryViewModel>().load(),
    ]);
  }
}

class _SettingsGoalRow extends StatelessWidget {
  const _SettingsGoalRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FreshCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          FreshIconChip(
            icon: icon,
            color: color,
          ),
          const SizedBox(width: FreshSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: FreshColors.inkMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _GoalEditSheet extends StatefulWidget {
  const _GoalEditSheet({
    required this.title,
    required this.fieldKey,
    required this.initialValue,
    required this.unit,
    required this.minValue,
    required this.maxValue,
  });

  final String title;
  final ValueKey<String> fieldKey;
  final int initialValue;
  final String unit;
  final int minValue;
  final int maxValue;

  @override
  State<_GoalEditSheet> createState() => _GoalEditSheetState();
}

class _GoalEditSheetState extends State<_GoalEditSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: context.freshPalette.rule,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: FreshSpacing.lg),
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: FreshSpacing.md),
          TextField(
            key: widget.fieldKey,
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: widget.unit,
              errorText: _error,
            ),
          ),
          const SizedBox(height: FreshSpacing.lg),
          FilledButton(
            key: const ValueKey('save_goal_button'),
            onPressed: _submit,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < widget.minValue || value > widget.maxValue) {
      setState(() {
        _error = 'Enter ${widget.minValue}-${widget.maxValue}.';
      });
      return;
    }
    Navigator.of(context).pop(value);
  }
}
