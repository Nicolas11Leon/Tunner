import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/chord_analyzer/domain/chord_entity.dart';
import 'package:tunner/features/chord_analyzer/domain/polyphonic_pitch_entity.dart';
import 'package:tunner/features/chord_analyzer/presentation/chord_analyzer_modal.dart';
import 'package:tunner/features/chord_analyzer/presentation/multi_tone_voicing_widget.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';

class _FakePitchService implements IPitchDetectorService {
  @override
  Function(double pitchHz)? onPitchDetected;
  @override
  Future<void> startRecording() async {}
  @override
  Future<void> stopRecording() async {}
}

class _FakeMetroService implements IMetronomeService {
  @override
  Function(int currentSubTick)? onSubTick;
  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}
  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MultiToneVoicingWidget UI Tests', () {
    const palette = TunnerThemePalette.obsidianStudio;

    testWidgets('Renders placeholder text and icon when no voices are present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiToneVoicingWidget(
              analysisResult: PolyphonicMultiToneAnalysisResult.empty,
              palette: palette,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('multitone_voicing_section')), findsOneWidget);
      expect(find.text('Descomposición Multitonal'), findsOneWidget);
      expect(
        find.text('Toca un acorde en guitarra o piano para descomponer sus notas en tiempo real'),
        findsOneWidget,
      );
    });

    testWidgets('Renders voice cards and pitch strip when voices are detected', (tester) async {
      const voice1 = DetectedPolyphonicVoice(
        noteName: 'Do',
        noteNameInternational: 'C',
        octave: 4,
        pitchClassIndex: 0,
        frequencyHz: 261.63,
        midiNumber: 60,
        centsDeviation: 1.5,
        salience: 1.0,
        harmonicRole: 'Fundamental (Raíz)',
      );
      const voice2 = DetectedPolyphonicVoice(
        noteName: 'Mi',
        noteNameInternational: 'E',
        octave: 4,
        pitchClassIndex: 4,
        frequencyHz: 329.63,
        midiNumber: 64,
        centsDeviation: -2.0,
        salience: 0.85,
        harmonicRole: 'Tercera Mayor',
      );
      const voice3 = DetectedPolyphonicVoice(
        noteName: 'Sol',
        noteNameInternational: 'G',
        octave: 4,
        pitchClassIndex: 7,
        frequencyHz: 392.00,
        midiNumber: 67,
        centsDeviation: 0.0,
        salience: 0.75,
        harmonicRole: 'Quinta Justa',
      );

      final result = PolyphonicMultiToneAnalysisResult(
        voices: [voice1, voice2, voice3],
        chord: const ChordEntity(
          rootNoteIndex: 0,
          quality: ChordQuality.major,
          confidence: 0.90,
          chromaVector: [1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0],
          notes: ['Do', 'Mi', 'Sol'],
        ),
        voicingName: 'Tríada Polifónica',
        isSilence: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiToneVoicingWidget(
              analysisResult: result,
              palette: palette,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('multitone_voice_card_0')), findsOneWidget);
      expect(find.byKey(const Key('multitone_voice_card_1')), findsOneWidget);
      expect(find.byKey(const Key('multitone_voice_card_2')), findsOneWidget);
      expect(find.text('C4'), findsOneWidget);
      expect(find.text('E4'), findsOneWidget);
      expect(find.text('G4'), findsOneWidget);
      expect(find.text('Tríada Polifónica'), findsOneWidget);
      expect(find.text('Distribución de Alturas Activas en Acorde:'), findsOneWidget);
    });
  });

  group('ChordAnalyzerModal & ViewModel Multitone Integration Tests', () {
    late TunerViewModel viewModel;

    setUp(() {
      viewModel = TunerViewModel(
        pitchService: _FakePitchService(),
        metronomeService: _FakeMetroService(),
      );
    });

    testWidgets('ChordAnalyzerModal embeds MultiToneVoicingWidget and reflects detected triad', (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      viewModel.setChordRecognitionActive(true);

      // Sintetizar muestras de tríada C4-E4-G4
      const sampleRate = 44100.0;
      const numSamples = 2048;
      final samples = List<double>.generate(numSamples, (i) {
        final t = i / sampleRate;
        return 0.3 * math.sin(2 * math.pi * 261.63 * t) +
            0.25 * math.sin(2 * math.pi * 329.63 * t) +
            0.22 * math.sin(2 * math.pi * 392.00 * t);
      });

      viewModel.processChordSamples(samples);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => ChordAnalyzerModal.show(ctx, viewModel),
                child: const Text('Open Chord Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Chord Modal'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('multitone_voicing_section')), findsOneWidget);
      expect(viewModel.polyphonicAnalysisResult.hasVoices, isTrue);
      expect(viewModel.polyphonicAnalysisResult.polyphonyCount, greaterThanOrEqualTo(2));
    });
  });
}
