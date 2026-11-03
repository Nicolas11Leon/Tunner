import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/tuner/domain/instrument_acoustic_filter.dart';

void main() {
  group('InstrumentAcousticFilterConfig Tests', () {
    test('Calculates safe acoustic margins (+-10%) for specific instruments', () {
      // Guitarra estándar: E2 (82.4 Hz) a E6 (1318.5 Hz)
      final config = InstrumentAcousticFilterConfig.forInstrument(
        minFrequencyHz: 82.4,
        maxFrequencyHz: 1318.5,
      );

      expect(config.enabled, isTrue);
      expect(config.minFrequencyHz, closeTo(82.4 * 0.90, 0.01));
      expect(config.maxFrequencyHz, closeTo(1318.5 * 1.10, 0.01));
      expect(config.minClarity, equals(0.82));
      expect(config.isFrequencyAllowed(110.0), isTrue); // A2 Guitarra
      expect(config.isFrequencyAllowed(50.0), isFalse); // Sub-bass fuera de guitarra
      expect(config.isFrequencyAllowed(2000.0), isFalse); // Fuera de tesitura
    });

    test('Universal config allows full 88-key piano chromatic spectrum', () {
      final config = InstrumentAcousticFilterConfig.universal(enabled: false);

      expect(config.enabled, isFalse);
      expect(config.minFrequencyHz, equals(27.5));
      expect(config.maxFrequencyHz, equals(4186.0));
      expect(config.minClarity, equals(0.70));
      expect(config.minConsecutiveFrames, equals(1));
    });
  });

  group('ToneLockTracker State Machine Tests', () {
    late ToneLockTracker tracker;
    late InstrumentAcousticFilterConfig guitarConfig;

    setUp(() {
      guitarConfig = InstrumentAcousticFilterConfig.forInstrument(
        minFrequencyHz: 82.4,
        maxFrequencyHz: 1318.5,
        minClarity: 0.82,
      );
      tracker = ToneLockTracker();
    });

    test('Rejects first isolated frame (provisional state) until confirmed', () {
      // Frame 1: Primer impacto de nota A2 (110.0 Hz)
      final res1 = tracker.processFrame(
        rawPitchHz: 110.0,
        clarity: 0.90,
        config: guitarConfig,
      );
      expect(res1, isNull, reason: 'Un solo frame no debe activar la aguja de inmediato');
      expect(tracker.isLocked, isFalse);

      // Frame 2: Segundo impacto estable (110.2 Hz)
      final res2 = tracker.processFrame(
        rawPitchHz: 110.2,
        clarity: 0.92,
        config: guitarConfig,
      );
      expect(res2, isNotNull);
      expect(res2!, closeTo(110.2, 0.01), reason: 'El segundo frame consecutivo confirma el Tone Lock');
      expect(tracker.isLocked, isTrue);
    });

    test('Rejects speech prosody and erratic pitch transitions', () {
      // Simulación de habla humana casual ("Hola..."):
      // Frame 1: 130 Hz
      tracker.processFrame(
        rawPitchHz: 130.0,
        clarity: 0.85,
        config: guitarConfig,
      );

      // Frame 2: Salto errático vocal a 165 Hz (~410 cents de salto)
      final resVoice = tracker.processFrame(
        rawPitchHz: 165.0,
        clarity: 0.84,
        config: guitarConfig,
      );
      expect(resVoice, isNull, reason: 'La prosodia vocal con saltos > 35 cents debe resetear el Tone Lock');
      expect(tracker.isLocked, isFalse);

      // Frame 3: Otro salto vocal a 140 Hz
      final resVoice2 = tracker.processFrame(
        rawPitchHz: 140.0,
        clarity: 0.83,
        config: guitarConfig,
      );
      expect(resVoice2, isNull, reason: 'El habla errática nunca debe bloquear el afinador');
    });

    test('Rejects frequencies outside the instrument register even if clear', () {
      // Frecuencia de 50.0 Hz (ruido de red eléctrica o murmullo grave)
      final resLow = tracker.processFrame(
        rawPitchHz: 50.0,
        clarity: 0.95,
        config: guitarConfig,
      );
      expect(resLow, isNull);

      final resLow2 = tracker.processFrame(
        rawPitchHz: 50.0,
        clarity: 0.95,
        config: guitarConfig,
      );
      expect(resLow2, isNull, reason: 'Frecuencia fuera de tesitura debe ser descartada');
    });

    test('Resets lock on silence or drop frame', () {
      // Bloquear tono primero
      tracker.processFrame(
        rawPitchHz: 220.0,
        clarity: 0.90,
        config: guitarConfig,
      );
      tracker.processFrame(
        rawPitchHz: 220.0,
        clarity: 0.90,
        config: guitarConfig,
      );
      expect(tracker.isLocked, isTrue);

      // Reset
      tracker.reset();
      expect(tracker.isLocked, isFalse);
    });

    test('Allows immediate pass-through when isolation is disabled', () {
      final openTracker = ToneLockTracker();
      final openConfig = InstrumentAcousticFilterConfig.universal(enabled: false);

      final res = openTracker.processFrame(
        rawPitchHz: 440.0,
        clarity: 0.75,
        config: openConfig,
      );
      expect(res, equals(440.0), reason: 'En modo abierto la respuesta debe ser inmediata');
    });
  });
}
