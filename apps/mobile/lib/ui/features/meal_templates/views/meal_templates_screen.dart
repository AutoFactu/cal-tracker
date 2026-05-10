import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/nutrition_models.dart';
import '../../../core/content_frame.dart';
import '../../../core/design_system.dart';
import '../view_models/meal_templates_view_model.dart';

class MealTemplatesScreen extends StatefulWidget {
  const MealTemplatesScreen({super.key});

  @override
  State<MealTemplatesScreen> createState() => _MealTemplatesScreenState();
}

class _MealTemplatesScreenState extends State<MealTemplatesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<MealTemplatesViewModel>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MealTemplatesViewModel>();
    final limeCardTextColor = FreshPalette.dark.limeWash;
    return ContentFrame(
      title: 'Usual meals',
      subtitle: 'Safe familiar templates',
      actions: [
        FreshIconButton(
          onPressed: viewModel.load,
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
        ),
        FreshIconButton(
          onPressed: () => _showCreateTemplateDialog(context, viewModel),
          icon: Icons.add_rounded,
          tooltip: 'Add usual meal',
          backgroundColor: FreshColors.lime,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FreshCard(
            color: FreshColors.limeSoft,
            radius: FreshRadii.xl,
            child: Row(
              children: [
                const FreshIconChip(
                  icon: Icons.star_rounded,
                  color: FreshColors.limeDeep,
                  backgroundColor: FreshColors.surface,
                ),
                const SizedBox(width: FreshSpacing.md),
                Expanded(
                  child: Text(
                    'Templates keep recurring meals fast while preserving confirmation controls.',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: limeCardTextColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: FreshSpacing.lg),
          if (viewModel.isLoading) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: FreshSpacing.md),
          ],
          if (viewModel.error != null) ...[
            FreshStatusBanner(
              icon: Icons.error_outline_rounded,
              title: 'Could not load usual meals',
              message: viewModel.error!,
              color: FreshColors.coral,
            ),
            const SizedBox(height: FreshSpacing.md),
          ],
          if (viewModel.templates.isEmpty)
            const FreshEmptyState(
              icon: Icons.restaurant_menu_rounded,
              title: 'No usual meals yet',
              message: 'Create one after you confirm a meal you repeat often.',
            )
          else
            for (final template in viewModel.templates)
              Padding(
                padding: const EdgeInsets.only(bottom: FreshSpacing.md),
                child: _TemplateCard(
                  template: template,
                  onTrustedChanged: (value) =>
                      viewModel.setTrustedMode(template, value),
                  onDelete: () => _confirmDelete(context, viewModel, template),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _showCreateTemplateDialog(
    BuildContext context,
    MealTemplatesViewModel viewModel,
  ) async {
    final draft = await showDialog<_TemplateDraft>(
      context: context,
      builder: (context) => const _CreateTemplateDialog(),
    );
    if (draft == null || draft.title.isEmpty || !context.mounted) {
      return;
    }
    await viewModel.createBasicTemplate(
      title: draft.title,
      aliases: draft.aliases,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MealTemplatesViewModel viewModel,
    MealTemplate template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete usual meal?'),
        content: Text(template.title),
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
      await viewModel.deleteTemplate(template);
    }
  }
}

class _CreateTemplateDialog extends StatefulWidget {
  const _CreateTemplateDialog();

  @override
  State<_CreateTemplateDialog> createState() => _CreateTemplateDialogState();
}

class _CreateTemplateDialogState extends State<_CreateTemplateDialog> {
  final _titleController = TextEditingController();
  final _aliasesController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _aliasesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New usual meal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('template_title_field'),
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: FreshSpacing.md),
          TextField(
            key: const ValueKey('template_aliases_field'),
            controller: _aliasesController,
            decoration:
                const InputDecoration(labelText: 'Aliases, comma-separated'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final aliases = _aliasesController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    Navigator.of(context).pop(_TemplateDraft(title: title, aliases: aliases));
  }
}

class _TemplateDraft {
  const _TemplateDraft({
    required this.title,
    required this.aliases,
  });

  final String title;
  final List<String> aliases;
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onTrustedChanged,
    required this.onDelete,
  });

  final MealTemplate template;
  final ValueChanged<bool> onTrustedChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FreshCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
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
                    Text(template.title, style: textTheme.titleMedium),
                    Text(
                      template.aliases.isEmpty
                          ? 'No aliases yet'
                          : template.aliases.join(', '),
                      style: textTheme.bodyMedium
                          ?.copyWith(color: FreshColors.inkMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const FreshFoodStack(
                assets: [
                  'assets/images/meal_breakfast.webp',
                  'assets/images/meal_lunch.webp',
                ],
              ),
            ],
          ),
          const SizedBox(height: FreshSpacing.md),
          Row(
            children: [
              Expanded(
                child: _NutritionPill(
                  label: 'Calories',
                  value: '${template.nutrition.calories}',
                  unit: 'Kcal',
                  color: FreshColors.lime,
                ),
              ),
              const SizedBox(width: FreshSpacing.sm),
              Expanded(
                child: _NutritionPill(
                  label: 'Protein',
                  value: _formatQuantity(template.nutrition.proteinGrams),
                  unit: 'g',
                  color: FreshColors.mint,
                ),
              ),
            ],
          ),
          const SizedBox(height: FreshSpacing.sm),
          SwitchListTile(
            key: ValueKey('trusted_template_${template.id}'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Trusted auto-commit'),
            subtitle: const Text('Allow this usual meal to log automatically.'),
            value: template.trustedAutoCommitEnabled,
            activeThumbColor: FreshColors.lime,
            onChanged: onTrustedChanged,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: FreshColors.coral),
              label: const Text('Delete'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutritionPill extends StatelessWidget {
  const _NutritionPill({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(FreshRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelMedium),
          const SizedBox(height: FreshSpacing.xs),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 4,
            children: [
              Text(
                value,
                style: textTheme.titleLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(unit, style: textTheme.bodyMedium),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}
