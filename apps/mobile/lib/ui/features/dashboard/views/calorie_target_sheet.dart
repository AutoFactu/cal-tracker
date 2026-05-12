import 'dart:math' as math;

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
    Navigator.of(context).pop(
      CalorieTargetSelection(
        calories: estimate.targetCalories,
        source: 'calculator',
      ),
    );
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

enum _WizardStep {
  sex,
  age,
  height,
  weight,
  goal,
  pace,
  activity,
  result,
}

class _CalorieCalculatorWizardState extends State<CalorieCalculatorWizard> {
  final _ageController = TextEditingController(text: '30');
  final _heightController = TextEditingController(text: '170');
  final _weightController = TextEditingController(text: '70');
  final _feetController = TextEditingController(text: '5');
  final _inchesController = TextEditingController(text: '7');
  final _poundsController = TextEditingController(text: '154');
  int _stepIndex = 0;
  bool _heightMetric = true;
  bool _weightMetric = true;
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.94;
    final activeStep = _activeStep;
    final totalSteps = _totalSteps;
    final currentStep = _isResultStep ? totalSteps : _stepIndex + 1;
    return Material(
      color: palette.screen,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(20, 10, 20, bottomInset + 16),
        child: SizedBox(
          height: maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WizardTopBar(
                currentStep: currentStep,
                totalSteps: totalSteps,
                progress: currentStep / totalSteps,
                canGoBack: _stepIndex > 0 && !_isResultStep,
                onClose: () => Navigator.of(context).maybePop(),
                onBack: _goBack,
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
              const SizedBox(height: FreshSpacing.md),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey(_isLoading ? 'loading' : activeStep.name),
                    child:
                        _isLoading ? const _LoadingPlanStep() : _bodyForStep(),
                  ),
                ),
              ),
              if (!_isLoading) ...[
                const SizedBox(height: FreshSpacing.lg),
                FilledButton(
                  key: ValueKey(_isResultStep
                      ? 'calorie_wizard_use_estimate_button'
                      : 'calorie_wizard_next_button'),
                  onPressed: _primaryAction,
                  child: Text(
                    _isResultStep ? 'Use this estimate' : 'Continue',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<_WizardStep> get _questionSteps {
    final steps = <_WizardStep>[
      _WizardStep.sex,
      _WizardStep.age,
      _WizardStep.height,
      _WizardStep.weight,
      _WizardStep.goal,
    ];
    if (_goal == 'lose_fat' || _goal == 'gain_muscle') {
      steps.add(_WizardStep.pace);
    }
    steps.add(_WizardStep.activity);
    return steps;
  }

  int get _totalSteps => _questionSteps.length + 1;

  bool get _isResultStep => _stepIndex >= _questionSteps.length;

  _WizardStep get _activeStep {
    if (_isResultStep) return _WizardStep.result;
    return _questionSteps[_stepIndex];
  }

  Widget _bodyForStep() {
    switch (_activeStep) {
      case _WizardStep.sex:
        return _sexStep();
      case _WizardStep.age:
        return _ageStep();
      case _WizardStep.height:
        return _heightStep();
      case _WizardStep.weight:
        return _weightStep();
      case _WizardStep.goal:
        return _goalStep();
      case _WizardStep.pace:
        return _paceStep();
      case _WizardStep.activity:
        return _activityStep();
      case _WizardStep.result:
        return _resultStep();
    }
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  String _formatCompactNumber(double value) {
    if ((value - value.roundToDouble()).abs() < 0.01) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  String _formatFeetAndInches(double value) {
    final totalInches = value.round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    return '$feet\'$inches"';
  }

  void _setAgeFromRuler(double value) {
    final age = value.round().clamp(18, 100);
    setState(() {
      _setControllerText(_ageController, age.toString());
      _error = null;
    });
  }

  void _setHeightFromRuler(double value) {
    setState(() {
      if (_heightMetric) {
        final heightCm = value.clamp(120, 230).toDouble();
        _setControllerText(_heightController, heightCm.round().toString());
      } else {
        final totalInches = value.round().clamp(48, 90);
        final feet = totalInches ~/ 12;
        final inches = totalInches % 12;
        _setControllerText(_feetController, feet.toString());
        _setControllerText(_inchesController, inches.toString());
      }
      _error = null;
    });
  }

  void _setWeightFromRuler(double value) {
    setState(() {
      if (_weightMetric) {
        final weightKg = value.clamp(35, 250).toDouble();
        _setControllerText(_weightController, _formatCompactNumber(weightKg));
      } else {
        final pounds = value.round().clamp(78, 551);
        _setControllerText(_poundsController, pounds.toString());
      }
      _error = null;
    });
  }

  Widget _sexStep() {
    return _WizardQuestionPage(
      title: 'What is your biological sex?',
      subtitle: 'This keeps the calorie estimate aligned with the formula.',
      children: [
        _WizardChoiceCard(
          key: const ValueKey('calorie_wizard_sex_male'),
          icon: Icons.male_rounded,
          title: 'Male',
          message: 'Use the male BMR coefficient.',
          selected: _sex == 'male',
          onTap: () => setState(() {
            _sex = 'male';
            _error = null;
          }),
        ),
        const SizedBox(height: FreshSpacing.md),
        _WizardChoiceCard(
          key: const ValueKey('calorie_wizard_sex_female'),
          icon: Icons.female_rounded,
          title: 'Female',
          message: 'Use the female BMR coefficient.',
          selected: _sex == 'female',
          onTap: () => setState(() {
            _sex = 'female';
            _error = null;
          }),
        ),
      ],
    );
  }

  Widget _ageStep() {
    final value = double.tryParse(_ageController.text.trim()) ?? 30;
    return _WizardQuestionPage(
      title: 'How old are you?',
      subtitle: 'Age helps estimate your resting calorie needs.',
      children: [
        _WizardNumberCard(
          fieldKey: const ValueKey('calorie_wizard_age_field'),
          controller: _ageController,
          suffix: 'years',
          decimal: false,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: FreshSpacing.xl),
        _RulerScale(
          value: value,
          min: 18,
          max: 100,
          step: 1,
          majorEvery: 10,
          onChanged: _setAgeFromRuler,
        ),
      ],
    );
  }

  Widget _heightStep() {
    final heightCm = _heightInCm() ?? 170;
    final value = _heightMetric
        ? (double.tryParse(_heightController.text.trim()) ?? heightCm)
        : (heightCm / 2.54).clamp(48, 90).toDouble();
    return _WizardQuestionPage(
      title: 'What is your height?',
      subtitle: 'Use the unit that feels easiest to enter.',
      children: [
        _UnitToggle(
          firstKey: const ValueKey('calorie_wizard_metric_units'),
          secondKey: const ValueKey('calorie_wizard_us_units'),
          firstLabel: 'cm',
          secondLabel: 'ft',
          firstSelected: _heightMetric,
          onFirstTap: () => setState(() {
            _heightMetric = true;
            _error = null;
          }),
          onSecondTap: () => setState(() {
            _heightMetric = false;
            _error = null;
          }),
        ),
        const SizedBox(height: FreshSpacing.md),
        if (_heightMetric)
          _WizardNumberCard(
            fieldKey: const ValueKey('calorie_wizard_height_cm_field'),
            controller: _heightController,
            suffix: 'cm',
            decimal: true,
            onChanged: (_) => setState(() => _error = null),
          )
        else
          Row(
            children: [
              Expanded(
                child: _WizardNumberCard(
                  fieldKey: const ValueKey('calorie_wizard_height_ft_field'),
                  controller: _feetController,
                  suffix: 'ft',
                  decimal: false,
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
              const SizedBox(width: FreshSpacing.sm),
              Expanded(
                child: _WizardNumberCard(
                  fieldKey: const ValueKey('calorie_wizard_height_in_field'),
                  controller: _inchesController,
                  suffix: 'in',
                  decimal: true,
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
            ],
          ),
        const SizedBox(height: FreshSpacing.xl),
        _RulerScale(
          value: value,
          min: _heightMetric ? 120 : 48,
          max: _heightMetric ? 230 : 90,
          step: 1,
          majorEvery: _heightMetric ? 10 : 12,
          minLabel: _heightMetric ? null : _formatFeetAndInches(48),
          maxLabel: _heightMetric ? null : _formatFeetAndInches(90),
          onChanged: _setHeightFromRuler,
        ),
      ],
    );
  }

  Widget _weightStep() {
    final weightKg = _weightInKg() ?? 70;
    final value = _weightMetric
        ? (double.tryParse(_weightController.text.trim()) ?? weightKg)
        : (weightKg / 0.45359237).clamp(78, 551).toDouble();
    return _WizardQuestionPage(
      title: 'What is your current weight?',
      subtitle: 'Your target is based on your current body weight.',
      children: [
        _UnitToggle(
          firstKey: const ValueKey('calorie_wizard_metric_units'),
          secondKey: const ValueKey('calorie_wizard_us_units'),
          firstLabel: 'kg',
          secondLabel: 'lb',
          firstSelected: _weightMetric,
          onFirstTap: () => setState(() {
            _weightMetric = true;
            _error = null;
          }),
          onSecondTap: () => setState(() {
            _weightMetric = false;
            _error = null;
          }),
        ),
        const SizedBox(height: FreshSpacing.md),
        if (_weightMetric)
          _WizardNumberCard(
            fieldKey: const ValueKey('calorie_wizard_weight_kg_field'),
            controller: _weightController,
            suffix: 'kg',
            decimal: true,
            onChanged: (_) => setState(() => _error = null),
          )
        else
          _WizardNumberCard(
            fieldKey: const ValueKey('calorie_wizard_weight_lb_field'),
            controller: _poundsController,
            suffix: 'lb',
            decimal: true,
            onChanged: (_) => setState(() => _error = null),
          ),
        const SizedBox(height: FreshSpacing.xl),
        _RulerScale(
          value: value,
          min: _weightMetric ? 35 : 78,
          max: _weightMetric ? 250 : 551,
          step: _weightMetric ? 0.5 : 1,
          majorEvery: _weightMetric ? 25 : 50,
          onChanged: _setWeightFromRuler,
        ),
      ],
    );
  }

  Widget _goalStep() {
    return _WizardQuestionPage(
      title: 'What is your main goal?',
      subtitle: 'Choose the outcome you want your target to support.',
      children: [
        for (final option in _goalOptions)
          Padding(
            padding: const EdgeInsets.only(bottom: FreshSpacing.md),
            child: _WizardChoiceCard(
              key: ValueKey('calorie_wizard_goal_${option.value}'),
              icon: option.icon,
              title: option.label,
              message: option.message,
              selected: _goal == option.value,
              onTap: () => setState(() {
                _goal = option.value;
                _error = null;
              }),
            ),
          ),
      ],
    );
  }

  Widget _paceStep() {
    final isLoss = _goal == 'lose_fat';
    final paceOptions = isLoss ? _lossPaceOptions : _gainPaceOptions;
    return _WizardQuestionPage(
      title: isLoss
          ? 'How fast do you want to lose weight?'
          : 'How fast do you want to gain weight?',
      subtitle: 'A steadier pace is easier to sustain.',
      children: [
        for (final option in paceOptions)
          Padding(
            padding: const EdgeInsets.only(bottom: FreshSpacing.md),
            child: _WizardChoiceCard(
              key: ValueKey('calorie_wizard_pace_${option.value}'),
              icon: option.icon,
              title: option.label,
              message: option.message,
              selected: _selectedPace == option.value,
              onTap: () => setState(() {
                if (isLoss) {
                  _lossPace = option.value;
                } else {
                  _gainPace = option.value;
                }
                _error = null;
              }),
            ),
          ),
      ],
    );
  }

  Widget _activityStep() {
    return _WizardQuestionPage(
      title: 'What is your activity level?',
      subtitle: 'Pick the option that best matches a normal week.',
      children: [
        for (final option in _activityOptions)
          Padding(
            padding: const EdgeInsets.only(bottom: FreshSpacing.md),
            child: _WizardChoiceCard(
              key: ValueKey('calorie_wizard_activity_${option.value}'),
              icon: option.icon,
              title: option.label,
              message: option.message,
              selected: _activityLevel == option.value,
              onTap: () => setState(() {
                _activityLevel = option.value;
                _error = null;
              }),
            ),
          ),
      ],
    );
  }

  Widget _resultStep() {
    final estimate = _estimate;
    if (estimate == null) return const _LoadingPlanStep();
    return _ResultPlanStep(estimate: estimate);
  }

  String? get _selectedPace {
    if (_goal == 'lose_fat') return _lossPace;
    if (_goal == 'gain_muscle') return _gainPace;
    return null;
  }

  Future<void> _primaryAction() async {
    if (_isResultStep) {
      if (_estimate != null) Navigator.of(context).pop(_estimate);
      return;
    }
    final step = _activeStep;
    if (!_validateCurrentStep(step)) return;
    if (step == _WizardStep.activity) {
      await _calculateEstimate();
      return;
    }
    setState(() {
      _error = null;
      _stepIndex += 1;
    });
  }

  void _goBack() {
    if (_isLoading) return;
    if (_isResultStep) {
      setState(() {
        _error = null;
        _estimate = null;
        _stepIndex = math.max(0, _questionSteps.length - 1);
      });
      return;
    }
    if (_stepIndex == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _error = null;
      _stepIndex -= 1;
    });
  }

  bool _validateCurrentStep(_WizardStep step) {
    switch (step) {
      case _WizardStep.age:
        final age = int.tryParse(_ageController.text.trim());
        if (age == null || age < 18 || age > 100) {
          setState(() => _error = 'Enter an age from 18 to 100.');
          return false;
        }
        return true;
      case _WizardStep.height:
        final heightCm = _heightMetric
            ? double.tryParse(_heightController.text.trim())
            : _heightInCm();
        if (heightCm == null || heightCm < 120 || heightCm > 230) {
          setState(() => _error = 'Enter a height from 120 to 230 cm.');
          return false;
        }
        return true;
      case _WizardStep.weight:
        final weightKg = _weightMetric
            ? double.tryParse(_weightController.text.trim())
            : _weightInKg();
        if (weightKg == null || weightKg < 35 || weightKg > 250) {
          setState(() => _error = 'Enter a weight from 35 to 250 kg.');
          return false;
        }
        return true;
      case _WizardStep.sex:
      case _WizardStep.goal:
      case _WizardStep.pace:
      case _WizardStep.activity:
      case _WizardStep.result:
        return true;
    }
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
        _stepIndex = _questionSteps.length;
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
    final heightCm = _heightMetric
        ? double.tryParse(_heightController.text.trim())
        : _heightInCm();
    final weightKg = _weightMetric
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
    required this.icon,
  });

  final String value;
  final String label;
  final String message;
  final IconData icon;
}

const _activityOptions = [
  _WizardOption(
    value: 'sedentary',
    label: 'Sedentary',
    message:
        'Mostly seated, low daily movement, and 0-1 light workouts weekly.',
    icon: Icons.weekend_rounded,
  ),
  _WizardOption(
    value: 'lightly_active',
    label: 'Lightly Active',
    message: 'Regular walks or light exercise 1-3 days per week.',
    icon: Icons.directions_walk_rounded,
  ),
  _WizardOption(
    value: 'moderately_active',
    label: 'Moderately Active',
    message: 'Training 3-5 days per week or a meaningfully active routine.',
    icon: Icons.fitness_center_rounded,
  ),
  _WizardOption(
    value: 'very_active',
    label: 'Very Active',
    message: 'Hard exercise most days or active work plus regular training.',
    icon: Icons.local_fire_department_rounded,
  ),
  _WizardOption(
    value: 'extra_active',
    label: 'Super Active',
    message: 'Athlete-level workload, two-a-days, or demanding physical work.',
    icon: Icons.speed_rounded,
  ),
];

const _goalOptions = [
  _WizardOption(
    value: 'lose_fat',
    label: 'Lose Weight',
    message: 'Estimate a deficit from maintenance.',
    icon: Icons.flag_rounded,
  ),
  _WizardOption(
    value: 'gain_muscle',
    label: 'Gain Muscle',
    message: 'Estimate a controlled calorie surplus.',
    icon: Icons.fitness_center_rounded,
  ),
  _WizardOption(
    value: 'maintain',
    label: 'Maintain Weight',
    message: 'Track around your estimated maintenance.',
    icon: Icons.balance_rounded,
  ),
  _WizardOption(
    value: 'recomposition',
    label: 'Improve Nutrition',
    message: 'Start near maintenance while you train consistently.',
    icon: Icons.auto_graph_rounded,
  ),
];

const _lossPaceOptions = [
  _WizardOption(
    value: 'slow',
    label: 'Slow',
    message: 'Easier to maintain and better for performance.',
    icon: Icons.eco_rounded,
  ),
  _WizardOption(
    value: 'moderate',
    label: 'Moderate',
    message: 'Recommended default for most users.',
    icon: Icons.check_circle_outline_rounded,
  ),
  _WizardOption(
    value: 'aggressive',
    label: 'Aggressive',
    message: 'Larger deficit. Use only if you can recover well.',
    icon: Icons.bolt_rounded,
  ),
];

const _gainPaceOptions = [
  _WizardOption(
    value: 'lean',
    label: 'Lean',
    message: 'Small surplus for minimal fat gain.',
    icon: Icons.eco_rounded,
  ),
  _WizardOption(
    value: 'standard',
    label: 'Standard',
    message: 'Recommended default for most users gaining muscle.',
    icon: Icons.check_circle_outline_rounded,
  ),
  _WizardOption(
    value: 'aggressive',
    label: 'Aggressive',
    message: 'Larger surplus with higher fat-gain risk.',
    icon: Icons.bolt_rounded,
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

class _WizardTopBar extends StatelessWidget {
  const _WizardTopBar({
    required this.currentStep,
    required this.totalSteps,
    required this.progress,
    required this.canGoBack,
    required this.onClose,
    required this.onBack,
  });

  final int currentStep;
  final int totalSteps;
  final double progress;
  final bool canGoBack;
  final VoidCallback onClose;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    final textTheme = Theme.of(context).textTheme;
    final normalizedProgress = progress.clamp(0.0, 1.0).toDouble();
    return Row(
      children: [
        FreshIconButton(
          key: ValueKey(canGoBack
              ? 'calorie_wizard_back_button'
              : 'calorie_wizard_close_button'),
          icon: canGoBack ? Icons.arrow_back_rounded : Icons.close_rounded,
          tooltip: canGoBack ? 'Back' : 'Close',
          onPressed: canGoBack ? onBack : onClose,
          backgroundColor: palette.surface,
        ),
        const SizedBox(width: FreshSpacing.md),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: normalizedProgress,
              backgroundColor: palette.surfaceMuted,
              color: palette.lime,
            ),
          ),
        ),
        const SizedBox(width: FreshSpacing.md),
        Text(
          '$currentStep/$totalSteps',
          style: textTheme.labelLarge?.copyWith(
            color: palette.inkMuted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _WizardQuestionPage extends StatelessWidget {
  const _WizardQuestionPage({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: FreshSpacing.md),
          Text(
            title,
            style: textTheme.headlineSmall?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: FreshSpacing.sm),
          Text(
            subtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: palette.inkMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: FreshSpacing.xl),
          ...children,
          const SizedBox(height: FreshSpacing.lg),
        ],
      ),
    );
  }
}

class _WizardChoiceCard extends StatelessWidget {
  const _WizardChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(FreshRadii.lg),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(FreshRadii.lg),
            border: Border.all(
              color: selected ? palette.lime : palette.ruleSoft,
              width: selected ? 2 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x17080907),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selected ? palette.limeWash : palette.surfaceSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: selected ? palette.limeDeep : palette.ink,
                  size: 22,
                ),
              ),
              const SizedBox(width: FreshSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        color: palette.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: textTheme.bodySmall?.copyWith(
                        color: palette.inkMuted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FreshSpacing.md),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: selected ? palette.lime : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? palette.lime : palette.rule,
                  ),
                ),
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        color: palette.ink,
                        size: 18,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({
    required this.firstKey,
    required this.secondKey,
    required this.firstLabel,
    required this.secondLabel,
    required this.firstSelected,
    required this.onFirstTap,
    required this.onSecondTap,
  });

  final Key firstKey;
  final Key secondKey;
  final String firstLabel;
  final String secondLabel;
  final bool firstSelected;
  final VoidCallback onFirstTap;
  final VoidCallback onSecondTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _UnitToggleSegment(
              key: firstKey,
              label: firstLabel,
              selected: firstSelected,
              onTap: onFirstTap,
            ),
          ),
          Expanded(
            child: _UnitToggleSegment(
              key: secondKey,
              label: secondLabel,
              selected: !firstSelected,
              onTap: onSecondTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitToggleSegment extends StatelessWidget {
  const _UnitToggleSegment({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? palette.lime : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _WizardNumberCard extends StatelessWidget {
  const _WizardNumberCard({
    required this.fieldKey,
    required this.controller,
    required this.suffix,
    required this.decimal,
    required this.onChanged,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String suffix;
  final bool decimal;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    final textTheme = Theme.of(context).textTheme;
    return FreshCard(
      color: palette.surface,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: TextField(
        key: fieldKey,
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
          ),
        ],
        style: textTheme.displaySmall?.copyWith(
          color: palette.ink,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          suffixText: suffix,
          suffixStyle: textTheme.titleMedium?.copyWith(
            color: palette.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _RulerScale extends StatelessWidget {
  const _RulerScale({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.majorEvery,
    required this.onChanged,
    this.minLabel,
    this.maxLabel,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final double majorEvery;
  final ValueChanged<double> onChanged;
  final String? minLabel;
  final String? maxLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    return FreshCard(
      color: palette.surface,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        children: [
          SizedBox(
            height: 86,
            child: LayoutBuilder(
              builder: (context, constraints) {
                void updateValue(double dx) {
                  final width = math.max(1.0, constraints.maxWidth);
                  final normalized = (dx / width).clamp(0.0, 1.0).toDouble();
                  final rawValue = min + (max - min) * normalized;
                  final snapped =
                      min + (((rawValue - min) / step).round() * step);
                  onChanged(snapped.clamp(min, max).toDouble());
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => updateValue(details.localPosition.dx),
                  onHorizontalDragStart: (details) =>
                      updateValue(details.localPosition.dx),
                  onHorizontalDragUpdate: (details) =>
                      updateValue(details.localPosition.dx),
                  child: CustomPaint(
                    painter: _RulerPainter(
                      value: value,
                      min: min,
                      max: max,
                      majorEvery: majorEvery,
                      activeColor: palette.limeDeep,
                      tickColor: palette.rule,
                      textColor: palette.inkMuted,
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: FreshSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                minLabel ?? min.toStringAsFixed(0),
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: palette.inkMuted),
              ),
              Text(
                maxLabel ?? max.toStringAsFixed(0),
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: palette.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  const _RulerPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.majorEvery,
    required this.activeColor,
    required this.tickColor,
    required this.textColor,
  });

  final double value;
  final double min;
  final double max;
  final double majorEvery;
  final Color activeColor;
  final Color tickColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final majorPaint = Paint()
      ..color = textColor.withValues(alpha: 0.55)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const ticks = 32;
    final bottom = size.height - 10;
    for (var i = 0; i <= ticks; i++) {
      final x = size.width * i / ticks;
      final tickValue = min + ((max - min) * i / ticks);
      final isMajor = ((tickValue - min) % majorEvery).abs() < 1.8 ||
          (i == 0 || i == ticks);
      final height = isMajor ? 32.0 : (i.isEven ? 22.0 : 14.0);
      canvas.drawLine(
        Offset(x, bottom),
        Offset(x, bottom - height),
        isMajor ? majorPaint : tickPaint,
      );
    }

    final normalized = ((value.clamp(min, max) - min) / (max - min)).toDouble();
    final indicatorX = size.width * normalized;
    canvas.drawLine(
      Offset(indicatorX, bottom + 2),
      Offset(indicatorX, 8),
      activePaint,
    );
    canvas.drawCircle(Offset(indicatorX, 8), 7, activePaint);
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) {
    return value != oldDelegate.value ||
        min != oldDelegate.min ||
        max != oldDelegate.max ||
        activeColor != oldDelegate.activeColor;
  }
}

class _LoadingPlanStep extends StatelessWidget {
  const _LoadingPlanStep();

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Personalizing your calorie plan...',
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w800,
                height: 1.08,
              ),
            ),
            const SizedBox(height: FreshSpacing.xxl),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0, end: 0.65),
              builder: (context, value, child) {
                return _ProgressRing(
                  progress: value,
                  size: 220,
                  center: Text(
                    '${(value * 100).round()}%',
                    style: textTheme.displaySmall?.copyWith(
                      color: palette.ink,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: FreshSpacing.xxl),
            Text(
              'Building a target from your profile and activity.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultPlanStep extends StatelessWidget {
  const _ResultPlanStep({required this.estimate});

  final CalorieEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: FreshSpacing.md),
          Text(
            'Your personalized calorie plan is ready!',
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
          const SizedBox(height: FreshSpacing.xxl),
          Center(
            child: _ProgressRing(
              progress: 1,
              size: 238,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${estimate.targetCalories}',
                    key: const ValueKey('calorie_wizard_target_value'),
                    style: textTheme.displaySmall?.copyWith(
                      color: palette.ink,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    'Kcal',
                    style: textTheme.titleMedium?.copyWith(
                      color: palette.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: FreshSpacing.xxl),
          FreshCard(
            key: const ValueKey('calorie_wizard_result_card'),
            color: palette.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ResultLine(
                  label: 'BMR estimate',
                  value: '${estimate.bmr} Kcal',
                ),
                _ResultLine(
                  label: 'Maintenance',
                  value: '${estimate.maintenanceCalories} Kcal',
                ),
                _ResultLine(
                  label: 'Target range',
                  value:
                      '${estimate.recommendedRangeMin}-${estimate.recommendedRangeMax} Kcal',
                ),
                _ResultLine(
                  label: 'Adjustment',
                  value: '${estimate.adjustmentCalories} Kcal',
                ),
              ],
            ),
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
          if (estimate.explanation.isNotEmpty) ...[
            const SizedBox(height: FreshSpacing.md),
            Text(
              estimate.explanation,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: palette.inkMuted,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: FreshSpacing.lg),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.progress,
    required this.size,
    required this.center,
  });

  final double progress;
  final double size;
  final Widget center;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _ProgressRingPainter(
              progress: progress,
              backgroundColor: Colors.white,
              foregroundColor: palette.lime,
              innerColor: palette.limeWash,
            ),
          ),
          center,
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.progress,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.innerColor,
  });

  final double progress;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color innerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final strokeWidth = radius * 0.17;
    final ringRect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );
    final outerPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final activePaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final innerPaint = Paint()
      ..color = innerColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius - strokeWidth - 4, innerPaint);
    canvas.drawArc(ringRect, 0, math.pi * 2, false, outerPaint);
    canvas.drawArc(
      ringRect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0).toDouble(),
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        backgroundColor != oldDelegate.backgroundColor ||
        foregroundColor != oldDelegate.foregroundColor ||
        innerColor != oldDelegate.innerColor;
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
