import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/modular_rack/domain/module_connection.dart';
import 'package:tunner/features/modular_rack/domain/port_id.dart';
import 'package:tunner/features/modular_rack/domain/port_permission_broker.dart';
import 'package:tunner/features/modular_rack/domain/signal_type.dart';
import 'package:tunner/features/tuner/domain/hardware_audio_endpoint.dart';

void main() {
  const broker = PortPermissionBroker();

  group('PortPermissionBroker - Connection Authorization', () {
    const micOut = PortId(
      id: 'mic.raw_pcm',
      displayName: 'Captura PCM Mic',
      signalType: SignalType.audioPcm,
      direction: PortDirection.output,
      ownerModuleId: 'module_mic',
    );

    const tunerIn = PortId(
      id: 'tuner.audio_in',
      displayName: 'Entrada Afinador',
      signalType: SignalType.audioPcm,
      direction: PortDirection.input,
      ownerModuleId: 'module_tuner',
    );

    const tunerNoteOut = PortId(
      id: 'tuner.note_events',
      displayName: 'Notas Afinador',
      signalType: SignalType.pitchEvents,
      direction: PortDirection.output,
      ownerModuleId: 'module_tuner',
    );

    const sameModuleIn = PortId(
      id: 'mic.loopback_in',
      displayName: 'Loopback',
      signalType: SignalType.audioPcm,
      direction: PortDirection.input,
      ownerModuleId: 'module_mic',
    );

    test('authorizes valid connection between different modules and matching signal type', () {
      expect(broker.canAuthorizeConnection(micOut, tunerIn), isTrue);
    });

    test('rejects connection if signal types do not match', () {
      expect(broker.canAuthorizeConnection(tunerNoteOut, tunerIn), isFalse);
    });

    test('rejects self-connection within the same module', () {
      expect(broker.canAuthorizeConnection(micOut, sameModuleIn), isFalse);
    });

    test('rejects connection if direction rules are violated', () {
      // Input to input
      expect(broker.canAuthorizeConnection(tunerIn, sameModuleIn), isFalse);
      // Output to output
      expect(broker.canAuthorizeConnection(micOut, tunerNoteOut), isFalse);
    });
  });

  group('PortPermissionBroker - Acoustic Safety & Permissions', () {
    test('authorizes live monitoring only if headphones or external interface are connected', () {
      expect(broker.canAuthorizeLiveMonitoring(isHeadphonesOrInterfaceConnected: false), isFalse);
      expect(broker.canAuthorizeLiveMonitoring(isHeadphonesOrInterfaceConnected: true), isTrue);
    });

    test('blocks audio emission during noise calibration mode', () {
      expect(broker.canAuthorizeAudioEmission(isCalibrationActive: true), isFalse);
      expect(broker.canAuthorizeAudioEmission(isCalibrationActive: false), isTrue);
    });

    test('generates safety warning reason when monitoring is denied', () {
      final warning = broker.getSafetyWarningReason(
        isHeadphonesConnected: false,
        isLiveMonitoringRequested: true,
      );
      expect(warning, contains('seguridad acustica'));
      expect(warning, contains('auriculares'));

      final noWarning = broker.getSafetyWarningReason(
        isHeadphonesConnected: true,
        isLiveMonitoringRequested: true,
      );
      expect(noWarning, isEmpty);
    });

    test('sanitizeConnections strips unsafe connections', () {
      const micOut = PortId(
        id: 'mic.pcm',
        displayName: 'Mic',
        signalType: SignalType.audioPcm,
        direction: PortDirection.output,
        ownerModuleId: 'mic_mod',
      );

      const speakerIn = PortId(
        id: 'speaker.in',
        displayName: 'Speaker',
        signalType: SignalType.audioPcm,
        direction: PortDirection.input,
        ownerModuleId: 'speaker_mod',
      );

      final unsafeConnection = ModuleConnection.pointToPoint(
        source: micOut,
        destination: speakerIn,
      );

      // Without headphones, mic-to-speaker is stripped
      final sanitizedWithoutHeadphones = broker.sanitizeConnections(
        [unsafeConnection],
        isHeadphonesConnected: false,
        isCalibrationActive: false,
      );
      expect(sanitizedWithoutHeadphones, isEmpty);

      // With headphones, mic-to-speaker is allowed
      final sanitizedWithHeadphones = broker.sanitizeConnections(
        [unsafeConnection],
        isHeadphonesConnected: true,
        isCalibrationActive: false,
      );
      expect(sanitizedWithHeadphones.length, 1);

      // During calibration, all PCM connections are stripped
      final sanitizedDuringCalibration = broker.sanitizeConnections(
        [unsafeConnection],
        isHeadphonesConnected: true,
        isCalibrationActive: true,
      );
      expect(sanitizedDuringCalibration, isEmpty);
    });
  });

  group('HardwareAudioEndpoint Domain Model', () {
    test('initializes and verifies properties correctly', () {
      const micEndpoint = HardwareAudioEndpoint(
        id: 'endpoint_mic_1',
        name: 'Microfono Frontal',
        type: AudioEndpointType.builtInMic,
        sampleRate: 48000,
        channelCount: 1,
        supportsRawCapture: true,
      );

      expect(micEndpoint.isInput, isTrue);
      expect(micEndpoint.isOutput, isFalse);
      expect(micEndpoint.isFeedbackSafe, isFalse);

      const headphonesEndpoint = HardwareAudioEndpoint(
        id: 'endpoint_hp_1',
        name: 'Auriculares Jack',
        type: AudioEndpointType.wiredHeadphones,
        sampleRate: 48000,
        channelCount: 2,
      );

      expect(headphonesEndpoint.isOutput, isTrue);
      expect(headphonesEndpoint.isInput, isFalse);
      expect(headphonesEndpoint.isFeedbackSafe, isTrue);
    });
  });
}
