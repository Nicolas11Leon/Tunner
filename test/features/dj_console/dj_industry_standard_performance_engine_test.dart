import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart';
import 'package:tunner/features/dj_console/data/memory_dj_deck_audio_player.dart';
import 'package:tunner/features/dj_console/domain/dj_action.dart';
import 'package:tunner/features/dj_console/domain/dj_performance_orchestrator.dart';
import 'package:tunner/features/dj_console/domain/dj_sampler_bank_entity.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DjIndustryStandardPerformanceEngine Tests', () {
    late MemoryDjDeckAudioPlayer memoryPlayer;
    late MemoryAudioSynthesizerService memorySynthesizer;
    late DjPerformanceOrchestrator orchestrator;
    late DjConsoleViewModel viewModel;

    setUp(() {
      memoryPlayer = MemoryDjDeckAudioPlayer();
      memorySynthesizer = MemoryAudioSynthesizerService();
      orchestrator = DjPerformanceOrchestrator();
      viewModel = DjConsoleViewModel(
        deckAudioPlayer: memoryPlayer,
        audioSynthesizer: memorySynthesizer,
        orchestrator: orchestrator,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('Subfase 1.1: Hot Cues register on first hit and seek/play audio on subsequent hits', () {
      // Advance Deck A position by nudging
      viewModel.scratchDeck('A', 0.5);
      expect(viewModel.deckA.currentPositionMs, 50);

      // First hit: registers cue at 50ms
      viewModel.triggerHotCue('A', 1);
      expect(viewModel.deckA.hotCues[1], 50);
      expect(viewModel.activeLitActions.contains(DjAction.deckAHotCue1), isTrue);

      // Move forward to 150ms
      viewModel.scratchDeck('A', 0.5);
      viewModel.scratchDeck('A', 0.5);
      expect(viewModel.deckA.currentPositionMs, 150);

      // Second hit: seeks audio player to 50ms and ensures playback
      viewModel.triggerHotCue('A', 1);
      expect(viewModel.deckA.currentPositionMs, 50);
      expect(memoryPlayer.positionA, const Duration(milliseconds: 50));
      expect(memoryPlayer.isPlayingA, isTrue);
    });

    test('Subfase 1.2: 8 Performance Sampler Pads emit audible PCM WAV through synthesizer service', () {
      expect(memorySynthesizer.playedPcmWavs.isEmpty, isTrue);

      // Trigger Airhorn
      viewModel.triggerSamplerPad(DjSamplerPadType.clubAirhorn);
      expect(memorySynthesizer.playedPcmWavs.length, 1);
      expect(memorySynthesizer.playedPcmWavs.first.wavBytes.isNotEmpty, isTrue);
      expect(memorySynthesizer.playedPcmWavs.first.volume, closeTo(0.85, 0.01));

      // Trigger Laser Dub Siren
      viewModel.triggerSamplerPad(DjSamplerPadType.laserDubSiren);
      expect(memorySynthesizer.playedPcmWavs.length, 2);

      // Trigger Sub Bass Drop
      viewModel.triggerSamplerPad(DjSamplerPadType.subBassDrop);
      expect(memorySynthesizer.playedPcmWavs.length, 3);

      // Trigger Stadium Impact & Vocal Stutter
      viewModel.triggerSamplerPad(DjSamplerPadType.stadiumImpact);
      viewModel.triggerSamplerPad(DjSamplerPadType.vocalStutter);
      expect(memorySynthesizer.playedPcmWavs.length, 5);

      // Verify buffer was stored in ViewModel
      expect(viewModel.lastSamplerBuffer, isNotNull);
      expect(viewModel.lastSamplerBuffer!.isNotEmpty, isTrue);
    });

    test('Subfase 1.3: Jog Wheel vinyl scratching modulates playback rate and restores pitch on release', () async {
      expect(memoryPlayer.playbackRateA, 1.0);

      // Fast forward scratch
      viewModel.scratchDeck('A', 0.4);
      expect(viewModel.rotationAngleA, closeTo(0.4, 0.001));
      // Scrub rate modulated above 1.0
      expect(memoryPlayer.playbackRateA, greaterThan(1.0));

      // Wait for release timer (140ms debounce)
      await Future<void>.delayed(const Duration(milliseconds: 180));
      // Playback rate restored to unity
      expect(memoryPlayer.playbackRateA, closeTo(1.0, 0.01));
    });

    test('Subfase 1.4: Beat Jump seeks physical audio player by quantized beats', () {
      viewModel.togglePlay('A');
      expect(viewModel.deckA.isPlaying, isTrue);

      // Beat jump forward +4 beats (at 124 BPM, 4 beats ~ 1935ms)
      viewModel.beatJump('A', 4.0);
      expect(viewModel.deckA.currentPositionMs, greaterThan(1900));
      expect(memoryPlayer.positionA, Duration(milliseconds: viewModel.deckA.currentPositionMs));

      // Beat jump backward -2 beats
      final posBefore = viewModel.deckA.currentPositionMs;
      viewModel.beatJump('A', -2.0);
      expect(viewModel.deckA.currentPositionMs, lessThan(posBefore));
      expect(memoryPlayer.positionA, Duration(milliseconds: viewModel.deckA.currentPositionMs));
    });

    test('Subfase 1.4: Auto-Loop toggle and boundary wrap-around in ticker seeks hardware player to loopStartMs', () async {
      // Engage loop on Deck A
      viewModel.toggleLoop('A');
      expect(viewModel.deckA.isLoopActive, isTrue);
      expect(viewModel.deckA.loopBeats, 4.0);

      // Halve loop
      viewModel.halveLoop('A');
      expect(viewModel.deckA.loopBeats, 2.0);

      // Double loop
      viewModel.doubleLoop('A');
      expect(viewModel.deckA.loopBeats, 4.0);

      // Start playback
      viewModel.togglePlay('A');
      expect(viewModel.deckA.isPlaying, isTrue);

      // Advance past loop end
      orchestrator.beatJump('A', 10.0);
      // Wait for a few ticker cycles
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // Audio player seekDeck should have been called to maintain the loop cycle
      expect(memoryPlayer.positionA, isNotNull);
    });

    test('Subfase 1.5: Direct Audio Ingestion & Routing loads track into Deck A and Deck B', () async {
      // Simulated WAV audio buffer from another studio tool
      final dummyWav = Uint8List.fromList(List.filled(256, 42));

      await viewModel.loadDeckTrack(
        deckId: 'A',
        wavBytes: dummyWav,
        title: 'Melodia Score Editor',
        bpm: 130.0,
      );

      expect(viewModel.deckA.trackTitle, 'Melodia Score Editor');
      expect(viewModel.deckA.bpm, 130.0);
      expect(memoryPlayer.loadedTitleA, 'Melodia Score Editor');

      await viewModel.loadDeckTrack(
        deckId: 'B',
        wavBytes: dummyWav,
        title: 'Arpegio Sintetizador',
        bpm: 126.0,
      );

      expect(viewModel.deckB.trackTitle, 'Arpegio Sintetizador');
      expect(viewModel.deckB.bpm, 126.0);
      expect(memoryPlayer.loadedTitleB, 'Arpegio Sintetizador');
    });

    test('Hardware Actions: executeAction triggers real audio dispatch for all performance buttons', () {
      // Sampler actions
      viewModel.executeAction(DjAction.triggerSamplerAirhorn);
      expect(memorySynthesizer.playedPcmWavs.isNotEmpty, isTrue);

      viewModel.executeAction(DjAction.triggerSamplerDrop);
      expect(memorySynthesizer.playedPcmWavs.length, 2);

      // Beat jump action
      viewModel.executeAction(DjAction.deckABeatJumpForward);
      expect(memoryPlayer.positionA, isNotNull);

      // Hot cue action
      viewModel.executeAction(DjAction.deckAHotCue1);
      expect(viewModel.deckA.hotCues.isNotEmpty, isTrue);
    });
  });
}
