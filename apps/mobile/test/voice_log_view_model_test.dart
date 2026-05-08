import 'dart:async';
import 'dart:io';

import 'package:cal_tracker_mobile/data/repositories/nutrition_repository.dart';
import 'package:cal_tracker_mobile/data/services/audio_recorder_service.dart';
import 'package:cal_tracker_mobile/domain/models/nutrition_models.dart';
import 'package:cal_tracker_mobile/ui/features/voice_log/view_models/voice_log_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNutritionRepository extends Mock implements NutritionRepository {}

class MockAudioRecorderService extends Mock implements AudioRecorderService {}

class FakeFile extends Fake implements File {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeFile());
  });

  group('VoiceLogViewModel', () {
    late MockNutritionRepository mockNutritionRepository;
    late MockAudioRecorderService mockAudioRecorderService;
    late VoiceLogViewModel viewModel;

    setUp(() {
      mockNutritionRepository = MockNutritionRepository();
      mockAudioRecorderService = MockAudioRecorderService();
      when(() => mockAudioRecorderService.dispose()).thenAnswer((_) async {});
      when(() => mockAudioRecorderService.stateStream).thenAnswer((_) => const Stream.empty());
      viewModel = VoiceLogViewModel(
        nutritionRepository: mockNutritionRepository,
        audioRecorderService: mockAudioRecorderService,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('initial state is idle', () {
      expect(viewModel.state, VoiceLogState.idle);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    group('toggleRecording', () {
      test('starts recording when idle', () async {
        when(() => mockAudioRecorderService.hasPermission()).thenAnswer((_) async => true);
        when(() => mockAudioRecorderService.start()).thenAnswer((_) async {});

        final states = <VoiceLogState>[];
        viewModel.addListener(() => states.add(viewModel.state));

        await viewModel.toggleRecording();

        expect(viewModel.state, VoiceLogState.recording);
        verify(() => mockAudioRecorderService.start()).called(1);
      });

      test('stops recording and transitions to transcriptReady', () async {
        when(() => mockAudioRecorderService.hasPermission()).thenAnswer((_) async => true);
        when(() => mockAudioRecorderService.start()).thenAnswer((_) async {});
        when(() => mockAudioRecorderService.stop()).thenAnswer((_) async => const RecordedAudio(path: '/tmp/test.m4a', mimeType: 'audio/m4a', sizeBytes: 1024));
        when(() => mockNutritionRepository.transcribeAudio(any())).thenAnswer((_) async => 'chicken and rice');

        await viewModel.toggleRecording(); // start
        expect(viewModel.state, VoiceLogState.recording);

        // Trigger stop
        await viewModel.toggleRecording();
        
        // Wait for transcribing -> transcriptReady transition
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(viewModel.state, VoiceLogState.transcriptReady);
        expect(viewModel.transcript, 'chicken and rice');
      });

      test('starts a new recording from transcriptReady', () async {
        when(() => mockAudioRecorderService.hasPermission()).thenAnswer((_) async => true);
        when(() => mockAudioRecorderService.start()).thenAnswer((_) async {});
        when(() => mockAudioRecorderService.stop()).thenAnswer((_) async => const RecordedAudio(path: '/tmp/test.m4a', mimeType: 'audio/m4a', sizeBytes: 1024));
        when(() => mockNutritionRepository.transcribeAudio(any())).thenAnswer((_) async => 'chicken and rice');

        await viewModel.toggleRecording();
        await viewModel.toggleRecording();
        expect(viewModel.state, VoiceLogState.transcriptReady);

        await viewModel.toggleRecording();

        expect(viewModel.state, VoiceLogState.recording);
        verify(() => mockAudioRecorderService.start()).called(2);
      });

      test('shows error on permission denied', () async {
        when(() => mockAudioRecorderService.start()).thenThrow(const RecorderException('permission_denied'));

        await viewModel.toggleRecording();

        expect(viewModel.state, VoiceLogState.error);
        expect(viewModel.errorMessage, contains('Microphone permission'));
      });

      test('shows error on transcription failure', () async {
        when(() => mockAudioRecorderService.hasPermission()).thenAnswer((_) async => true);
        when(() => mockAudioRecorderService.start()).thenAnswer((_) async {});
        when(() => mockAudioRecorderService.stop()).thenAnswer((_) async => const RecordedAudio(path: '/tmp/test.m4a', mimeType: 'audio/m4a', sizeBytes: 1024));
        when(() => mockNutritionRepository.transcribeAudio(any())).thenThrow(Exception('network error'));

        await viewModel.toggleRecording(); // start
        expect(viewModel.state, VoiceLogState.recording);

        await viewModel.toggleRecording(); // stop
        await Future.delayed(const Duration(milliseconds: 100));

        expect(viewModel.state, VoiceLogState.error);
        expect(viewModel.errorMessage, contains('Transcription failed'));
      });

      test('starts a new recording from error', () async {
        when(() => mockAudioRecorderService.start()).thenThrow(const RecorderException('permission_denied'));

        await viewModel.toggleRecording();
        expect(viewModel.state, VoiceLogState.error);

        when(() => mockAudioRecorderService.start()).thenAnswer((_) async {});
        await viewModel.toggleRecording();

        expect(viewModel.state, VoiceLogState.recording);
      });
    });

    group('submitText', () {
      test('transitions to proposalReady on proposal result', () async {
        const proposal = MealProposal(
          id: 'prop_1',
          title: 'Chicken and rice',
          confidence: 0.85,
          requiresConfirmation: true,
          trustedAutoCommitEligible: false,
          nutrition: NutritionSnapshot(calories: 500, proteinGrams: 30, carbsGrams: 60, fatGrams: 15),
          items: [],
        );
        when(() => mockNutritionRepository.logText('chicken and rice')).thenAnswer(
          (_) async => const AgentRunResult(
            kind: 'proposal',
            proposal: proposal,
            message: 'Meal proposal created.',
          ),
        );

        await viewModel.submitText('chicken and rice');

        expect(viewModel.state, VoiceLogState.proposalReady);
        expect(viewModel.proposal, proposal);
        expect(viewModel.message, 'Meal proposal created.');
      });

      test('transitions to autoCommitted on meal result', () async {
        final meal = Meal(
          id: 'meal_1',
          title: 'Usual breakfast',
          occurredAt: DateTime.now(),
          nutrition: const NutritionSnapshot(calories: 400, proteinGrams: 20, carbsGrams: 50, fatGrams: 10),
          items: const [],
        );
        when(() => mockNutritionRepository.logText('usual breakfast')).thenAnswer(
          (_) async => AgentRunResult(
            kind: 'meal_committed',
            meal: meal,
            message: 'Meal logged from trusted template.',
          ),
        );

        await viewModel.submitText('usual breakfast');

        expect(viewModel.state, VoiceLogState.autoCommitted);
        expect(viewModel.autoCommittedMeal, meal);
      });

      test('transitions to error on failure', () async {
        when(() => mockNutritionRepository.logText(any())).thenThrow(Exception('network error'));

        await viewModel.submitText('test');

        expect(viewModel.state, VoiceLogState.error);
        expect(viewModel.errorMessage, contains('network error'));
      });

      test('does nothing when text is empty', () async {
        await viewModel.submitText('');
        expect(viewModel.state, VoiceLogState.idle);
      });
    });

    group('commitProposal', () {
      test('commits proposal and transitions to autoCommitted', () async {
        const proposal = MealProposal(
          id: 'prop_1',
          title: 'Chicken and rice',
          confidence: 0.85,
          requiresConfirmation: true,
          trustedAutoCommitEligible: false,
          nutrition: NutritionSnapshot(calories: 500, proteinGrams: 30, carbsGrams: 60, fatGrams: 15),
          items: [],
        );
        final meal = Meal(
          id: 'meal_1',
          title: 'Chicken and rice',
          occurredAt: DateTime.now(),
          nutrition: const NutritionSnapshot(calories: 500, proteinGrams: 30, carbsGrams: 60, fatGrams: 15),
          items: const [],
        );

        when(() => mockNutritionRepository.logText('chicken and rice')).thenAnswer(
          (_) async => const AgentRunResult(
            kind: 'proposal',
            proposal: proposal,
            message: 'Meal proposal created.',
          ),
        );
        when(() => mockNutritionRepository.commitProposal('prop_1')).thenAnswer((_) async => meal);

        await viewModel.submitText('chicken and rice');
        expect(viewModel.state, VoiceLogState.proposalReady);
        expect(viewModel.proposal, proposal);

        await viewModel.commitProposal();

        expect(viewModel.state, VoiceLogState.autoCommitted);
        expect(viewModel.autoCommittedMeal, meal);
        expect(viewModel.proposal, isNull);
      });

      test('does nothing when no proposal exists', () async {
        await viewModel.commitProposal();
        expect(viewModel.state, VoiceLogState.idle);
      });
    });

    group('clearResult', () {
      test('resets all state', () async {
        viewModel.updateTranscript('test');
        viewModel.clearResult();

        expect(viewModel.state, VoiceLogState.idle);
        expect(viewModel.proposal, isNull);
        expect(viewModel.autoCommittedMeal, isNull);
        expect(viewModel.message, isNull);
        expect(viewModel.errorMessage, isNull);
        expect(viewModel.transcript, isEmpty);
      });
    });

    group('retry', () {
      test('clears error and returns to idle', () async {
        viewModel.updateTranscript('test');

        // Simulate error state
        when(() => mockNutritionRepository.logText(any())).thenThrow(Exception('error'));
        await viewModel.submitText();
        expect(viewModel.state, VoiceLogState.error);

        viewModel.retry();

        expect(viewModel.state, VoiceLogState.idle);
        expect(viewModel.errorMessage, isNull);
      });
    });
  });
}
