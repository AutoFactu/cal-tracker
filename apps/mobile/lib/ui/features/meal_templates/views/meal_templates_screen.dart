import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/nutrition_models.dart';
import '../../../core/content_frame.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<MealTemplatesViewModel>().load());
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MealTemplatesViewModel>();
    return ContentFrame(
      title: 'Usual Meals',
      actions: [
        IconButton(onPressed: viewModel.load, icon: const Icon(Icons.refresh)),
        IconButton(onPressed: () => _showCreateTemplateDialog(context, viewModel), icon: const Icon(Icons.add)),
      ],
      child: Column(
        children: [
          if (viewModel.isLoading) const LinearProgressIndicator(),
          if (viewModel.error != null) Text(viewModel.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          for (final template in viewModel.templates)
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(template.title),
                    subtitle: Text('${template.nutrition.calories} kcal'),
                    value: template.trustedAutoCommitEnabled,
                    onChanged: (value) => viewModel.setTrustedMode(template, value),
                  ),
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _confirmDelete(context, viewModel, template),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showCreateTemplateDialog(BuildContext context, MealTemplatesViewModel viewModel) async {
    final titleController = TextEditingController();
    final aliasesController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New usual meal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('template_title_field'),
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              key: const ValueKey('template_aliases_field'),
              controller: aliasesController,
              decoration: const InputDecoration(labelText: 'Aliases, comma-separated'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Create')),
        ],
      ),
    );
    final title = titleController.text.trim();
    final aliases = aliasesController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    titleController.dispose();
    aliasesController.dispose();
    if (submitted == true && title.isNotEmpty) {
      await viewModel.createBasicTemplate(title: title, aliases: aliases);
    }
  }

  Future<void> _confirmDelete(BuildContext context, MealTemplatesViewModel viewModel, MealTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete usual meal?'),
        content: Text(template.title),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await viewModel.deleteTemplate(template);
    }
  }
}
