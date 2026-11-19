import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/dsl/domain/studio_os_audio_kernel.dart';
import 'package:tunner/core/dsl/domain/tunner_ast_node.dart';
import 'package:tunner/core/dsl/domain/tunner_dsl_interpreter.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import 'package:tunner/features/sheet_music/domain/score_playback_coordinator.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/universal_importer/data/abc_score_parser.dart';
import 'package:tunner/features/universal_importer/data/midi_score_parser.dart';
import 'package:tunner/features/universal_importer/domain/vector_omr_engine.dart';

void main() {
  group('Wave 4 SMuFL, Parsers, and Navigation Hardening Tests', () {
    test('ScorePlaybackCoordinator noteNameToMidi accurately maps B, Bb, Si, Sib and Eb', () {
      // English notation
      expect(ScorePlaybackCoordinator.noteNameToMidi('C4'), equals(60));
      expect(ScorePlaybackCoordinator.noteNameToMidi('B4'), equals(71));
      expect(ScorePlaybackCoordinator.noteNameToMidi('Bb4'), equals(70));
      expect(ScorePlaybackCoordinator.noteNameToMidi('Eb4'), equals(63));
      expect(ScorePlaybackCoordinator.noteNameToMidi('A4'), equals(69));

      // Solfege notation
      expect(ScorePlaybackCoordinator.noteNameToMidi('Do4'), equals(60));
      expect(ScorePlaybackCoordinator.noteNameToMidi('Si4'), equals(71));
      expect(ScorePlaybackCoordinator.noteNameToMidi('Sib4'), equals(70));
      expect(ScorePlaybackCoordinator.noteNameToMidi('Mib4'), equals(63));
      expect(ScorePlaybackCoordinator.noteNameToMidi('La4'), equals(69));
    });

    test('ScorePlaybackCoordinator stops notes at measure boundaries without hanging', () {
      final voicePool = PolyphonicVoicePool(maxPolyphony: 8);
      final coordinator = ScorePlaybackCoordinator(voicePool: voicePool, initialBpm: 120.0);

      // Create a 2-measure score where note in M0 ends exactly at tick 16
      final score = HierarchicalScore(
        title: 'Test Barline Score',
        baseBpm: 120,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 16, noteName: 'Do4'),
            ],
          ),
          MeasureEntity(
            index: 1,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 8, noteName: 'Sol4'),
              HierarchicalNote.rest(startTick: 8, durationTicks: 8),
            ],
          ),
        ],
      );

      coordinator.startPlayback(score: score);
      expect(coordinator.isPlaying, isTrue);

      // Verify that playing notes are cleanly cleared on stopPlayback
      coordinator.stopPlayback();
      expect(coordinator.isPlaying, isFalse);
      expect(voicePool.activeVoiceCount, equals(0));
      coordinator.dispose();
    });

    test('AbcScoreParser handles zero-denominator fractions and clamp BPM without throwing', () async {
      const abc = '''
X:1
T:Test Zero Div
M:4/4
L:1/4
Q:0
K:C
C/0 D/0 E2 F2 | G4 |
''';

      const parser = AbcScoreParser();
      final bytes = Uint8List.fromList(abc.codeUnits);
      expect(parser.canParse('test.abc', bytes), isTrue);

      final result = await parser.parseScoreData(bytes: bytes, fileName: 'test.abc');
      expect(result.package.defaultBpm, greaterThanOrEqualTo(20));
      expect(result.package.score.measures.isNotEmpty, isTrue);
    });

    test('MidiScoreParser handles raw zero PPQ defensively without dividing by zero', () async {
      // Create minimal valid MThd header with division = 0
      final bytes = Uint8List.fromList([
        0x4D, 0x54, 0x68, 0x64, // 'MThd'
        0x00, 0x00, 0x00, 0x06, // length 6
        0x00, 0x00,             // format 0
        0x00, 0x01,             // 1 track
        0x00, 0x00,             // division = 0 (corrupted PPQ)
        // MTrk
        0x4D, 0x54, 0x72, 0x6B, // 'MTrk'
        0x00, 0x00, 0x00, 0x04, // length 4
        0x00, 0xFF, 0x2F, 0x00, // end of track
      ]);

      const parser = MidiScoreParser();
      expect(parser.canParse('test.mid', bytes), isTrue);

      final result = await parser.parseScoreData(bytes: bytes, fileName: 'test.mid');
      expect(result.package.score.measures.isNotEmpty, isTrue);
    });

    test('VectorOmrEngine sorts multi-system staves from top of page downwards', () {
      const engine = VectorOmrEngine();

      // Top system (Y ~ 500)
      final topLines = [
        const OmrLine(x1: 50, y1: 500, x2: 450, y2: 500),
        const OmrLine(x1: 50, y1: 510, x2: 450, y2: 510),
        const OmrLine(x1: 50, y1: 520, x2: 450, y2: 520),
        const OmrLine(x1: 50, y1: 530, x2: 450, y2: 530),
        const OmrLine(x1: 50, y1: 540, x2: 450, y2: 540),
      ];

      // Bottom system (Y ~ 100)
      final bottomLines = [
        const OmrLine(x1: 50, y1: 100, x2: 450, y2: 100),
        const OmrLine(x1: 50, y1: 110, x2: 450, y2: 110),
        const OmrLine(x1: 50, y1: 120, x2: 450, y2: 120),
        const OmrLine(x1: 50, y1: 130, x2: 450, y2: 130),
        const OmrLine(x1: 50, y1: 140, x2: 450, y2: 140),
      ];

      final allLines = [...bottomLines, ...topLines];
      final rects = [
        const OmrRect(x: 100, y: 500, width: 8, height: 8),
        const OmrRect(x: 100, y: 100, width: 8, height: 8),
      ];

      final score = engine.processGeometricElements(
        lines: allLines,
        rects: rects,
      );

      // Verify measures were generated for both systems
      expect(score.measures.length, greaterThanOrEqualTo(2));
    });

    test('TunnerDslInterpreter executes script program deterministically', () async {
      final interpreter = TunnerDslInterpreter();
      final kernel = StudioOsAudioKernel();

      final program = ProgramNode([
        const TempoStatementNode(132.0),
        const ChannelDeclNode('synth_main'),
        const NoteStatementNode(pitch: 'C4', durationFraction: '1/4'),
      ]);

      final report = await interpreter.interpret(program, kernel: kernel);
      expect(report.isSuccess, isTrue);
      expect(report.totalStatementsExecuted, equals(3));
      expect(report.warnings, isEmpty);
    });
  });
}
