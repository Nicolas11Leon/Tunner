import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/modular_rack/domain/signal_type.dart';
import 'package:tunner/features/modular_rack/domain/port_id.dart';
import 'package:tunner/features/modular_rack/domain/module_connection.dart';
import 'package:tunner/features/modular_rack/domain/signal_bus.dart';
import 'package:tunner/features/modular_rack/domain/rack_module_entity.dart';
import 'package:tunner/features/modular_rack/domain/atomic_signal_event.dart';
import 'package:tunner/features/modular_rack/domain/interoperable_module_node.dart';
import 'package:tunner/features/modular_rack/presentation/modular_rack_viewmodel.dart';

class MockInstrumentNode implements InteroperableModuleNode {
  @override
  final String nodeId;
  @override
  final RackModuleType moduleType;
  @override
  bool isProcessingActive;

  @override
  final List<PortId> declaredInputPorts;
  @override
  final List<PortId> declaredOutputPorts;
  @override
  final Set<SignalType> acceptedSignalTypes;

  final List<AtomicSignalEvent> receivedEvents = [];

  MockInstrumentNode({
    required this.nodeId,
    required this.moduleType,
    this.isProcessingActive = true,
    required this.declaredInputPorts,
    required this.declaredOutputPorts,
    required this.acceptedSignalTypes,
  });

  @override
  void onReceiveAtomicSignal(AtomicSignalEvent event) {
    receivedEvents.add(event);
  }
}

void main() {
  group('Atomic Tool Synergy & SignalBus Interoperability Tests', () {
    late SignalBus bus;

    setUp(() {
      bus = SignalBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('SignalType extensions includes tuningCalibration and spectralData', () {
      expect(SignalType.tuningCalibration.code, equals('tuning_calibration'));
      expect(SignalType.spectralData.code, equals('spectral_data'));
    });

    test('Node registration and atomic signal delivery in < 1ms', () async {
      const inputPort = PortId(
        id: 'clock_in',
        displayName: 'Entrada de Reloj',
        ownerModuleId: 'node_score',
        signalType: SignalType.temporalClock,
        direction: PortDirection.input,
      );

      const outputPort = PortId(
        id: 'clock_out',
        displayName: 'Salida de Reloj',
        ownerModuleId: 'node_metro',
        signalType: SignalType.temporalClock,
        direction: PortDirection.output,
      );

      final mockScore = MockInstrumentNode(
        nodeId: 'node_score',
        moduleType: RackModuleType.scoreNotation,
        declaredInputPorts: [inputPort],
        declaredOutputPorts: [],
        acceptedSignalTypes: {SignalType.temporalClock},
      );

      bus.registerNode(mockScore);
      expect(bus.registeredNodes.containsKey('node_score'), isTrue);

      // Conectar metrónomo -> partitura
      bus.addConnection(ModuleConnection.pointToPoint(source: outputPort, destination: inputPort));

      // Emitir tick de metrónomo
      final tickEvent = ClockTickEvent(
        eventId: 'tick_1',
        sourcePort: outputPort,
        timestampMicros: 1000,
        tickIndex: 0,
        beatsPerBar: 4,
        bpm: 120.0,
        isDownbeat: true,
        tickDurationMs: 500.0,
      );

      bus.emitAtomicEvent(tickEvent);

      // Esperar breve microtask para procesamiento del stream
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(mockScore.receivedEvents.length, equals(1));
      final received = mockScore.receivedEvents.first as ClockTickEvent;
      expect(received.bpm, equals(120.0));
      expect(received.isDownbeat, isTrue);
      expect(received.tickIndex, equals(0));
    });

    test('Rejects mismatched signal connection with ArgumentError', () {
      const audioPort = PortId(
        id: 'audio_out',
        displayName: 'Audio PCM',
        ownerModuleId: 'mod_mic',
        signalType: SignalType.audioPcm,
        direction: PortDirection.output,
      );

      const clockPort = PortId(
        id: 'clock_in',
        displayName: 'Reloj In',
        ownerModuleId: 'mod_score',
        signalType: SignalType.temporalClock,
        direction: PortDirection.input,
      );

      expect(
        () => bus.addConnection(ModuleConnection.pointToPoint(source: audioPort, destination: clockPort)),
        throwsArgumentError,
      );
    });

    test('Global broadcast delivers signal to all compatible active nodes', () async {
      final tunerNode = MockInstrumentNode(
        nodeId: 'tuner_1',
        moduleType: RackModuleType.strobeTuner,
        declaredInputPorts: [],
        declaredOutputPorts: [],
        acceptedSignalTypes: {SignalType.tuningCalibration},
      );

      final droneNode = MockInstrumentNode(
        nodeId: 'drone_1',
        moduleType: RackModuleType.harmonicDrone,
        declaredInputPorts: [],
        declaredOutputPorts: [],
        acceptedSignalTypes: {SignalType.tuningCalibration},
      );

      final metroNode = MockInstrumentNode(
        nodeId: 'metro_1',
        moduleType: RackModuleType.metronome,
        declaredInputPorts: [],
        declaredOutputPorts: [],
        acceptedSignalTypes: {SignalType.transportControl}, // No acepta calibración
      );

      bus.registerNode(tunerNode);
      bus.registerNode(droneNode);
      bus.registerNode(metroNode);

      final calibEvent = TuningCalibrationEvent(
        eventId: 'calib_1',
        sourcePort: const PortId(
          id: 'calib_out',
          displayName: 'Calibración Out',
          ownerModuleId: 'master',
          signalType: SignalType.tuningCalibration,
          direction: PortDirection.output,
        ),
        timestampMicros: 2000,
        referenceA4Hz: 432.0,
        temperamentName: 'pythagorean',
      );

      bus.broadcastGlobalSignal(calibEvent);

      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(tunerNode.receivedEvents.length, equals(1));
      expect(droneNode.receivedEvents.length, equals(1));
      expect(metroNode.receivedEvents.length, equals(0)); // Ignorado limpiamente

      final tunerEv = tunerNode.receivedEvents.first as TuningCalibrationEvent;
      expect(tunerEv.referenceA4Hz, equals(432.0));
    });

    test('Powered off node ignores incoming signals gracefully', () async {
      final node = MockInstrumentNode(
        nodeId: 'off_node',
        moduleType: RackModuleType.vocalAutoTune,
        isProcessingActive: false, // Apagado
        declaredInputPorts: [],
        declaredOutputPorts: [],
        acceptedSignalTypes: {SignalType.tuningCalibration},
      );

      bus.registerNode(node);

      bus.broadcastGlobalSignal(
        TuningCalibrationEvent(
          eventId: 'calib_2',
          sourcePort: const PortId(
            id: 'calib_out',
            displayName: 'Calibración Out',
            ownerModuleId: 'master',
            signalType: SignalType.tuningCalibration,
            direction: PortDirection.output,
          ),
          timestampMicros: 3000,
          referenceA4Hz: 440.0,
          temperamentName: 'equal',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(node.receivedEvents.isEmpty, isTrue);
    });
  });

  group('ModularRackViewModel Atomic Synergy Integration Tests', () {
    late ModularRackViewModel viewModel;

    setUp(() {
      viewModel = ModularRackViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('Initializes with default atomic nodes registered in SignalBus', () {
      expect(viewModel.signalBus.registeredNodes.length, equals(4));
      expect(viewModel.activeModules.length, equals(4));
    });

    test('Transport controls dispatch global TransportControlEvent to nodes', () {
      viewModel.toggleMasterSession();
      expect(viewModel.isSessionRunning, isTrue);

      viewModel.toggleMasterRecording();
      expect(viewModel.isRecording, isTrue);

      viewModel.stopMasterSession();
      expect(viewModel.isSessionRunning, isFalse);
      expect(viewModel.isRecording, isFalse);
    });

    test('Customization changes broadcast TuningCalibrationEvent to rack nodes', () {
      final newCustom = viewModel.customization.copyWith(
        referencePitchA4: 415.0,
      );

      viewModel.updateCustomization(newCustom);
      expect(viewModel.customization.referencePitchA4, equals(415.0));
    });

    test('Adding and removing modules dynamically syncs SignalBus nodes without leaks', () {
      viewModel.addModule(RackModuleType.vocalAutoTune);
      expect(viewModel.activeModules.length, equals(5));
      expect(viewModel.signalBus.registeredNodes.length, equals(5));

      final addedId = viewModel.activeModules.last.moduleId;
      viewModel.removeModule(addedId);

      expect(viewModel.activeModules.length, equals(4));
      expect(viewModel.signalBus.registeredNodes.length, equals(4));
    });
  });
}
