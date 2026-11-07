import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/modular_rack/domain/signal_type.dart';
import 'package:tunner/features/modular_rack/domain/port_id.dart';
import 'package:tunner/features/modular_rack/domain/module_connection.dart';
import 'package:tunner/features/modular_rack/domain/signal_bus.dart';
import 'package:tunner/features/modular_rack/domain/rack_module_entity.dart';

void main() {
  group('SignalBus & Modular Rack Routing Domain Tests', () {
    late SignalBus bus;

    setUp(() {
      bus = SignalBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('ports can connect only if direction is opposite and signal type matches', () {
      final outAudio = PortId(
        id: 'out_audio',
        displayName: 'Mic Out',
        signalType: SignalType.audioPcm,
        direction: PortDirection.output,
        ownerModuleId: 'mic_mod',
      );

      final inAudio = PortId(
        id: 'in_audio',
        displayName: 'Recorder In',
        signalType: SignalType.audioPcm,
        direction: PortDirection.input,
        ownerModuleId: 'rec_mod',
      );

      final inPitch = PortId(
        id: 'in_pitch',
        displayName: 'Score Pitch In',
        signalType: SignalType.pitchEvents,
        direction: PortDirection.input,
        ownerModuleId: 'score_mod',
      );

      // Compatible: audio out -> audio in
      expect(outAudio.canConnectTo(inAudio), isTrue);

      // Incompatible: audio out -> pitch in (distinto SignalType)
      expect(outAudio.canConnectTo(inPitch), isFalse);

      // Incompatible: out -> out (misma dirección)
      expect(outAudio.canConnectTo(outAudio), isFalse);
    });

    test('point to point connection routes data exclusively to destination', () async {
      final micOut = PortId(
        id: 'audio_out',
        displayName: 'Mic Out',
        signalType: SignalType.audioPcm,
        direction: PortDirection.output,
        ownerModuleId: 'mic_1',
      );

      final recIn = PortId(
        id: 'audio_in',
        displayName: 'Rec In',
        signalType: SignalType.audioPcm,
        direction: PortDirection.input,
        ownerModuleId: 'rec_1',
      );

      final connection = ModuleConnection.pointToPoint(source: micOut, destination: recIn);
      bus.addConnection(connection);

      expect(bus.activeConnections.length, 1);

      // Suscribirse a la entrada del grabador
      final receivedData = <List<double>>[];
      final sub = bus.subscribe<List<double>>(recIn).listen((event) {
        receivedData.add(event);
      });

      // Emitir buffer de audio desde el micrófono
      final buffer = [0.1, 0.2, 0.3, -0.4];
      bus.emit(micOut, buffer);

      // Esperar microtask de entrega reactiva
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(receivedData.length, 1);
      expect(receivedData.first, equals(buffer));

      await sub.cancel();
    });

    test('broadcast connection distributes data to all subscribed inputs', () async {
      final pitchOut = PortId(
        id: 'pitch_stream',
        displayName: 'Pitch Stream',
        signalType: SignalType.pitchEvents,
        direction: PortDirection.output,
        ownerModuleId: 'tuner_mod',
      );

      final scoreIn = PortId(
        id: 'score_pitch_in',
        displayName: 'Score Pitch',
        signalType: SignalType.pitchEvents,
        direction: PortDirection.input,
        ownerModuleId: 'score_mod',
      );

      final evalIn = PortId(
        id: 'eval_pitch_in',
        displayName: 'Evaluator Pitch',
        signalType: SignalType.pitchEvents,
        direction: PortDirection.input,
        ownerModuleId: 'eval_mod',
      );

      // Conexión broadcast
      final bcastConn = ModuleConnection.broadcast(source: pitchOut);
      bus.addConnection(bcastConn);

      final scoreEvents = <String>[];
      final evalEvents = <String>[];

      final sub1 = bus.subscribe<String>(scoreIn).listen((e) => scoreEvents.add(e));
      final sub2 = bus.subscribe<String>(evalIn).listen((e) => evalEvents.add(e));

      bus.emit(pitchOut, 'Note: A4, 440Hz');

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(scoreEvents, contains('Note: A4, 440Hz'));
      expect(evalEvents, contains('Note: A4, 440Hz'));

      await sub1.cancel();
      await sub2.cancel();
    });

    test('hot-swapping: removing a connection stops data flow gracefully', () async {
      final clockOut = PortId(
        id: 'metro_clock',
        displayName: 'Metronome Clock',
        signalType: SignalType.temporalClock,
        direction: PortDirection.output,
        ownerModuleId: 'metro_1',
      );

      final scoreClockIn = PortId(
        id: 'clock_in',
        displayName: 'Score Clock',
        signalType: SignalType.temporalClock,
        direction: PortDirection.input,
        ownerModuleId: 'score_1',
      );

      final conn = ModuleConnection.pointToPoint(source: clockOut, destination: scoreClockIn);
      bus.addConnection(conn);

      final ticks = <int>[];
      final sub = bus.subscribe<int>(scoreClockIn).listen((t) => ticks.add(t));

      bus.emit(clockOut, 1);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(ticks, [1]);

      // Desconectar en caliente
      bus.removeConnection(conn.connectionId);
      expect(bus.activeConnections.isEmpty, isTrue);

      bus.emit(clockOut, 2);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // El tick 2 no debe haber llegado al receptor
      expect(ticks, [1]);

      await sub.cancel();
    });

    test('standard rack module factory builds modules with predefined valid ports', () {
      final tunerMod = RackModuleEntity.standard(RackModuleType.strobeTuner, 0);
      expect(tunerMod.outputPorts.any((p) => p.signalType == SignalType.pitchEvents), isTrue);

      final scoreMod = RackModuleEntity.standard(RackModuleType.scoreNotation, 1);
      expect(scoreMod.inputPorts.any((p) => p.signalType == SignalType.pitchEvents), isTrue);

      final recorderMod = RackModuleEntity.standard(RackModuleType.practiceRecorder, 2);
      expect(recorderMod.inputPorts.any((p) => p.signalType == SignalType.audioPcm), isTrue);

      final autoTuneMod = RackModuleEntity.standard(RackModuleType.vocalAutoTune, 3);
      expect(autoTuneMod.inputPorts.any((p) => p.signalType == SignalType.audioPcm), isTrue);
      expect(autoTuneMod.outputPorts.any((p) => p.signalType == SignalType.audioPcm), isTrue);
    });
  });
}
