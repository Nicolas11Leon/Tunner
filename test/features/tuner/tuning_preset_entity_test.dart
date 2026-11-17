import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/tuner/domain/tuning_preset_entity.dart';

void main() {
  group('TuningPresetEntity Domain Unit Tests', () {
    test('instantiates with expected parameters and defaults', () {
      final now = DateTime(2026, 11, 16);
      final preset = TuningPresetEntity(
        id: 'preset_test_1',
        name: 'Sinfónica Viena A442',
        referencePitchHz: 442.0,
        temperamentId: 'equal',
        rootKey: 0,
        description: 'Afinación sinfónica brillante',
        createdAt: now,
      );

      expect(preset.id, equals('preset_test_1'));
      expect(preset.name, equals('Sinfónica Viena A442'));
      expect(preset.referencePitchHz, equals(442.0));
      expect(preset.temperamentId, equals('equal'));
      expect(preset.rootKey, equals(0));
      expect(preset.description, equals('Afinación sinfónica brillante'));
      expect(preset.createdAt, equals(now));
    });

    test('serializes toMap and deserializes fromMap accurately', () {
      final now = DateTime(2026, 11, 16, 14, 30);
      final original = TuningPresetEntity(
        id: 'preset_just_c',
        name: 'Just Intonation C',
        referencePitchHz: 432.0,
        temperamentId: 'just',
        rootKey: 0,
        description: 'Entonación justa pura en Do',
        createdAt: now,
      );

      final map = original.toMap();
      final restored = TuningPresetEntity.fromMap(map);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.referencePitchHz, equals(original.referencePitchHz));
      expect(restored.temperamentId, equals(original.temperamentId));
      expect(restored.rootKey, equals(original.rootKey));
      expect(restored.description, equals(original.description));
      expect(restored, equals(original));
    });

    test('copyWith creates modified clone correctly', () {
      final preset = TuningPresetEntity(
        id: 'preset_orig',
        name: 'A440',
        referencePitchHz: 440.0,
        createdAt: DateTime.now(),
      );

      final updated = preset.copyWith(
        name: 'A443 Brillante',
        referencePitchHz: 443.0,
      );

      expect(updated.id, equals(preset.id));
      expect(updated.name, equals('A443 Brillante'));
      expect(updated.referencePitchHz, equals(443.0));
      expect(updated.temperamentId, equals(preset.temperamentId));
    });
  });
}
