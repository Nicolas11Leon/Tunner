import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/modular_rack/domain/module_connection.dart';
import 'package:tunner/features/modular_rack/domain/port_id.dart';
import 'package:tunner/features/modular_rack/domain/signal_bus.dart';
import 'package:tunner/features/modular_rack/domain/signal_type.dart';
import 'package:tunner/features/modular_rack/domain/synergy_policy_engine.dart';

void main() {
  group('SynergyPolicyEngine Domain Tests', () {
    test('Approves Hyper-Synergy 1: Metronome clock to Score Notation', () {
      const src = PortId(
        id: 'metronome.clock_out',
        displayName: 'Clock Out',
        ownerModuleId: 'metronome',
        direction: PortDirection.output,
        signalType: SignalType.temporalClock,
      );
      const dest = PortId(
        id: 'score_notation.clock_in',
        displayName: 'Clock In',
        ownerModuleId: 'score_notation',
        direction: PortDirection.input,
        signalType: SignalType.temporalClock,
      );

      final result = SynergyPolicyEngine.validateConnection(
        sourcePort: src,
        destinationPort: dest,
      );

      expect(result.isApproved, isTrue);
      expect(result.isHyperSynergy, isTrue);
      expect(result.pedagogicalNote, contains('Lectura en Vuelo'));
    });

    test('Approves Hyper-Synergy 2: Vocal Autotune to Practice Recorder', () {
      const src = PortId(
        id: 'vocal_autotune.wet_audio_out',
        displayName: 'Wet Audio Out',
        ownerModuleId: 'vocal_autotune',
        direction: PortDirection.output,
        signalType: SignalType.audioPcm,
      );
      const dest = PortId(
        id: 'practice_recorder.audio_in',
        displayName: 'Audio In',
        ownerModuleId: 'practice_recorder',
        direction: PortDirection.input,
        signalType: SignalType.audioPcm,
      );

      final result = SynergyPolicyEngine.validateConnection(
        sourcePort: src,
        destinationPort: dest,
      );

      expect(result.isApproved, isTrue);
      expect(result.isHyperSynergy, isTrue);
      expect(result.pedagogicalNote, contains('Suite Vocal'));
    });

    test('Approves Hyper-Synergy 5: Harmonic Drone to Spectrogram', () {
      const src = PortId(
        id: 'harmonic_drone.audio_out',
        displayName: 'Drone Audio Out',
        ownerModuleId: 'harmonic_drone',
        direction: PortDirection.output,
        signalType: SignalType.audioPcm,
      );
      const dest = PortId(
        id: 'spectrogram.audio_in',
        displayName: 'Audio In',
        ownerModuleId: 'spectrogram',
        direction: PortDirection.input,
        signalType: SignalType.audioPcm,
      );

      final result = SynergyPolicyEngine.validateConnection(
        sourcePort: src,
        destinationPort: dest,
      );

      expect(result.isApproved, isTrue);
      expect(result.isHyperSynergy, isTrue);
      expect(result.pedagogicalNote, contains('Afinación Pura por Batimento'));
    });

    test('Rejects forced anti-pattern: Vocal Autotune into Blind Ear Trainer', () {
      const src = PortId(
        id: 'vocal_autotune.audio_out',
        displayName: 'Autotune Out',
        ownerModuleId: 'vocal_autotune',
        direction: PortDirection.output,
        signalType: SignalType.audioPcm,
      );
      const dest = PortId(
        id: 'ear_trainer.mic_audio_in',
        displayName: 'Mic In',
        ownerModuleId: 'ear_trainer',
        direction: PortDirection.input,
        signalType: SignalType.audioPcm,
      );

      final result = SynergyPolicyEngine.validateConnection(
        sourcePort: src,
        destinationPort: dest,
      );

      expect(result.isApproved, isFalse);
      expect(result.rejectionReason, contains('Conflicto pedagógico'));
      expect(result.pedagogicalNote, contains('desarrollar el oído interno'));
    });

    test('Rejects forced anti-pattern: Polyphonic Chord Analyzer into Monophonic Strobe Tuner MPM', () {
      const src = PortId(
        id: 'chord_analyzer.poly_audio_out',
        displayName: 'Poly Audio Out',
        ownerModuleId: 'chord_analyzer',
        direction: PortDirection.output,
        signalType: SignalType.audioPcm,
      );
      const dest = PortId(
        id: 'strobe_tuner.audio_in',
        displayName: 'Audio In',
        ownerModuleId: 'strobe_tuner',
        direction: PortDirection.input,
        signalType: SignalType.audioPcm,
      );

      final result = SynergyPolicyEngine.validateConnection(
        sourcePort: src,
        destinationPort: dest,
      );

      expect(result.isApproved, isFalse);
      expect(result.rejectionReason, contains('Conflicto acústico'));
      expect(result.rejectionReason, contains('distorsión de fase NSDF'));
    });

    test('Rejects signal type mismatch: temporalClock into audioPcm', () {
      const src = PortId(
        id: 'metronome.clock_out',
        displayName: 'Clock Out',
        ownerModuleId: 'metronome',
        direction: PortDirection.output,
        signalType: SignalType.temporalClock,
      );
      const dest = PortId(
        id: 'spectrogram.audio_in',
        displayName: 'Audio In',
        ownerModuleId: 'spectrogram',
        direction: PortDirection.input,
        signalType: SignalType.audioPcm,
      );

      final result = SynergyPolicyEngine.validateConnection(
        sourcePort: src,
        destinationPort: dest,
      );

      expect(result.isApproved, isFalse);
      expect(result.rejectionReason, contains('Incompatibilidad de tipos de señal'));
    });

    test('Rejects invalid port directions (output to output or input to input)', () {
      const out1 = PortId(
        id: 'metronome.clock_out',
        displayName: 'Clock Out',
        ownerModuleId: 'metronome',
        direction: PortDirection.output,
        signalType: SignalType.temporalClock,
      );
      const out2 = PortId(
        id: 'score.clock_out',
        displayName: 'Clock Out 2',
        ownerModuleId: 'score',
        direction: PortDirection.output,
        signalType: SignalType.temporalClock,
      );

      final result = SynergyPolicyEngine.validateConnection(
        sourcePort: out1,
        destinationPort: out2,
      );

      expect(result.isApproved, isFalse);
      expect(result.rejectionReason, contains('El puerto de destino debe ser de entrada'));
    });

    test('SignalBus throws ArgumentError when attempting a rejected connection', () {
      final bus = SignalBus();

      const src = PortId(
        id: 'vocal_autotune.audio_out',
        displayName: 'Autotune Audio Out',
        ownerModuleId: 'vocal_autotune',
        direction: PortDirection.output,
        signalType: SignalType.audioPcm,
      );
      const dest = PortId(
        id: 'ear_trainer.audio_in',
        displayName: 'Ear Trainer Audio In',
        ownerModuleId: 'ear_trainer',
        direction: PortDirection.input,
        signalType: SignalType.audioPcm,
      );

      expect(
        () => bus.addConnection(
          ModuleConnection.pointToPoint(source: src, destination: dest),
        ),
        throwsArgumentError,
      );
    });
  });
}
