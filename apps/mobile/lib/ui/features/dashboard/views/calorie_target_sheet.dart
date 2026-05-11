import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/nutrition_models.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../core/design_system.dart';

class CalorieTargetSelection {
  const CalorieTargetSelection({
    required this.calories,
    required this.source,
  });

  final int calories;
  final String source;
}

class CalorieTargetSheet extends StatefulWidget {
  const CalorieTargetSheet({
    super.key,
    required this.initialValue,
    required this.estimateCalories,
  });

  final int initialValue;
  final Future<CalorieEstimate> Function({
    required int age,
    required String sex,
    required double heightCm,
    required double weightKg,
    required String activityLevel,
    required String goal,
    String? pace,
  }) estimateCalories;

  @override
  State<CalorieTargetSheet> createState() => _CalorieTargetSheetState();
}

class _CalorieTargetSheetState extends State<CalorieTargetSheet> {
  late final TextEditingController _controller;
  String _source = 'manual';
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
    final palette = context.freshPalette;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
      child: SizedBox(
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.rule,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: FreshSpacing.lg),
            Text(
              'Set your daily calories',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: FreshSpacing.xs),
            Text(
              'Choose the target you want to track each day.',
              style: textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
            ),
            const SizedBox(height: FreshSpacing.lg),
            FreshCard(
              shadow: false,
              color: palette.surfaceSoft,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  _StepButton(
                    key: const ValueKey('calorie_target_decrement'),
                    icon: Icons.remove_rounded,
                    onTap: () => _step(-50),
                  ),
                  const SizedBox(width: FreshSpacing.md),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('dashboard_calorie_target_field'),
                      controller: _controller,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      decoration: InputDecoration(
                        suffixText: context.l10n.commonKcal,
                        errorText: _error,
                      ),
                      onChanged: (_) => setState(() {
                        _source = 'manual';
                        _error = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: FreshSpacing.md),
                  _StepButton(
                    key: const ValueKey('calorie_target_increment'),
                    icon: Icons.add_rounded,
                    onTap: () => _step(50),
                  ),
                ],
              ),
            ),
            const SizedBox(height: FreshSpacing.md),
            TextButton(
              key: const ValueKey('calorie_calculator_link'),
              onPressed: _showCalculator,
              child: const Text("Don't know how many calories you need?"),
            ),
            const SizedBox(height: FreshSpacing.lg),
            FilledButton(
              key: const ValueKey('dashboard_save_calorie_target_button'),
              onPressed: _submit,
              child: Text(context.l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }

  void _step(int delta) {
    final current =
        int.tryParse(_controller.text.trim()) ?? widget.initialValue;
    final next = (current + delta).clamp(800, 10000).toInt();
    setState(() {
      _source = 'manual';
      _error = null;
      _controller.text = next.toString();
    });
  }

  Future<void> _showCalculator() async {
    final estimate = await showModalBottomSheet<CalorieEstimate>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (context) => CalorieCalculatorWizard(
        estimateCalories: widget.estimateCalories,
      ),
    );
    if (estimate == null || !mounted) return;
    setState(() {
      _source = 'calculator';
      _error = null;
      _controller.text = estimate.targetCalories.toString();
    });
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < 800 || value > 10000) {
      setState(() => _error = 'Enter a target from 800 to 10000 Kcal.');
      return;
    }
    Navigator.of(context).pop(
      CalorieTargetSelection(calories: value, source: _source),
    );
  }
}

class CalorieCalculatorWizard extends StatefulWidget {
  const CalorieCalculatorWizard({
    super.key,
    required this.estimateCalories,
  });

  final Future<CalorieEstimate> Function({
    required int age,
    required String sex,
    required double heightCm,
    required double weightKg,
    required String activityLevel,
    required String goal,
    String? pace,
  }) estimateCalories;

  @override
  State<CalorieCalculatorWizard> createState() =>
      _CalorieCalculatorWizardState();
}

class _CalorieCalculatorWizardState extends State<CalorieCalculatorWizard> {
  final _ageController = TextEditingController(text: '30');
  final _heightController = TextEditingController(text: '170');
  final _weightController = TextEditingController(text: '70');
  final _feetController = TextEditingController(text: '5');
  final _inchesController = TextEditingController(text: '7');
  final _poundsController = TextEditingController(text: '154');
  int _step = 0;
  bool _metric = true;
  String _sex = 'male';
  String _activityLevel = 'moderately_active';
  String _goal = 'maintain';
  String _lossPace = 'moderate';
  String _gainPace = 'standard';
  bool _isLoading = false;
  String? _error;
  CalorieEstimate? _estimate;

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _feetController.dispose();
    _inchesController.dispose();
    _poundsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
      child: SizedBox(
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.rule,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: FreshSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _title,
                    style: textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${_step + 1}/4',
                  style: textTheme.labelLarge?.copyWith(
                    color: palette.inkMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: FreshSpacing.lg),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _bodyForStep(),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: FreshSpacing.md),
                      FreshStatusBanner(
                        icon: Icons.error_outline_rounded,
                        title: 'Check your details',
                        message: _error!,
                        color: FreshColors.coral,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: FreshSpacing.lg),
            Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('calorie_wizard_back_button'),
                      onPressed: _isLoading
                          ? null
                          : () => setState(() {
                                _error = null;
                                _step -= 1;
                              }),
                      child: const Text('Back'),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: FreshSpacing.md),
                Expanded(
                  child: FilledButton(
                    key: ValueKey(_step == 3
                        ? 'calorie_wizard_use_estimate_button'
                        : 'calorie_wizard_next_button'),
                    onPressed: _isLoading ? null : _primaryAction,
                    child: Text(
                      _isLoading
                          ? 'Calculating...'
                          : _step == 3
                              ? 'Use this estimate'
                              : 'Continue',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _title {
    switch (_step) {
      case 0:
        return 'Basic profile';
      case 1:
        return 'Usual activity';
      case 2:
        return 'Your goal';
      default:
        return 'Estimated target';
    }
  }

  Widget _bodyForStep() {
    switch (_step) {
      case 0:
        return _profileStep();
      case 1:
        return _activityStep();
      case 2:
        return _goalStep();
      default:
        return _resultStep();
    }
  }

  Widget _profileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumberField(
          key: const ValueKey('calorie_wizard_age_field'),
          controller: _ageController,
          label: 'Age',
          suffix: 'years',
        ),
        const SizedBox(height: FreshSpacing.md),
        Row(
          children: [
            Expanded(
              child: _ChoiceChipButton(
                key: const ValueKey('calorie_wizard_sex_male'),
                label: 'Male',
                selected: _sex == 'male',
                onTap: () => setState(() => _sex = 'male'),
              ),
            ),
            const SizedBox(width: FreshSpacing.sm),
            Expanded(
              child: _ChoiceChipButton(
                key: const ValueKey('calorie_wizard_sex_female'),
                label: 'Female',
                selected: _sex == 'female',
                onTap: () => setState(() => _sex = 'female'),
              ),
            ),
          ],
        ),
        const SizedBox(height: FreshSpacing.md),
        Row(
          children: [
            Expanded(
              child: _ChoiceChipButton(
                key: const ValueKey('calorie_wizard_metric_units'),
                label: 'Metric',
                selected: _metric,
                onTap: () => setState(() => _metric = true),
              ),
            ),
            const SizedBox(width: FreshSpacing.sm),
            Expanded(
              child: _ChoiceChipButton(
                key: const ValueKey('calorie_wizard_us_units'),
                label: 'US',
                selected: !_metric,
                onTap: () => setState(() => _metric = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: FreshSpacing.md),
        if (_metric) ...[
          _NumberField(
            key: const ValueKey('calorie_wizard_height_cm_field'),
            controller: _heightController,
            label: 'Height',
            suffix: 'cm',
          ),
          const SizedBox(height: FreshSpacing.md),
          _NumberField(
            key: const ValueKey('calorie_wizard_weight_kg_field'),
            controller: _weightController,
            label: 'Weight',
            suffix: 'kg',
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  key: const ValueKey('calorie_wizard_height_ft_field'),
                  controller: _feetController,
                  label: 'Feet',
                  suffix: 'ft',
                ),
              ),
              const SizedBox(width: FreshSpacing.sm),
              Expanded(
                child: _NumberField(
                  key: const ValueKey('calorie_wizard_height_in_field'),
                  controller: _inchesController,
                  label: 'Inches',
                  suffix: 'in',
                ),
              ),
            ],
          ),
          const SizedBox(height: FreshSpacing.md),
          _NumberField(
            key: const ValueKey('calorie_wizard_weight_lb_field'),
            controller: _poundsController,
            label: 'Weight',
            suffix: 'lb',
          ),
        ],
      ],
    );
  }

  Widget _activityStep() {
    return Column(
      children: _activityOptions.map((option) {
        return Padding(
          padding: const EdgeInsets.only(bottom: FreshSpacing.sm),
          child: _OptionCard(
            key: ValueKey('calorie_wizard_activity_${option.value}'),
            title: option.label,
            message: option.message,
            selected: _activityLevel == option.value,
            onTap: () => setState(() => _activityLevel = option.value),
          ),
        );
      }).toList(),
    );
  }

  Widget _goalStep() {
    final paceOptions = _goal == 'lose_fat'
        ? _lossPaceOptions
        : _goal == 'gain_muscle'
            ? _gainPaceOptions
            : const <_WizardOption>[];
    return Column(
      children: [
        for (final option in _goalOptions)
          Padding(
            padding: const EdgeInsets.only(bottom: FreshSpacing.sm),
            child: _OptionCard(
              key: ValueKey('calorie_wizard_goal_${option.value}'),
              title: option.label,
              message: option.message,
              selected: _goal == option.value,
              onTap: () => setState(() => _goal = option.value),
            ),
          ),
        if (paceOptions.isNotEmpty) ...[
          const SizedBox(height: FreshSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _goal == 'lose_fat'
                  ? 'How fast do you want to lose weight?'
                  : 'How fast do you want to gain weight?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: FreshSpacing.sm),
          for (final option in paceOptions)
            Padding(
              padding: const EdgeInsets.only(bottom: FreshSpacing.sm),
              child: _OptionCard(
                key: ValueKey('calorie_wizard_pace_${option.value}'),
                title: option.label,
                message: option.message,
                selected: _selectedPace == option.value,
                onTap: () => setState(() {
                  if (_goal == 'lose_fat') {
                    _lossPace = option.value;
                  } else {
                    _gainPace = option.value;
                  }
                }),
              ),
            ),
        ],
      ],
    );
  }

  Widget _resultStep() {
    final estimate = _estimate;
    if (estimate == null) {
      return Text(
        'Your estimate will appear here.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    final palette = context.freshPalette;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FreshCard(
          key: const ValueKey('calorie_wizard_result_card'),
          color: palette.limeWash,
          shadow: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recommended target', style: textTheme.titleMedium),
              const SizedBox(height: FreshSpacing.sm),
              Text(
                '${estimate.targetCalories}',
                key: const ValueKey('calorie_wizard_target_value'),
                style: textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'Kcal per day',
                style: textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: FreshSpacing.md),
        _ResultLine(label: 'BMR estimate', value: '${estimate.bmr} Kcal'),
        _ResultLine(
          label: 'Maintenance',
          value: '${estimate.maintenanceCalories} Kcal',
        ),
        _ResultLine(
          label: 'Range',
          value:
              '${estimate.recommendedRangeMin}-${estimate.recommendedRangeMax} Kcal',
        ),
        if (estimate.warnings.isNotEmpty) ...[
          const SizedBox(height: FreshSpacing.md),
          for (final warning in estimate.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: FreshSpacing.sm),
              child: FreshStatusBanner(
                icon: Icons.info_outline_rounded,
                title: 'Estimate note',
                message: warning,
                color: FreshColors.orange,
              ),
            ),
        ],
        const SizedBox(height: FreshSpacing.sm),
        Text(
          estimate.explanation,
          style: textTheme.bodySmall?.copyWith(color: palette.inkMuted),
        ),
      ],
    );
  }

  String? get _selectedPace {
    if (_goal == 'lose_fat') return _lossPace;
    if (_goal == 'gain_muscle') return _gainPace;
    return null;
  }

  Future<void> _primaryAction() async {
    if (_step < 2) {
      if (_step == 0 && !_validateProfile()) return;
      setState(() {
        _error = null;
        _step += 1;
      });
      return;
    }
    if (_step == 2) {
      if (!_validateProfile()) return;
      await _calculateEstimate();
      return;
    }
    if (_estimate != null) Navigator.of(context).pop(_estimate);
  }

  bool _validateProfile() {
    final profile = _profileValues();
    if (profile == null) {
      setState(() =>
          _error = 'Enter age, height, and weight in the expected ranges.');
      return false;
    }
    return true;
  }

  Future<void> _calculateEstimate() async {
    final profile = _profileValues();
    if (profile == null) {
      setState(() =>
          _error = 'Enter age, height, and weight in the expected ranges.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final estimate = await widget.estimateCalories(
        age: profile.age,
        sex: _sex,
        heightCm: profile.heightCm,
        weightKg: profile.weightKg,
        activityLevel: _activityLevel,
        goal: _goal,
        pace: _selectedPace,
      );
      if (!mounted) return;
      setState(() {
        _estimate = estimate;
        _step = 3;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  _ProfileValues? _profileValues() {
    final age = int.tryParse(_ageController.text.trim());
    final heightCm = _metric
        ? double.tryParse(_heightController.text.trim())
        : _heightInCm();
    final weightKg = _metric
        ? double.tryParse(_weightController.text.trim())
        : _weightInKg();
    if (age == null ||
        age < 18 ||
        age > 100 ||
        heightCm == null ||
        heightCm < 120 ||
        heightCm > 230 ||
        weightKg == null ||
        weightKg < 35 ||
        weightKg > 250) {
      return null;
    }
    return _ProfileValues(age: age, heightCm: heightCm, weightKg: weightKg);
  }

  double? _heightInCm() {
    final feet = double.tryParse(_feetController.text.trim());
    final inches = double.tryParse(_inchesController.text.trim());
    if (feet == null || inches == null) return null;
    return (feet * 12 + inches) * 2.54;
  }

  double? _weightInKg() {
    final pounds = double.tryParse(_poundsController.text.trim());
    if (pounds == null) return null;
    return pounds * 0.45359237;
  }
}

class _ProfileValues {
  const _ProfileValues({
    required this.age,
    required this.heightCm,
    required this.weightKg,
  });

  final int age;
  final double heightCm;
  final double weightKg;
}

class _WizardOption {
  const _WizardOption({
    required this.value,
    required this.label,
    required this.message,
  });

  final String value;
  final String label;
  final String message;
}

const _activityOptions = [
  _WizardOption(
    value: 'sedentary',
    label: 'Sedentary',
    message:
        'Mostly seated, low daily movement, and 0-1 light workouts weekly.',
  ),
  _WizardOption(
    value: 'lightly_active',
    label: 'Lightly active',
    message: 'Regular walks or light exercise 1-3 days per week.',
  ),
  _WizardOption(
    value: 'moderately_active',
    label: 'Moderately active',
    message: 'Training 3-5 days per week or a meaningfully active routine.',
  ),
  _WizardOption(
    value: 'very_active',
    label: 'Very active',
    message: 'Hard exercise most days or active work plus regular training.',
  ),
  _WizardOption(
    value: 'extra_active',
    label: 'Extra active',
    message: 'Athlete-level workload, two-a-days, or demanding physical work.',
  ),
];

const _goalOptions = [
  _WizardOption(
    value: 'lose_fat',
    label: 'Lose fat',
    message: 'Estimate a deficit from maintenance.',
  ),
  _WizardOption(
    value: 'maintain',
    label: 'Maintain weight',
    message: 'Track around your estimated maintenance.',
  ),
  _WizardOption(
    value: 'gain_muscle',
    label: 'Gain muscle / weight',
    message: 'Estimate a controlled calorie surplus.',
  ),
  _WizardOption(
    value: 'recomposition',
    label: 'Recomposition',
    message: 'Start near maintenance while you train consistently.',
  ),
];

const _lossPaceOptions = [
  _WizardOption(
    value: 'slow',
    label: 'Slow',
    message: 'Easier to maintain and better for performance.',
  ),
  _WizardOption(
    value: 'moderate',
    label: 'Moderate',
    message: 'Recommended default for most users.',
  ),
  _WizardOption(
    value: 'aggressive',
    label: 'Aggressive',
    message: 'Larger deficit. Use only if you can recover well.',
  ),
];

const _gainPaceOptions = [
  _WizardOption(
    value: 'lean',
    label: 'Lean',
    message: 'Small surplus for minimal fat gain.',
  ),
  _WizardOption(
    value: 'standard',
    label: 'Standard',
    message: 'Recommended default for most users gaining muscle.',
  ),
  _WizardOption(
    value: 'aggressive',
    label: 'Aggressive',
    message: 'Larger surplus with higher fat-gain risk.',
  ),
];

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FreshIconButton(
      icon: icon,
      tooltip: icon == Icons.add_rounded ? 'Increase' : 'Decrease',
      onPressed: onTap,
      backgroundColor: context.freshPalette.surface,
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
      ),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  const _ChoiceChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? palette.lime : palette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? palette.lime : palette.rule),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    super.key,
    required this.title,
    required this.message,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String message;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    return FreshCard(
      onTap: onTap,
      shadow: false,
      padding: const EdgeInsets.all(14),
      color: selected ? palette.limeWash : palette.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            selected ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: selected ? palette.limeDeep : palette.inkMuted,
          ),
          const SizedBox(width: FreshSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: palette.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    return Padding(
      padding: const EdgeInsets.only(bottom: FreshSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: palette.inkMuted),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
