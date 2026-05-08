import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../data/repositories/nutrition_repository.dart';
import '../../../../data/services/audio_recorder_service.dart';
import '../../../../domain/models/nutrition_models.dart';

enum VoiceLogState {
  idle,
  requestingPermission,
  ready,
  recording,
  stopping,
  transcribing,
  transcriptReady,
  agentRunning,
  proposalReady,
  autoCommitted,
  clarificationRequired,
  error,
}

class VoiceLogUiState {
  const VoiceLogUiState({
    this.phase = VoiceLogState.idle,
    this.errorMessage,
    this.message,
    this.transcript = '',
    this.recordingDuration = Duration.zero,
    this.proposal,
    this.autoCommittedMeal,
    this.summary,
    this.remaining,
    this.meals,
    this.confirmationActionId,
    this.confirmationInput,
  });

  final VoiceLogState phase;
  final String? errorMessage;
  final String? message;
  final String transcript;
  final Duration recordingDuration;
  final MealProposal? proposal;
  final Meal? autoCommittedMeal;
  final DailySummary? summary;
  final NutritionSnapshot? remaining;
  final List<Meal>? meals;
  final String? confirmationActionId;
  final Object? confirmationInput;

  bool get isLoading =>
      phase == VoiceLogState.transcribing ||
      phase == VoiceLogState.agentRunning ||
      phase == VoiceLogState.stopping;

  VoiceLogUiState copyWith({
    VoiceLogState? phase,
    Object? errorMessage = _unchanged,
    Object? message = _unchanged,
    String? transcript,
    Duration? recordingDuration,
    Object? proposal = _unchanged,
    Object? autoCommittedMeal = _unchanged,
    Object? summary = _unchanged,
    Object? remaining = _unchanged,
    Object? meals = _unchanged,
    Object? confirmationActionId = _unchanged,
    Object? confirmationInput = _unchanged,
  }) {
    return VoiceLogUiState(
      phase: phase ?? this.phase,
      errorMessage: identical(errorMessage, _unchanged) ? this.errorMessage : errorMessage as String?,
      message: identical(message, _unchanged) ? this.message : message as String?,
      transcript: transcript ?? this.transcript,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      proposal: identical(proposal, _unchanged) ? this.proposal : proposal as MealProposal?,
      autoCommittedMeal: identical(autoCommittedMeal, _unchanged) ? this.autoCommittedMeal : autoCommittedMeal as Meal?,
      summary: identical(summary, _unchanged) ? this.summary : summary as DailySummary?,
      remaining: identical(remaining, _unchanged) ? this.remaining : remaining as NutritionSnapshot?,
      meals: identical(meals, _unchanged) ? this.meals : meals as List<Meal>?,
      confirmationActionId: identical(confirmationActionId, _unchanged) ? this.confirmationActionId : confirmationActionId as String?,
      confirmationInput: identical(confirmationInput, _unchanged) ? this.confirmationInput : confirmationInput,
    );
  }
}

const Object _unchanged = Object();

class VoiceLogViewModel extends ChangeNotifier {
  VoiceLogViewModel({
    required NutritionRepository nutritionRepository,
    AudioRecorderService? audioRecorderService,
  })  : _nutritionRepository = nutritionRepository,
        _audioRecorderService = audioRecorderService ?? AudioRecorderService();

  final NutritionRepository _nutritionRepository;
  final AudioRecorderService _audioRecorderService;

  VoiceLogUiState _uiState = const VoiceLogUiState();
  VoiceLogUiState get uiState => _uiState;

  VoiceLogState get state => _uiState.phase;

  String? get errorMessage => _uiState.errorMessage;

  String? get message => _uiState.message;

  String get transcript => _uiState.transcript;

  Duration get recordingDuration => _uiState.recordingDuration;

  Timer? _durationTimer;

  MealProposal? get proposal => _uiState.proposal;

  Meal? get autoCommittedMeal => _uiState.autoCommittedMeal;

  DailySummary? get summary => _uiState.summary;

  NutritionSnapshot? get remaining => _uiState.remaining;

  List<Meal>? get meals => _uiState.meals;

  bool get isLoading => _uiState.isLoading;

  Future<void> toggleRecording() async {
    if (_canStartRecording) {
      await _startRecording();
    } else if (state == VoiceLogState.recording) {
      await _stopRecording();
    }
  }

  bool get _canStartRecording =>
      state == VoiceLogState.idle ||
      state == VoiceLogState.ready ||
      state == VoiceLogState.transcriptReady ||
      state == VoiceLogState.error ||
      state == VoiceLogState.proposalReady ||
      state == VoiceLogState.autoCommitted ||
      state == VoiceLogState.clarificationRequired;

  Future<void> _startRecording() async {
    _setUiState(_uiState.copyWith(
      phase: VoiceLogState.requestingPermission,
      errorMessage: null,
      message: null,
      proposal: null,
      autoCommittedMeal: null,
      summary: null,
      remaining: null,
      meals: null,
      confirmationActionId: null,
      confirmationInput: null,
    ));
    try {
      await _audioRecorderService.start();
      _setUiState(_uiState.copyWith(recordingDuration: Duration.zero));
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _setUiState(_uiState.copyWith(recordingDuration: _uiState.recordingDuration + const Duration(seconds: 1)));
      });
      _setState(VoiceLogState.recording);
    } on RecorderException catch (e) {
      if (e.code == 'permission_denied') {
        _setError('Microphone permission is required to record voice logs.');
      } else {
        _setError('Recording failed: ${e.toString()}');
      }
    } catch (e) {
      _setError('Recording failed: ${e.toString()}');
    }
  }

  Future<void> _stopRecording() async {
    _durationTimer?.cancel();
    _setState(VoiceLogState.stopping);
    try {
      final audio = await _audioRecorderService.stop();
      if (audio != null) {
        await _transcribe(audio.path);
      } else {
        _setError('No audio file was created.');
      }
    } on RecorderException catch (e) {
      _setError(e.message ?? 'Recording failed: ${e.toString()}');
    } catch (e) {
      _setError('Recording failed: ${e.toString()}');
    }
  }

  Future<void> _transcribe(String path) async {
    _setState(VoiceLogState.transcribing);
    try {
      final transcript = await _nutritionRepository.transcribeAudio(File(path));
      _setUiState(_uiState.copyWith(transcript: transcript, errorMessage: null));
      _setState(VoiceLogState.transcriptReady);
    } catch (e) {
      _setError('Transcription failed: ${e.toString()}');
    } finally {
      try {
        await File(path).delete();
      } catch (_) {
        // ignore cleanup errors
      }
    }
  }

  void updateTranscript(String value) {
    _setUiState(_uiState.copyWith(transcript: value));
  }

  Future<void> submitText([String? overrideText]) async {
    final text = (overrideText ?? _uiState.transcript).trim();
    if (text.isEmpty) return;
    _setUiState(_uiState.copyWith(
      phase: VoiceLogState.agentRunning,
      transcript: text,
      errorMessage: null,
      message: null,
      proposal: null,
      autoCommittedMeal: null,
      summary: null,
      remaining: null,
      meals: null,
      confirmationActionId: null,
      confirmationInput: null,
    ));
    try {
      final result = await _nutritionRepository.logText(text);
      VoiceLogState nextState;
      switch (result.kind) {
        case 'meal_committed':
          nextState = VoiceLogState.autoCommitted;
          break;
        case 'proposal':
          nextState = VoiceLogState.proposalReady;
          break;
        case 'clarification_required':
        case 'confirmation_required':
          nextState = VoiceLogState.clarificationRequired;
          break;
        case 'summary':
        case 'remaining_targets':
        case 'history':
          nextState = VoiceLogState.clarificationRequired;
          break;
        default:
          nextState = VoiceLogState.clarificationRequired;
      }
      _setUiState(_uiState.copyWith(
        phase: nextState,
        proposal: result.proposal,
        autoCommittedMeal: result.meal,
        summary: result.summary,
        remaining: result.remaining,
        meals: result.meals,
        message: result.message,
        errorMessage: null,
        confirmationActionId: result.actionId,
        confirmationInput: result.input,
      ));
    } catch (error) {
      _setError('Agent failed: ${error.toString()}');
    }
  }

  Future<void> commitProposal() async {
    final proposal = _uiState.proposal;
    if (proposal == null) return;
    _setState(VoiceLogState.agentRunning);
    try {
      final meal = await _nutritionRepository.commitProposal(proposal.id);
      _setUiState(_uiState.copyWith(
        phase: VoiceLogState.autoCommitted,
        autoCommittedMeal: meal,
        proposal: null,
        message: 'Meal logged.',
        errorMessage: null,
      ));
    } catch (error) {
      _setError('Commit failed: ${error.toString()}');
    }
  }

  void clearResult() {
    _setUiState(const VoiceLogUiState());
  }

  void retry() {
    _setUiState(_uiState.copyWith(phase: VoiceLogState.idle, errorMessage: null));
  }

  void _setState(VoiceLogState value) {
    _setUiState(_uiState.copyWith(phase: value));
  }

  void _setError(String message) {
    _setUiState(_uiState.copyWith(phase: VoiceLogState.error, errorMessage: message));
  }

  void _setUiState(VoiceLogUiState value) {
    _uiState = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _audioRecorderService.dispose();
    _durationTimer?.cancel();
    super.dispose();
  }
}
