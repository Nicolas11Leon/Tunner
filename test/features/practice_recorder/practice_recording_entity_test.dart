import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/practice_recorder/domain/practice_recording_entity.dart';

void main() {
  group('PracticeRecordingEntity Domain Tests', () {
    test('formattedDuration correctly formats minutes and seconds', () {
      final rec1 = PracticeRecordingEntity(
        id: "rec_1",
        filePath: "/tmp/rec1.m4a",
        recordedAt: DateTime(2026, 10, 26, 10, 0),
        duration: const Duration(seconds: 45),
        songTitle: "Para Elisa",
        bpm: 120,
      );
      expect(rec1.formattedDuration, "00:45");

      final rec2 = rec1.copyWith(duration: const Duration(minutes: 2, seconds: 5));
      expect(rec2.formattedDuration, "02:05");
    });

    test('formattedDateTime produces ISO-like readable timestamp', () {
      final rec = PracticeRecordingEntity(
        id: "rec_2",
        filePath: "/tmp/rec2.m4a",
        recordedAt: DateTime(2026, 10, 26, 14, 30),
        duration: const Duration(seconds: 30),
        songTitle: "Canon en Re",
        bpm: 68,
      );
      expect(rec.formattedDateTime, "2026-10-26 14:30");
    });

    test('copyWith preserves unmodified fields and updates targets', () {
      final original = PracticeRecordingEntity(
        id: "orig",
        filePath: "/path/a.m4a",
        recordedAt: DateTime(2026, 1, 1),
        duration: const Duration(seconds: 10),
        songTitle: "Escala Mayor",
        bpm: 80,
        waveformPeaks: const [0.1, 0.4, 0.8],
      );

      final modified = original.copyWith(
        songTitle: "Escala Menor",
        bpm: 90,
      );

      expect(modified.id, "orig");
      expect(modified.filePath, "/path/a.m4a");
      expect(modified.songTitle, "Escala Menor");
      expect(modified.bpm, 90);
      expect(modified.waveformPeaks, const [0.1, 0.4, 0.8]);
    });

    test('toJson and fromJson provide lossless round-trip serialization', () {
      final entity = PracticeRecordingEntity(
        id: "test_roundtrip",
        filePath: "/storage/recordings/take_1.m4a",
        recordedAt: DateTime(2026, 10, 26, 12, 0, 0),
        duration: const Duration(seconds: 90),
        songTitle: "Himno a la Alegría",
        bpm: 112,
        waveformPeaks: const [0.12, 0.45, 0.78, 0.33, 0.95],
      );

      final jsonStr = entity.toJson();
      final restored = PracticeRecordingEntity.fromJson(jsonStr);

      expect(restored.id, entity.id);
      expect(restored.filePath, entity.filePath);
      expect(restored.duration, entity.duration);
      expect(restored.songTitle, entity.songTitle);
      expect(restored.bpm, entity.bpm);
      expect(restored.waveformPeaks, entity.waveformPeaks);
    });
  });
}
