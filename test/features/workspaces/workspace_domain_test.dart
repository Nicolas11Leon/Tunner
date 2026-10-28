import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/workspaces/domain/workspace_type.dart';

void main() {
  group('WorkspaceType Domain Tests', () {
    test('displayName and tagline return correct values for all modes', () {
      expect(WorkspaceType.learning.displayName, 'Aprender');
      expect(WorkspaceType.learning.tagline, contains('Práctica'));

      expect(WorkspaceType.composition.displayName, 'Componer');
      expect(WorkspaceType.composition.tagline, contains('Notación'));

      expect(WorkspaceType.production.displayName, 'Producir');
      expect(WorkspaceType.production.tagline, contains('Laboratorio'));
    });

    test('serializedKey and fromSerializedKey roundtrip correctly', () {
      for (final type in WorkspaceType.values) {
        final key = type.serializedKey;
        final restored = WorkspaceType.fromSerializedKey(key);
        expect(restored, equals(type));
      }

      // Default fallback
      expect(WorkspaceType.fromSerializedKey(null), equals(WorkspaceType.learning));
      expect(WorkspaceType.fromSerializedKey('unknown_key'), equals(WorkspaceType.learning));
    });

    test('WorkspaceConfigurationEntity defaultFor sets correct tool visibilities', () {
      final learning = WorkspaceConfigurationEntity.defaultFor(WorkspaceType.learning);
      expect(learning.showMetronome, isTrue);
      expect(learning.showStrobeTuner, isTrue);
      expect(learning.showAcousticSpectrogram, isFalse);

      final composition = WorkspaceConfigurationEntity.defaultFor(WorkspaceType.composition);
      expect(composition.showSheetMusicCanvas, isTrue);
      expect(composition.showStrobeTuner, isFalse);

      final production = WorkspaceConfigurationEntity.defaultFor(WorkspaceType.production);
      expect(production.showAcousticSpectrogram, isTrue);
      expect(production.showChordAnalyzer, isTrue);
      expect(production.showMetronome, isFalse);
    });

    test('WorkspaceConfigurationEntity toMap and fromMap serialization', () {
      final original = WorkspaceConfigurationEntity.defaultFor(WorkspaceType.production);
      final map = original.toMap();
      final restored = WorkspaceConfigurationEntity.fromMap(map);

      expect(restored.type, equals(WorkspaceType.production));
      expect(restored.showAcousticSpectrogram, isTrue);
      expect(restored.showChordAnalyzer, isTrue);
      expect(restored.showMetronome, isFalse);
    });

    test('WorkspaceConfigurationEntity copyWith preserves and updates values', () {
      final config = WorkspaceConfigurationEntity.defaultFor(WorkspaceType.learning);
      final updated = config.copyWith(showAcousticSpectrogram: true);

      expect(updated.showAcousticSpectrogram, isTrue);
      expect(updated.showMetronome, equals(config.showMetronome));
      expect(updated.type, equals(WorkspaceType.learning));
    });
  });
}
