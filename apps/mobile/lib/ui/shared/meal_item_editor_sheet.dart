import 'package:flutter/material.dart';

import '../../domain/models/nutrition_models.dart';
import '../../l10n/app_localizations_context.dart';
import '../core/design_system.dart';

class MealItemEditorSheet extends StatefulWidget {
  const MealItemEditorSheet({
    super.key,
    required this.meal,
    this.keyPrefix = 'meal',
  });

  final Meal meal;
  final String keyPrefix;

  @override
  State<MealItemEditorSheet> createState() => _MealItemEditorSheetState();
}

class _MealItemEditorSheetState extends State<MealItemEditorSheet> {
  late final List<_EditableMealItem> _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _items = [
      for (final item in widget.meal.items) _EditableMealItem(item),
    ];
    if (_items.isEmpty) {
      _items.add(_EditableMealItem.empty());
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 12, 18, bottomInset + 18),
      child: SingleChildScrollView(
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
            Text(l10n.commonEditIngredients, style: textTheme.titleLarge),
            const SizedBox(height: FreshSpacing.xs),
            Text(
              widget.meal.title,
              style: textTheme.bodyMedium?.copyWith(
                color: context.freshPalette.inkMuted,
              ),
            ),
            const SizedBox(height: FreshSpacing.md),
            if (_error != null) ...[
              FreshStatusBanner(
                icon: Icons.error_outline_rounded,
                title: l10n.commonCheckIngredientDetails,
                message: _error!,
                color: FreshColors.coral,
              ),
              const SizedBox(height: FreshSpacing.md),
            ],
            for (var index = 0; index < _items.length; index++) ...[
              _IngredientEditorRow(
                key: ValueKey('${widget.keyPrefix}_item_editor_$index'),
                item: _items[index],
                index: index,
                keyPrefix: widget.keyPrefix,
                onDelete: _items.length == 1
                    ? null
                    : () {
                        setState(() {
                          _items.removeAt(index).dispose();
                        });
                      },
              ),
              const SizedBox(height: FreshSpacing.md),
            ],
            OutlinedButton.icon(
              key: ValueKey('add_${widget.keyPrefix}_item_button'),
              onPressed: () {
                setState(() {
                  _items.add(_EditableMealItem.empty());
                  _error = null;
                });
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.commonAddIngredient),
            ),
            const SizedBox(height: FreshSpacing.md),
            FilledButton.icon(
              key: ValueKey('save_${widget.keyPrefix}_item_edits_button'),
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(l10n.commonSaveEdits),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final edited = <MealItem>[];
    for (final item in _items) {
      final mealItem = item.toMealItem();
      if (mealItem == null) {
        setState(() {
          _error = context.l10n.commonIngredientDetailsError;
        });
        return;
      }
      edited.add(mealItem);
    }
    if (edited.isEmpty) {
      setState(() {
        _error = context.l10n.commonAddAtLeastOneIngredient;
      });
      return;
    }
    Navigator.of(context).pop(edited);
  }
}

class _IngredientEditorRow extends StatelessWidget {
  const _IngredientEditorRow({
    super.key,
    required this.item,
    required this.index,
    required this.keyPrefix,
    required this.onDelete,
  });

  final _EditableMealItem item;
  final int index;
  final String keyPrefix;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FreshCard(
      padding: const EdgeInsets.all(12),
      shadow: false,
      child: Column(
        children: [
          TextField(
            key: ValueKey('${keyPrefix}_item_name_$index'),
            controller: item.nameController,
            decoration: InputDecoration(labelText: l10n.commonIngredient),
          ),
          const SizedBox(height: FreshSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('${keyPrefix}_item_quantity_$index'),
                  controller: item.quantityController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.commonAmount),
                ),
              ),
              const SizedBox(width: FreshSpacing.sm),
              SizedBox(
                width: 82,
                child: TextField(
                  key: ValueKey('${keyPrefix}_item_unit_$index'),
                  controller: item.unitController,
                  decoration: InputDecoration(labelText: l10n.commonUnit),
                ),
              ),
              const SizedBox(width: FreshSpacing.sm),
              IconButton(
                key: ValueKey('delete_${keyPrefix}_item_$index'),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: l10n.commonDeleteIngredient,
              ),
            ],
          ),
          const SizedBox(height: FreshSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('${keyPrefix}_item_calories_$index'),
                  controller: item.caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.commonCalories),
                ),
              ),
              const SizedBox(width: FreshSpacing.sm),
              Expanded(
                child: TextField(
                  key: ValueKey('${keyPrefix}_item_protein_$index'),
                  controller: item.proteinController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.commonProtein),
                ),
              ),
            ],
          ),
          const SizedBox(height: FreshSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('${keyPrefix}_item_carbs_$index'),
                  controller: item.carbsController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.commonCarbs),
                ),
              ),
              const SizedBox(width: FreshSpacing.sm),
              Expanded(
                child: TextField(
                  key: ValueKey('${keyPrefix}_item_fat_$index'),
                  controller: item.fatController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.commonFat),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditableMealItem {
  _EditableMealItem(MealItem item)
      : original = item,
        isNew = false {
    nameController = TextEditingController(text: item.name);
    quantityController =
        TextEditingController(text: _formatQuantity(item.quantity));
    unitController = TextEditingController(text: item.unit);
    caloriesController = TextEditingController(text: '${item.calories}');
    proteinController =
        TextEditingController(text: _formatMacro(item.proteinGrams));
    carbsController =
        TextEditingController(text: _formatMacro(item.carbsGrams));
    fatController = TextEditingController(text: _formatMacro(item.fatGrams));
  }

  _EditableMealItem.empty()
      : original = const MealItem(
          name: '',
          quantity: 100,
          unit: 'g',
          calories: 0,
          proteinGrams: 0,
          carbsGrams: 0,
          fatGrams: 0,
          source: 'manual_edit',
        ),
        isNew = true {
    nameController = TextEditingController();
    quantityController = TextEditingController(text: '100');
    unitController = TextEditingController(text: 'g');
    caloriesController = TextEditingController();
    proteinController = TextEditingController(text: '0');
    carbsController = TextEditingController(text: '0');
    fatController = TextEditingController(text: '0');
  }

  final MealItem original;
  final bool isNew;
  late final TextEditingController nameController;
  late final TextEditingController quantityController;
  late final TextEditingController unitController;
  late final TextEditingController caloriesController;
  late final TextEditingController proteinController;
  late final TextEditingController carbsController;
  late final TextEditingController fatController;

  MealItem? toMealItem() {
    final name = nameController.text.trim();
    final quantity = double.tryParse(quantityController.text.trim());
    final unit = unitController.text.trim();
    final calories = int.tryParse(caloriesController.text.trim());
    final protein = double.tryParse(proteinController.text.trim());
    final carbs = double.tryParse(carbsController.text.trim());
    final fat = double.tryParse(fatController.text.trim());
    if (name.isEmpty ||
        quantity == null ||
        quantity <= 0 ||
        unit.isEmpty ||
        calories == null ||
        calories < 0 ||
        protein == null ||
        protein < 0 ||
        carbs == null ||
        carbs < 0 ||
        fat == null ||
        fat < 0) {
      return null;
    }

    final factor = original.quantity > 0 ? quantity / original.quantity : 1.0;
    final source = original.source.contains('manual_edit')
        ? original.source
        : '${original.source}:manual_edit';
    return original.copyWith(
      name: name,
      quantity: quantity,
      unit: unit,
      calories: _wasUnedited(caloriesController.text, '${original.calories}')
          ? (original.calories * factor).round()
          : calories,
      proteinGrams: _wasUnedited(
              proteinController.text, _formatMacro(original.proteinGrams))
          ? _roundMacro(original.proteinGrams * factor)
          : _roundMacro(protein),
      carbsGrams:
          _wasUnedited(carbsController.text, _formatMacro(original.carbsGrams))
              ? _roundMacro(original.carbsGrams * factor)
              : _roundMacro(carbs),
      fatGrams:
          _wasUnedited(fatController.text, _formatMacro(original.fatGrams))
              ? _roundMacro(original.fatGrams * factor)
              : _roundMacro(fat),
      source: isNew ? 'manual_edit' : source,
    );
  }

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
  }
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

String _formatMacro(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

double _roundMacro(double value) => (value * 10).round() / 10;

bool _wasUnedited(String current, String original) {
  return current.trim() == original.trim();
}
