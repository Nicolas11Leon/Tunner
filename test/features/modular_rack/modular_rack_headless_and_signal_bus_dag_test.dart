import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/modular_rack/domain/atomic_signal_event.dart';
import 'package:tunner/features/modular_rack/domain/modular_rack_headless_controller.dart';
import 'package:tunner/features/modular_rack/domain/module_connection.dart';
import 'package:tunner/features/modular_rack/domain/port_id.dart';
import 'package:tunner/features/modular_rack/domain/rack_module_entity.dart';
import 'package:tunner/features/modular_rack/domain/signal_bus.dart';
import 'package:tunner/features/modular_rack/domain/signal_type.dart';

PortId _audioOut(String moduleId) => PortId(
      id: 'audio_out',
      displayName: 'Out',
      signalType: SignalType.audioPcm,
      direction: PortDirection.output,
      ownerModuleId: moduleId,
    );

PortId _audioIn(String moduleId) => PortId(
      id: 'audio_in',
      displayName: 'In',
      signalType: SignalType.audioPcm,
      direction: PortDirection.input,
      ownerModuleId: moduleId,
    );

void main() {
  group('SignalBus DAG cycle detection, updateConnection and JSON serialization', () {
    test('rejects multi-hop cycles (A -> B -> C -> A) while allowing DAG diamonds', () {
      final bus = SignalBus();

      // A -> B -> C
      bus.addConnection(ModuleConnection.pointToPoint(
        source: _audioOut('mod_a'),
        destination: _audioIn('mod_b'),
      ));
      bus.addConnection(ModuleConnection.pointToPoint(
        source: _audioOut('mod_b'),
        destination: _audioIn('mod_c'),
      ));

      // Closing the loop C -> A must throw ArgumentError
      expect(
        () => bus.addConnection(ModuleConnection.pointToPoint(
          source: _audioOut('mod_c'),
          destination: _audioIn('mod_a'),
        )),
        throwsArgumentError,
      );

      // Direct 2-hop feedback B -> A must also throw ArgumentError
      expect(
        () => bus.addConnection(ModuleConnection.pointToPoint(
          source: _audioOut('mod_b'),
          destination: _audioIn('mod_a'),
        )),
        throwsArgumentError,
      );

      // Acyclic diamond A -> D and B -> D must succeed
      bus.addConnection(ModuleConnection.pointToPoint(
        source: _audioOut('mod_a'),
        destination: _audioIn('mod_d'),
      ));
      bus.addConnection(ModuleConnection.pointToPoint(
        source: _audioOut('mod_b'),
        destination: _audioIn('mod_d'),
      ));

      expect(bus.activeConnections.length, equals(4));
      bus.dispose();
    });

    test('updateConnection mutates gain and mute state and affects emitted signals', () async {
      final bus = SignalBus();
      final outA = _audioOut('mod_a');
      final inB = _audioIn('mod_b');

      final conn = ModuleConnection.pointToPoint(source: outA, destination: inB);
      bus.addConnection(conn);

      final received = <AudioPcmEvent>[];
      final sub = bus.subscribe<AudioPcmEvent>(inB).listen(received.add);

      // Mutate gain to 0.5
      final updated = bus.updateConnection(conn.connectionId, gain: 0.5);
      expect(updated, isNotNull);
      expect(updated!.gain, closeTo(0.5, 1e-6));

      bus.emitAtomicEvent(AudioPcmEvent(
        eventId: 'e1',
        sourcePort: outA,
        timestampMicros: 1000,
        samples: const [0.8, -0.4],
        sampleRate: 44100,
        rmsLevel: 0.6,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(received.length, equals(1));
      expect(received.first.samples[0], closeTo(0.4, 1e-6));
      expect(received.first.samples[1], closeTo(-0.2, 1e-6));

      // Mute the connection and verify no further events are delivered
      bus.updateConnection(conn.connectionId, isMuted: true);
      bus.emitAtomicEvent(AudioPcmEvent(
        eventId: 'e2',
        sourcePort: outA,
        timestampMicros: 2000,
        samples: const [0.8],
        sampleRate: 44100,
        rmsLevel: 0.8,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(received.length, equals(1));

      await sub.cancel();
      bus.dispose();
    });

    test('toJson / fromJson round-trips SignalBus connection topology', () {
      final bus = SignalBus();
      final conn = ModuleConnection.pointToPoint(
        source: _audioOut('mod_dj'),
        destination: _audioIn('mod_mix'),
        gain: 1.4,
        isMuted: true,
      );
      bus.addConnection(conn);

      final serialized = bus.toJson();
      final restored = SignalBus.fromJson(serialized);

      expect(restored.activeConnections.length, equals(1));
      final restoredConn = restored.activeConnections.first;
      expect(restoredConn.connectionId, equals(conn.connectionId));
      expect(restoredConn.gain, closeTo(1.4, 1e-6));
      expect(restoredConn.isMuted, isTrue);

      bus.dispose();
      restored.dispose();
    });
  });

  group('RackModuleType & ModularRackHeadlessController', () {
    test('supports djConsole and stemMixer modules with standard ports and dj_studio preset', () {
      final controller = ModularRackHeadlessController();
      controller.loadPreset('dj_studio');

      expect(controller.activeModules.length, equals(3));
      expect(controller.activeModules[0].moduleType, equals(RackModuleType.djConsole));
      expect(controller.activeModules[1].moduleType, equals(RackModuleType.stemMixer));
      expect(controller.activeModules[2].moduleType, equals(RackModuleType.spectrogram));
      expect(controller.activeConnections.length, equals(2));

      // Round-trip topology serialization
      final jsonStr = controller.toJsonString();
      final restored = ModularRackHeadlessController();
      restored.loadTopologyFromJsonString(jsonStr);

      expect(restored.activeModules.length, equals(3));
      expect(restored.activeModules[0].moduleType, equals(RackModuleType.djConsole));
      expect(restored.activeConnections.length, equals(2));

      controller.dispose();
      restored.dispose();
    });

    test('connectByPortIds, updateConnection, and power toggle work headless', () {
      final controller = ModularRackHeadlessController();
      final dj = controller.addModule(RackModuleType.djConsole, customId: 'dj_1');
      final mixer = controller.addModule(RackModuleType.stemMixer, customId: 'mix_1');

      final conn = controller.connectByPortIds(
        sourceModuleId: dj.moduleId,
        sourcePortId: 'master_audio_out',
        destinationModuleId: mixer.moduleId,
        destinationPortId: 'stem_audio_in',
        gain: 0.75,
      );
      expect(conn.gain, closeTo(0.75, 1e-6));

      final mutated = controller.updateConnection(conn.connectionId, gain: 1.2, isMuted: true);
      expect(mutated?.gain, closeTo(1.2, 1e-6));
      expect(mutated?.isMuted, isTrue);

      controller.setModulePower(dj.moduleId, false);
      expect(controller.findModule(dj.moduleId)?.isPoweredOn, isFalse);
      expect(controller.nodes[dj.moduleId]?.isProcessingActive, isFalse);

      controller.dispose();
    });
  });
}
