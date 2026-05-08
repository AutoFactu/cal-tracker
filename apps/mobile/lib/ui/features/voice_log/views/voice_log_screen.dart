import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/nutrition_models.dart';
import '../view_models/voice_log_view_model.dart';
import '../../../core/content_frame.dart';

class VoiceLogScreen extends StatefulWidget {
  const VoiceLogScreen({super.key});

  @override
  State<VoiceLogScreen> createState() => _VoiceLogScreenState();
}

class _VoiceLogScreenState extends State<VoiceLogScreen> {
  final _textController = TextEditingController();
  final _textFieldFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<VoiceLogViewModel>();
      if (viewModel.state == VoiceLogState.transcriptReady) {
        FocusScope.of(context).requestFocus(_textFieldFocusNode);
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
    if (_textController.text != viewModel.transcript) {
      _textController.value = TextEditingValue(
        text: viewModel.transcript,
        selection: TextSelection.collapsed(offset: viewModel.transcript.length),
      );
    }

    // Auto-focus text field when transcript is ready
    if (viewModel.state == VoiceLogState.transcriptReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_textFieldFocusNode);
      });
    }

    return ContentFrame(
      title: 'Log Meal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('meal_text_field'),
            controller: _textController,
            focusNode: _textFieldFocusNode,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Meal'),
            onChanged: viewModel.updateTranscript,
            enabled: viewModel.state != VoiceLogState.transcribing && viewModel.state != VoiceLogState.agentRunning,
          ),
          const SizedBox(height: 12),
          _buildControls(context, viewModel),
          const SizedBox(height: 16),
          if (viewModel.isLoading) const LinearProgressIndicator(),
          if (viewModel.state == VoiceLogState.recording)
            _RecordingIndicator(duration: viewModel.recordingDuration),
          if (viewModel.state == VoiceLogState.transcribing)
            const Text('Transcribing...'),
          if (viewModel.errorMessage != null)
            _ErrorBanner(
              message: viewModel.errorMessage!,
              onRetry: viewModel.retry,
            ),
          if (viewModel.autoCommittedMeal != null)
            _LoggedMealBanner(title: viewModel.autoCommittedMeal!.title),
          if (viewModel.proposal != null)
            _ProposalCard(
              proposal: viewModel.proposal!,
              onConfirm: viewModel.commitProposal,
            ),
          if (viewModel.state == VoiceLogState.clarificationRequired)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(viewModel.message ?? 'I\'m not sure what you\'d like to do. Could you rephrase?'),
              ),
            ),
          if (viewModel.summary != null)
            _SummaryCard(summary: viewModel.summary!),
          if (viewModel.remaining != null)
            _RemainingCard(remaining: viewModel.remaining!),
          if (viewModel.meals != null)
            _MealsCard(meals: viewModel.meals!),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, VoiceLogViewModel viewModel) {
    final isRecording = viewModel.state == VoiceLogState.recording;
    final canSubmit = viewModel.state == VoiceLogState.idle ||
        viewModel.state == VoiceLogState.ready ||
        viewModel.state == VoiceLogState.transcriptReady ||
        viewModel.state == VoiceLogState.error;

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('submit_meal_button'),
            icon: const Icon(Icons.send),
            onPressed: canSubmit && !viewModel.isLoading
                ? () => viewModel.submitText(_textController.text)
                : null,
            label: const Text('Submit'),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          key: const ValueKey('mic_button'),
          tooltip: isRecording ? 'Stop recording' : 'Record voice',
          onPressed: viewModel.state == VoiceLogState.stopping ||
                  viewModel.state == VoiceLogState.transcribing ||
                  viewModel.state == VoiceLogState.agentRunning
              ? null
              : viewModel.toggleRecording,
          icon: Icon(isRecording ? Icons.stop : Icons.mic),
          style: isRecording
              ? IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                )
              : null,
        ),
      ],
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
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fiber_manual_record, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Text(
              '$minutes:$seconds',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoggedMealBanner extends StatelessWidget {
  const _LoggedMealBanner({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.check_circle),
        title: Text(title),
        subtitle: const Text('Logged. You can correct it from history.'),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('${summary.consumed.calories} kcal consumed'),
            Text('${summary.remaining.calories} kcal remaining'),
          ],
        ),
      ),
    );
  }
}

class _MealsCard extends StatelessWidget {
  const _MealsCard({required this.meals});

  final List<Meal> meals;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meals', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final meal in meals)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(meal.title),
                trailing: Text('${meal.nutrition.calories} kcal'),
              ),
          ],
        ),
      ),
    );
  }
}

class _RemainingCard extends StatelessWidget {
  const _RemainingCard({required this.remaining});

  final NutritionSnapshot remaining;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remaining', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('${remaining.calories} kcal'),
            Text('${remaining.proteinGrams} g protein'),
          ],
        ),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({required this.proposal, required this.onConfirm});

  final MealProposal proposal;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(proposal.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('${proposal.nutrition.calories} kcal'),
            const SizedBox(height: 8),
            for (final item in proposal.items)
              Text('${item.name} ${item.quantity} ${item.unit}'),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('confirm_proposal_button'),
              onPressed: onConfirm,
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }
}
