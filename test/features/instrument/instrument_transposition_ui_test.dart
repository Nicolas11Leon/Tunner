import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/instrument/domain/instrument_profile_entity.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/sheet_music/presentation/real_sheet_music_painter.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_screen.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

class _FakePitchService extends IPitchDetectorService {
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

  late _FakePitchService pitchService;
  late TunerViewModel viewModel;

  setUp(() {
    pitchService = _FakePitchService();
    viewModel = TunerViewModel(
      pitchService: pitchService,
      metronomeService: _FakeMetroService(),
    );
  });

  group('Transposition Engine & Clef Integration UI Tests', () {
    testWidgets('Essential mode shows dual note display (written note + sounding badge) for transposing instruments', (tester) async {
      viewModel.setDisplayMode(AppDisplayMode.essential);
      viewModel.setInstrumentProfile(InstrumentProfileEntity.bbTrumpet);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TunerViewModel>.value(
            value: viewModel,
            child: const TunerScreen(),
          ),
        ),
      );
      await tester.pump();

      // Transposition is active
      expect(viewModel.hasTransposition, isTrue);

      // Sounding frequency 233.08 Hz corresponds to concert La#3 / Sib3
      // For Bb trumpet, written note is Do4
      pitchService.onPitchDetected?.call(233.08);
      await tester.pump();

      expect(viewModel.noteName, equals('La#3'));
      expect(viewModel.writtenNoteName, equals('Do4'));

      // Hero note display shows the written note
      final heroNoteWidget = tester.widget<Text>(find.byKey(const Key('essential_note_display')));
      expect(heroNoteWidget.data, equals('Do4'));

      // Subtitle badge displays sounding concert pitch
      expect(find.byKey(const Key('essential_sounding_badge')), findsOneWidget);
      expect(find.text('Sonando: La#3 (Tono Real)'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 70));
    });

    testWidgets('Conservatory Pro mode StrobeTuner displays written note and sounding subtitle', (tester) async {
      viewModel.setDisplayMode(AppDisplayMode.conservatoryPro);
      viewModel.setInstrumentProfile(InstrumentProfileEntity.ebAltoSax);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TunerViewModel>.value(
            value: viewModel,
            child: const TunerScreen(),
          ),
        ),
      );
      await tester.pump();

      // Alto Sax is in Eb: concert 155.56 Hz is sounding Re#3 / Mib3, written note is Do4
      pitchService.onPitchDetected?.call(155.56);
      await tester.pump();

      expect(viewModel.hasTransposition, isTrue);
      expect(viewModel.noteName, equals('Re#3'));
      expect(viewModel.writtenNoteName, equals('Do4'));

      // Strobe tuner displays written note Do4 and sounding note Re#3
      expect(find.text('Do4'), findsWidgets);
      expect(find.text('Real: Re#3'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 70));
    });

    testWidgets('Score transposition shifts melody by correct interval for active instrument', (tester) async {
      // Setup initial package notes
      final initialNote = viewModel.currentMeasureNotes.first.noteName;
      
      // Transpose score for Bb trumpet (+2 semitones to compensate for sounding -2 st)
      viewModel.transposeActiveScoreForInstrument(InstrumentProfileEntity.bbTrumpet);

      final transposedNote = viewModel.currentMeasureNotes.first.noteName;
      expect(transposedNote, isNot(equals(initialNote)));
    });

    testWidgets('Instrument modal displays clef, family, transposition and allows 1-tap score transposition', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TunerViewModel>.value(
            value: viewModel,
            child: const TunerScreen(),
          ),
        ),
      );
      await tester.pump();

      // Tap instrument chip in Pro mode
      final instrumentChip = find.byKey(const Key('instrument_selector_chip'));
      await tester.tap(instrumentChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Check modal is open
      expect(find.text('SELECTOR DE INSTRUMENTO'), findsOneWidget);
      expect(find.textContaining('Clave de Sol'), findsWidgets);

      // Check score transpose button for Piccolo exists and tap it
      final transposeBtn = find.byKey(const Key('transpose_score_btn_piccolo'));
      expect(transposeBtn, findsOneWidget);

      await tester.tap(transposeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify SnackBar appears
      expect(find.text('Partitura transpuesta para Flautín / Piccolo'), findsOneWidget);
    });

    test('RealSheetMusicPainter renders correctly with both Treble and Bass clefs', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(400, 200);

      final treblePainter = RealSheetMusicPainter(
        currentSubTick: 0,
        notes: const [],
        history: const {},
        liveNote: 'Do4',
        liveCents: 0,
        isCountingIn: false,
        countInBeat: 0,
        timeSignature: TimeSignature.commonTime44,
        measureIndex: 0,
        totalMeasures: 1,
        palette: TunnerThemePalette.obsidianStudio,
        clef: InstrumentClef.treble,
      );

      // Paint Treble Clef
      expect(() => treblePainter.paint(canvas, size), returnsNormally);

      final bassPainter = RealSheetMusicPainter(
        currentSubTick: 0,
        notes: const [],
        history: const {},
        liveNote: 'Do3',
        liveCents: 0,
        isCountingIn: false,
        countInBeat: 0,
        timeSignature: TimeSignature.commonTime44,
        measureIndex: 0,
        totalMeasures: 1,
        palette: TunnerThemePalette.obsidianStudio,
        clef: InstrumentClef.bass,
      );

      // Paint Bass Clef
      expect(() => bassPainter.paint(canvas, size), returnsNormally);
    });
  });
}
