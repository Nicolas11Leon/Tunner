import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import 'package:tunner/features/sheet_music/domain/score_playback_coordinator.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';

void main() {
  group('ScorePlaybackCoordinator Tests', () {
    late PolyphonicVoicePool voicePool;
    late ScorePlaybackCoordinator coordinator;

    setUp(() {
      voicePool = PolyphonicVoicePool(maxPolyphony: 8);
      coordinator = ScorePlaybackCoordinator(voicePool: voicePool, initialBpm: 120.0);
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('noteNameToMidi converts Solfège and standard notation accurately', () {
      expect(ScorePlaybackCoordinator.noteNameToMidi('Do4'), 60);
      expect(ScorePlaybackCoordinator.noteNameToMidi('C4'), 60);
      expect(ScorePlaybackCoordinator.noteNameToMidi('Do#4'), 61);
      expect(ScorePlaybackCoordinator.noteNameToMidi('C#4'), 61);
      expect(ScorePlaybackCoordinator.noteNameToMidi('Re4'), 62);
      expect(ScorePlaybackCoordinator.noteNameToMidi('Mib4'), 63);
      expect(ScorePlaybackCoordinator.noteNameToMidi('Mi4'), 64);
      expect(ScorePlaybackCoordinator.noteNameToMidi('Fa4'), 65);
      expect(ScorePlaybackCoordinator.noteNameToMidi('Fa#4'), 66);
      expect(ScorePlaybackCoordinator.noteNameToMidi('Sol4'), 67);
      expect(ScorePlaybackCoordinator.noteNameToMidi('La4'), 69); // 440 Hz
      expect(ScorePlaybackCoordinator.noteNameToMidi('A4'), 69);
      expect(ScorePlaybackCoordinator.noteNameToMidi('Si4'), 71);
      expect(ScorePlaybackCoordinator.noteNameToMidi('Do5'), 72);
      expect(ScorePlaybackCoordinator.noteNameToMidi('Fa#5'), 78);
      expect(ScorePlaybackCoordinator.noteNameToMidi(''), -1);
      expect(ScorePlaybackCoordinator.noteNameToMidi('--'), -1);
    });

    test('previewNote activates a voice in the pool', () {
      expect(voicePool.activeVoiceCount, 0);

      final note = HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Do4');
      coordinator.previewNote(note, durationSeconds: 0.1);

      expect(voicePool.activeVoiceCount, 1);
      expect(voicePool.voices.any((v) => v.noteNumber == 60), isTrue);
    });

    test('startPlayback, pause, and stop controls sequencer and voices', () {
      final measure1 = MeasureEntity(
        index: 0,
        timeSignature: TimeSignature.commonTime44,
        notes: [
          HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Do4'),
          HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: 'Mi4'),
          HierarchicalNote.note(startTick: 8, durationTicks: 8, noteName: 'Sol4'),
        ],
      );

      final score = HierarchicalScore(
        title: 'Canon Test',
        baseBpm: 120,
        measures: [measure1],
      );

      int ticksCounted = 0;
      coordinator.onTick = (m, t) {
        ticksCounted++;
      };

      coordinator.startPlayback(score: score);
      expect(coordinator.isPlaying, isTrue);
      expect(voicePool.activeVoiceCount, greaterThan(0));

      coordinator.pausePlayback();
      expect(coordinator.isPlaying, isFalse);

      coordinator.stopPlayback();
      expect(coordinator.isPlaying, isFalse);
      expect(coordinator.currentMeasureIndex, 0);
      expect(coordinator.currentSubTick, 0);
      expect(voicePool.activeVoiceCount, 0);
      expect(ticksCounted, greaterThanOrEqualTo(0));
    });
  });
}
