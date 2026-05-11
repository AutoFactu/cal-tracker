import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/nutrition_models.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../l10n/meal_label_localizations.dart';
import '../../../core/content_frame.dart';
import '../../../core/design_system.dart';
import '../view_models/voice_log_view_model.dart';

class VoiceLogScreen extends StatefulWidget {
  const VoiceLogScreen({super.key});

  @override
  State<VoiceLogScreen> createState() => _VoiceLogScreenState();
}

class _VoiceLogScreenState extends State<VoiceLogScreen> {
  final _textController = TextEditingController();
  final _textFieldFocusNode = FocusNode();
  bool _transcriptReadyFocusQueued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final viewModel = context.read<VoiceLogViewModel>();
      if (viewModel.state == VoiceLogState.transcriptReady) {
        _requestTextFieldFocus();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<VoiceLogViewModel>();
    final l10n = context.l10n;
    if (_textController.text != viewModel.transcript) {
      _textController.value = TextEditingValue(
        text: viewModel.transcript,
        selection: TextSelection.collapsed(offset: viewModel.transcript.length),
      );
    }

    if (viewModel.state == VoiceLogState.transcriptReady) {
      if (!_transcriptReadyFocusQueued) {
        _transcriptReadyFocusQueued = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || viewModel.state != VoiceLogState.transcriptReady) {
            return;
          }
          _requestTextFieldFocus();
        });
      }
    } else {
      _transcriptReadyFocusQueued = false;
    }

    return ContentFrame(
      title: l10n.voiceTitle,
      subtitle: _stateLabel(viewModel.state, l10n),
      actions: [
        if (viewModel.transcript.isNotEmpty ||
            viewModel.proposal != null ||
            viewModel.autoCommittedMeal != null)
          FreshIconButton(
            key: const ValueKey('voice_log_start_over_button'),
            icon: Icons.refresh_rounded,
            tooltip: l10n.voiceStartOver,
            onPressed: viewModel.clearResult,
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VoiceCaptureCard(viewModel: viewModel),
          const SizedBox(height: FreshSpacing.lg),
          FreshCard(
            padding: const EdgeInsets.all(14),
            child: TextField(
              key: const ValueKey('meal_text_field'),
              controller: _textController,
              focusNode: _textFieldFocusNode,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: l10n.voiceMealFieldLabel,
                hintText: l10n.voiceMealFieldHint,
                prefixIcon: const Icon(Icons.restaurant_rounded),
              ),
              onChanged: viewModel.updateTranscript,
              enabled: viewModel.state != VoiceLogState.transcribing &&
                  viewModel.state != VoiceLogState.agentRunning,
            ),
          ),
          const SizedBox(height: FreshSpacing.md),
          _buildControls(context, viewModel),
          const SizedBox(height: FreshSpacing.lg),
          if (viewModel.isLoading) const LinearProgressIndicator(minHeight: 3),
          if (viewModel.state == VoiceLogState.recording) ...[
            _RecordingIndicator(duration: viewModel.recordingDuration),
            const SizedBox(height: FreshSpacing.md),
          ],
          if (viewModel.state == VoiceLogState.transcribing) ...[
            FreshStatusBanner(
              icon: Icons.graphic_eq_rounded,
              title: l10n.voiceTranscribingTitle,
              message: l10n.voiceTranscribingMessage,
              color: FreshColors.water,
            ),
            const SizedBox(height: FreshSpacing.md),
          ],
          if (viewModel.errorMessage != null) ...[
            _ErrorBanner(
              message: viewModel.errorMessage!,
              onRetry: viewModel.retry,
            ),
            const SizedBox(height: FreshSpacing.md),
          ],
          if (viewModel.autoCommittedMeal != null) ...[
            _LoggedMealBanner(title: viewModel.autoCommittedMeal!.title),
            const SizedBox(height: FreshSpacing.md),
          ],
          if (viewModel.proposal != null) ...[
            _ProposalCard(
              proposal: viewModel.proposal!,
              onConfirm: () => _showMealLabelSheet(context, viewModel),
              onEdit: () => _showProposalEditor(context, viewModel),
            ),
            const SizedBox(height: FreshSpacing.md),
          ],
          if (viewModel.state == VoiceLogState.clarificationRequired) ...[
            FreshStatusBanner(
              icon: Icons.help_outline_rounded,
              title: l10n.voiceClarificationTitle,
              message: viewModel.message ?? l10n.voiceClarificationDefault,
              color: FreshColors.orange,
            ),
            const SizedBox(height: FreshSpacing.md),
          ],
          if (viewModel.candidateGroups != null) ...[
            _ResolverClarificationCard(
              groups: viewModel.candidateGroups!,
              isCandidateSelected: viewModel.isCandidateSelected,
              onCandidateSelected: viewModel.selectCandidate,
              onPortionSelected: (choice) {
                final actionText = choice.actionText;
                if (actionText == null || actionText.isEmpty) return;
                viewModel.submitText(actionText);
              },
            ),
            const SizedBox(height: FreshSpacing.md),
          ],
          if (viewModel.state == VoiceLogState.resultReady &&
              viewModel.message != null) ...[
            _InfoBanner(
              message: _localizedVoiceMessage(context, viewModel.message!),
            ),
            const SizedBox(height: FreshSpacing.md),
          ],
          if (viewModel.summary != null) ...[
            _SummaryCard(summary: viewModel.summary!),
            const SizedBox(height: FreshSpacing.md),
          ],
          if (viewModel.remaining != null) ...[
            _RemainingCard(remaining: viewModel.remaining!),
            const SizedBox(height: FreshSpacing.md),
          ],
          if (viewModel.meals != null) ...[
            _MealsCard(meals: viewModel.meals!),
            const SizedBox(height: FreshSpacing.md),
          ],
          if (viewModel.items != null) ...[
            _NutritionItemsCard(items: viewModel.items!),
            const SizedBox(height: FreshSpacing.md),
          ],
          if (viewModel.templates != null) ...[
            _TemplatesCard(templates: viewModel.templates!),
            const SizedBox(height: FreshSpacing.md),
          ],
          if (viewModel.template != null)
            _TemplatesCard(templates: [viewModel.template!]),
        ],
      ),
    );
  }

  void _requestTextFieldFocus() {
    if (!_textFieldFocusNode.canRequestFocus) return;
    _textFieldFocusNode.requestFocus();
  }

  Future<void> _showProposalEditor(
    BuildContext context,
    VoiceLogViewModel viewModel,
  ) async {
    final proposal = viewModel.proposal;
    if (proposal == null) return;
    final items = await showModalBottomSheet<List<MealItem>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ProposalEditorSheet(proposal: proposal),
    );
    if (items == null || !context.mounted) return;
    await viewModel.updateProposalItems(items);
  }

  Future<void> _showMealLabelSheet(
    BuildContext context,
    VoiceLogViewModel viewModel,
  ) async {
    final selection = await showModalBottomSheet<_MealLabelSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _MealLabelSheet(),
    );
    if (!context.mounted || selection == null) return;
    await viewModel.commitProposal(mealLabel: selection.label);
  }

  Widget _buildControls(BuildContext context, VoiceLogViewModel viewModel) {
    final canSubmit = viewModel.state == VoiceLogState.idle ||
        viewModel.state == VoiceLogState.ready ||
        viewModel.state == VoiceLogState.transcriptReady ||
        viewModel.state == VoiceLogState.resultReady ||
        viewModel.state == VoiceLogState.error;

    return FilledButton.icon(
      key: const ValueKey('submit_meal_button'),
      icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
      onPressed: canSubmit && !viewModel.isLoading
          ? () => viewModel.submitText(_textController.text)
          : null,
      label: Text(context.l10n.voiceSubmitMeal),
    );
  }
}

class _ResolverClarificationCard extends StatelessWidget {
  const _ResolverClarificationCard({
    required this.groups,
    required this.isCandidateSelected,
    required this.onCandidateSelected,
    required this.onPortionSelected,
  });

  final List<FoodCandidateGroup> groups;
  final bool Function(FoodCandidateGroup group, MealItem candidate)
      isCandidateSelected;
  final Future<void> Function(FoodCandidateGroup group, MealItem candidate)
      onCandidateSelected;
  final ValueChanged<FoodPortionChoice> onPortionSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return FreshCard(
      key: const ValueKey('resolver_clarification_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FreshSectionTitle(title: l10n.voiceFoodMatches),
          const SizedBox(height: FreshSpacing.sm),
          for (final group in groups) ...[
            Text(
              '${group.mention.originalText} -> ${group.mention.canonicalEnglishName}',
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            if (group.portionOptions?.isNotEmpty ?? false) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0;
                      index < group.portionOptions!.length;
                      index++)
                    _PortionChoiceChip(
                      key: ValueKey(
                        'portion_option_${group.mention.canonicalEnglishName}_$index',
                      ),
                      choice: group.portionOptions![index],
                      onSelected: onPortionSelected,
                    ),
                ],
              ),
              const SizedBox(height: FreshSpacing.sm),
            ],
            if (group.candidates.isEmpty)
              Text(
                l10n.voiceNoConfidentMatchYet,
                style:
                    textTheme.bodyMedium?.copyWith(color: FreshColors.inkMuted),
              )
            else
              for (var index = 0;
                  index < group.candidates.take(3).length;
                  index++)
                _CandidateMealLine(
                  key: ValueKey(
                    'food_candidate_${group.mention.canonicalEnglishName}_$index',
                  ),
                  candidate: group.candidates[index],
                  selected: isCandidateSelected(group, group.candidates[index]),
                  onSelected: () =>
                      onCandidateSelected(group, group.candidates[index]),
                ),
            const SizedBox(height: FreshSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _CandidateMealLine extends StatelessWidget {
  const _CandidateMealLine({
    super.key,
    required this.candidate,
    required this.selected,
    required this.onSelected,
  });

  final MealItem candidate;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final subtitle = candidate.externalSource ?? candidate.source;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected
            ? FreshColors.lime.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(FreshRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(FreshRadii.md),
          onTap: onSelected,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                FreshIconChip(
                  icon: selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? FreshColors.limeDeep : FreshColors.inkMuted,
                  backgroundColor:
                      selected ? FreshColors.limeSoft : FreshColors.surface,
                  size: 36,
                ),
                const SizedBox(width: FreshSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(candidate.name, style: textTheme.bodyLarge),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: textTheme.bodyMedium
                              ?.copyWith(color: FreshColors.inkMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Text(
                  l10n.caloriesValue(candidate.calories),
                  style: textTheme.labelLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PortionChoiceChip extends StatelessWidget {
  const _PortionChoiceChip({
    super.key,
    required this.choice,
    required this.onSelected,
  });

  final FoodPortionChoice choice;
  final ValueChanged<FoodPortionChoice> onSelected;

  @override
  Widget build(BuildContext context) {
    final grams = choice.totalGrams ?? choice.gramWeight;
    final label = grams == null
        ? choice.label
        : '${choice.label} (${_formatQuantity(grams)} g)';
    final canSelect = choice.actionText?.isNotEmpty ?? false;
    return ActionChip(
      label: Text(label),
      avatar: Icon(canSelect ? Icons.check_rounded : Icons.edit_rounded),
      onPressed: canSelect ? () => onSelected(choice) : null,
    );
  }
}

class _VoiceCaptureCard extends StatelessWidget {
  const _VoiceCaptureCard({required this.viewModel});

  final VoiceLogViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isRecording = viewModel.state == VoiceLogState.recording;
    final isDisabled = viewModel.state == VoiceLogState.stopping ||
        viewModel.state == VoiceLogState.transcribing ||
        viewModel.state == VoiceLogState.agentRunning;
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final limeCardTextColor = FreshPalette.dark.limeWash;
    return FreshCard(
      color: isRecording
          ? FreshColors.coral.withValues(alpha: 0.12)
          : FreshColors.limeSoft,
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
                      icon: isRecording
                          ? Icons.fiber_manual_record_rounded
                          : Icons.bolt_rounded,
                      color: isRecording
                          ? FreshColors.coral
                          : FreshColors.limeDeep,
                      backgroundColor: FreshColors.surface,
                    ),
                    const SizedBox(width: FreshSpacing.sm),
                    Text(
                      isRecording
                          ? l10n.voiceRecordingTitle
                          : l10n.voiceIntakeTitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color:
                            isRecording ? FreshColors.ink : limeCardTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FreshSpacing.md),
                Text(
                  isRecording
                      ? l10n.voiceTapStopWhenDone
                      : l10n.voiceSayMealNaturally,
                  style: textTheme.titleLarge?.copyWith(
                    color: isRecording ? null : limeCardTextColor,
                    fontWeight: FontWeight.w700,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: FreshSpacing.sm),
                Text(
                  l10n.voiceMealFilledWithVoice,
                  style: textTheme.bodyMedium?.copyWith(
                    color:
                        isRecording ? FreshColors.inkSoft : limeCardTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: FreshSpacing.lg),
          SizedBox.square(
            dimension: 76,
            child: IconButton(
              key: const ValueKey('mic_button'),
              tooltip: isRecording
                  ? l10n.voiceStopRecordingTooltip
                  : l10n.voiceRecordVoiceTooltip,
              onPressed: isDisabled ? null : viewModel.toggleRecording,
              icon: Icon(isRecording ? Icons.stop_rounded : Icons.mic_rounded),
              style: IconButton.styleFrom(
                backgroundColor:
                    isRecording ? FreshColors.coral : FreshColors.lime,
                foregroundColor: FreshColors.ink,
                disabledBackgroundColor: FreshColors.surfaceMuted,
                disabledForegroundColor: FreshColors.inkMuted,
                shape: const CircleBorder(),
                iconSize: 34,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return FreshStatusBanner(
      icon: Icons.info_outline_rounded,
      title: context.l10n.commonUpdate,
      message: message,
      color: FreshColors.water,
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  const _RecordingIndicator({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return FreshStatusBanner(
      icon: Icons.fiber_manual_record_rounded,
      title: '$minutes:$seconds',
      message: context.l10n.voiceRecordingIndicator,
      color: FreshColors.coral,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FreshStatusBanner(
      icon: Icons.error_outline_rounded,
      title: context.l10n.voiceErrorTitle,
      message: message,
      color: FreshColors.coral,
      action: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(context.l10n.commonTryAgain),
      ),
    );
  }
}

class _LoggedMealBanner extends StatelessWidget {
  const _LoggedMealBanner({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return FreshStatusBanner(
      icon: Icons.check_rounded,
      title: title,
      message: context.l10n.voiceLoggedMessage,
      color: FreshColors.limeDeep,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FreshCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FreshSectionTitle(title: l10n.voiceTodaySection),
          const SizedBox(height: FreshSpacing.md),
          Row(
            children: [
              Expanded(
                child: _MetricBlock(
                  label: l10n.commonConsumed,
                  value: '${summary.consumed.calories}',
                  unit: l10n.commonKcal,
                  color: FreshColors.lime,
                ),
              ),
              const SizedBox(width: FreshSpacing.md),
              Expanded(
                child: _MetricBlock(
                  label: l10n.commonRemaining,
                  value: '${summary.remaining.calories}',
                  unit: l10n.commonKcal,
                  color: FreshColors.water,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealsCard extends StatelessWidget {
  const _MealsCard({required this.meals});

  final List<Meal> meals;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FreshCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FreshSectionTitle(title: l10n.voiceMealsSection),
          const SizedBox(height: FreshSpacing.sm),
          if (meals.isEmpty)
            FreshEmptyState(
              icon: Icons.restaurant_rounded,
              title: l10n.voiceNoMealsYet,
              message: l10n.voiceNoMealsMessage,
            )
          else
            for (final meal in meals)
              _MealLine(
                title: meal.title,
                subtitle: l10n.voiceItemCount(meal.items.length),
                calories: meal.nutrition.calories,
              ),
        ],
      ),
    );
  }
}

class _NutritionItemsCard extends StatelessWidget {
  const _NutritionItemsCard({required this.items});

  final List<MealItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FreshCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FreshSectionTitle(title: l10n.voiceNutritionMatchesSection),
          const SizedBox(height: FreshSpacing.sm),
          for (final item in items)
            _MealLine(
              title: item.name,
              subtitle: l10n.quantityUnitValue(
                _formatQuantity(item.quantity),
                item.unit,
              ),
              calories: item.calories,
            ),
        ],
      ),
    );
  }
}

class _TemplatesCard extends StatelessWidget {
  const _TemplatesCard({required this.templates});

  final List<MealTemplate> templates;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FreshCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FreshSectionTitle(title: l10n.voiceUsualMealsSection),
          const SizedBox(height: FreshSpacing.sm),
          for (final template in templates)
            _MealLine(
              title: template.title,
              subtitle: template.aliases.join(', '),
              calories: template.nutrition.calories,
            ),
        ],
      ),
    );
  }
}

class _RemainingCard extends StatelessWidget {
  const _RemainingCard({required this.remaining});

  final NutritionSnapshot remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FreshCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FreshSectionTitle(title: l10n.commonRemaining),
          const SizedBox(height: FreshSpacing.md),
          Row(
            children: [
              Expanded(
                child: _MetricBlock(
                  label: l10n.commonCalories,
                  value: '${remaining.calories}',
                  unit: l10n.commonKcal,
                  color: FreshColors.lime,
                ),
              ),
              const SizedBox(width: FreshSpacing.md),
              Expanded(
                child: _MetricBlock(
                  label: l10n.commonProtein,
                  value: _formatQuantity(remaining.proteinGrams),
                  unit: 'g',
                  color: FreshColors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealLabelSelection {
  const _MealLabelSelection(this.label);

  final MealLabel? label;
}

class _MealLabelSheet extends StatefulWidget {
  const _MealLabelSheet();

  @override
  State<_MealLabelSheet> createState() => _MealLabelSheetState();
}

class _MealLabelSheetState extends State<_MealLabelSheet> {
  final _otherController = TextEditingController();
  bool _showOther = false;

  static const _fixedLabels = [
    MealLabel.breakfast,
    MealLabel.lunch,
    MealLabel.dinner,
    MealLabel.snack,
    MealLabel.preWorkout,
    MealLabel.postWorkout,
  ];

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        key: const ValueKey('meal_label_sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: FreshColors.rule,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: FreshSpacing.lg),
          Text(
            l10n.mealLabelQuestion,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: FreshSpacing.sm),
          Text(
            l10n.mealLabelHelper,
            style: textTheme.bodyMedium?.copyWith(color: FreshColors.inkMuted),
          ),
          const SizedBox(height: FreshSpacing.lg),
          Wrap(
            spacing: FreshSpacing.sm,
            runSpacing: FreshSpacing.sm,
            children: [
              for (final label in _fixedLabels)
                ChoiceChip(
                  key: ValueKey('meal_label_${label.type}_option'),
                  label: Text(localizedMealLabel(l10n, label)),
                  selected: false,
                  onSelected: (_) => _select(label),
                ),
              ChoiceChip(
                key: const ValueKey('meal_label_other_option'),
                label: Text(l10n.mealLabelOther),
                selected: _showOther,
                onSelected: (_) => setState(() => _showOther = true),
              ),
            ],
          ),
          if (_showOther) ...[
            const SizedBox(height: FreshSpacing.lg),
            TextField(
              key: const ValueKey('meal_label_other_field'),
              controller: _otherController,
              autofocus: true,
              maxLength: 40,
              decoration: InputDecoration(
                labelText: l10n.mealLabelCustomType,
                hintText: l10n.mealLabelOtherPlaceholder,
                prefixIcon: const Icon(Icons.edit_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: FreshSpacing.sm),
            FilledButton.icon(
              key: const ValueKey('meal_label_other_save_button'),
              onPressed: _otherController.text.trim().isEmpty
                  ? null
                  : () => _select(MealLabel.other(_otherController.text)),
              icon: const Icon(Icons.check_rounded),
              label: Text(l10n.mealLabelSave),
            ),
          ],
          const SizedBox(height: FreshSpacing.md),
          Row(
            children: [
              TextButton(
                key: const ValueKey('meal_label_cancel_button'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonCancel),
              ),
              const Spacer(),
              TextButton(
                key: const ValueKey('meal_label_skip_button'),
                onPressed: () =>
                    Navigator.of(context).pop(const _MealLabelSelection(null)),
                child: Text(l10n.mealLabelSkip),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _select(MealLabel label) {
    Navigator.of(context).pop(_MealLabelSelection(label));
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.onConfirm,
    required this.onEdit,
  });

  final MealProposal proposal;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return FreshCard(
      radius: FreshRadii.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    Text(proposal.title, style: textTheme.titleLarge),
                    Text(
                      l10n.mealProposalReadyToLog,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: FreshColors.inkMuted),
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
          const SizedBox(height: FreshSpacing.lg),
          _MetricBlock(
            label: l10n.commonCalories,
            value: '${proposal.nutrition.calories}',
            unit: l10n.commonKcal,
            color: FreshColors.lime,
          ),
          const SizedBox(height: FreshSpacing.md),
          for (final item in proposal.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${item.name} ${l10n.quantityUnitValue(_formatQuantity(item.quantity), item.unit)}',
                style: textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: FreshSpacing.lg),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('confirm_proposal_button'),
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(l10n.mealProposalConfirm),
                ),
              ),
              const SizedBox(width: FreshSpacing.md),
              FreshIconButton(
                key: const ValueKey('edit_proposal_button'),
                icon: Icons.edit_rounded,
                tooltip: l10n.commonEditIngredients,
                onPressed: onEdit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProposalEditorSheet extends StatefulWidget {
  const _ProposalEditorSheet({required this.proposal});

  final MealProposal proposal;

  @override
  State<_ProposalEditorSheet> createState() => _ProposalEditorSheetState();
}

class _ProposalEditorSheetState extends State<_ProposalEditorSheet> {
  late final List<_EditableMealItem> _items;

  @override
  void initState() {
    super.initState();
    _items = [
      for (final item in widget.proposal.items) _EditableMealItem(item),
    ];
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
    return SafeArea(
      child: Padding(
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
                    color: FreshColors.rule,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: FreshSpacing.lg),
              Text(l10n.commonEditIngredients, style: textTheme.titleLarge),
              const SizedBox(height: FreshSpacing.md),
              for (var index = 0; index < _items.length; index++) ...[
                _EditableIngredientRow(
                  key: ValueKey('proposal_item_editor_$index'),
                  item: _items[index],
                  index: index,
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
                key: const ValueKey('add_proposal_item_button'),
                onPressed: () {
                  setState(() {
                    _items.add(_EditableMealItem.empty());
                  });
                },
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.commonAddIngredient),
              ),
              const SizedBox(height: FreshSpacing.md),
              FilledButton(
                key: const ValueKey('save_proposal_edits_button'),
                onPressed: _save,
                child: Text(l10n.commonSaveEdits),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final edited = <MealItem>[];
    for (final item in _items) {
      final name = item.nameController.text.trim();
      final quantity = double.tryParse(item.quantityController.text.trim());
      final unit = item.unitController.text.trim();
      if (name.isEmpty || quantity == null || quantity <= 0 || unit.isEmpty) {
        continue;
      }
      edited.add(item.toMealItem(name: name, quantity: quantity, unit: unit));
    }
    if (edited.isEmpty) return;
    Navigator.of(context).pop(edited);
  }
}

class _EditableIngredientRow extends StatelessWidget {
  const _EditableIngredientRow({
    super.key,
    required this.item,
    required this.index,
    required this.onDelete,
  });

  final _EditableMealItem item;
  final int index;
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
            key: ValueKey('proposal_item_name_$index'),
            controller: item.nameController,
            decoration: InputDecoration(labelText: l10n.commonIngredient),
          ),
          const SizedBox(height: FreshSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('proposal_item_quantity_$index'),
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
                  key: ValueKey('proposal_item_unit_$index'),
                  controller: item.unitController,
                  decoration: InputDecoration(labelText: l10n.commonUnit),
                ),
              ),
              const SizedBox(width: FreshSpacing.sm),
              IconButton(
                key: ValueKey('delete_proposal_item_$index'),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: l10n.commonDeleteIngredient,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditableMealItem {
  _EditableMealItem(MealItem item) : original = item {
    nameController = TextEditingController(text: item.name);
    quantityController =
        TextEditingController(text: _formatQuantity(item.quantity));
    unitController = TextEditingController(text: item.unit);
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
        ) {
    nameController = TextEditingController();
    quantityController = TextEditingController(text: '100');
    unitController = TextEditingController(text: 'g');
  }

  final MealItem original;
  late final TextEditingController nameController;
  late final TextEditingController quantityController;
  late final TextEditingController unitController;

  MealItem toMealItem({
    required String name,
    required double quantity,
    required String unit,
  }) {
    final factor = original.quantity > 0 ? quantity / original.quantity : 1.0;
    return original.copyWith(
      name: name,
      quantity: quantity,
      unit: unit,
      calories: (original.calories * factor).round(),
      proteinGrams: _roundMacro(original.proteinGrams * factor),
      carbsGrams: _roundMacro(original.carbsGrams * factor),
      fatGrams: _roundMacro(original.fatGrams * factor),
      source: original.source == 'manual_edit'
          ? 'manual_edit'
          : '${original.source}:manual_edit',
    );
  }

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(FreshRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelMedium),
          const SizedBox(height: FreshSpacing.sm),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 4,
            children: [
              Text(
                value,
                style: textTheme.headlineMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(unit, style: textTheme.bodyMedium),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealLine extends StatelessWidget {
  const _MealLine({
    required this.title,
    required this.subtitle,
    required this.calories,
  });

  final String title;
  final String subtitle;
  final int calories;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const FreshIconChip(
            icon: Icons.local_fire_department_rounded,
            color: FreshColors.orange,
            backgroundColor: FreshColors.yellow,
            size: 36,
          ),
          const SizedBox(width: FreshSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.bodyLarge),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: textTheme.bodyMedium
                        ?.copyWith(color: FreshColors.inkMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            context.l10n.caloriesValue(calories),
            style: textTheme.labelLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
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

double _roundMacro(double value) => (value * 10).roundToDouble() / 10;

String _stateLabel(VoiceLogState state, AppLocalizations l10n) {
  return switch (state) {
    VoiceLogState.recording => l10n.voiceStateListening,
    VoiceLogState.stopping => l10n.voiceStateSavingAudio,
    VoiceLogState.transcribing => l10n.voiceStateWhisperTranscription,
    VoiceLogState.transcriptReady => l10n.voiceStateTranscriptReady,
    VoiceLogState.agentRunning => l10n.voiceStateBuildingProposal,
    VoiceLogState.proposalReady => l10n.voiceStateReviewMeal,
    VoiceLogState.autoCommitted => l10n.voiceStateLogged,
    VoiceLogState.resultReady => l10n.voiceStateResultReady,
    VoiceLogState.clarificationRequired => l10n.voiceStateClarification,
    VoiceLogState.error => l10n.voiceStateNeedsAttention,
    _ => l10n.voiceStateInput,
  };
}

String _localizedVoiceMessage(BuildContext context, String message) {
  final l10n = context.l10n;
  return switch (message) {
    'Meal logged.' => l10n.voiceMessageMealLogged,
    'Proposal updated.' => l10n.voiceMessageProposalUpdated,
    'Meal proposal created.' => l10n.voiceMessageMealProposalCreated,
    _ => message,
  };
}
