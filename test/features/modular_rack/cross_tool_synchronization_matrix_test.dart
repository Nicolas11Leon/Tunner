import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/modular_rack/domain/atomic_signal_event.dart';
import 'package:tunner/features/modular_rack/domain/interoperable_module_node.dart';
import 'package:tunner/features/modular_rack/domain/module_connection.dart';
import 'package:tunner/features/modular_rack/domain/port_id.dart';
import 'package:tunner/features/modular_rack/domain/rack_module_entity.dart';
import 'package:tunner/features/modular_rack/domain/signal_bus.dart';
import 'package:tunner/features/modular_rack/domain/signal_type.dart';

/// Nodo espía simulador para pruebas rigurosas de la matriz de sincronización.
class MockInteroperableToolNode implements InteroperableModuleNode {
  @override
  final String nodeId;
  @override
  final RackModuleType moduleType;
  @override
  final List<PortId> declaredInputPorts;
  @override
  final List<PortId> declaredOutputPorts;
  @override
  final Set<SignalType> acceptedSignalTypes;

  bool _isProcessingActive;
  final List<AtomicSignalEvent> receivedEvents = [];

  MockInteroperableToolNode({
    required this.nodeId,
    required this.moduleType,
    required this.declaredInputPorts,
    required this.declaredOutputPorts,
    required this.acceptedSignalTypes,
    bool isProcessingActive = true,
  }) : _isProcessingActive = isProcessingActive;

  @override
  bool get isProcessingActive => _isProcessingActive;

  set isProcessingActive(bool value) => _isProcessingActive = value;

  @override
  void onReceiveAtomicSignal(AtomicSignalEvent event) {
    receivedEvents.add(event);
  }

  void clearEvents() => receivedEvents.clear();
}

void main() {
  group('Matriz de Sincronización Inter-Herramientas (SignalBus Cross-Tool Tests)', () {
    late SignalBus bus;

    setUp(() {
      bus = SignalBus();
    });

    tearDown(() {
      bus.dispose();
    });

    // -------------------------------------------------------------
    // 1. Metrónomo -> Pentagrama SMuFL (Sincronía de Reloj Temporal)
    // -------------------------------------------------------------
    test('1. Metrónomo <-> Pentagrama: Sincroniza sub-ticks y avance de playhead', () async {
      final metroModule = RackModuleEntity.standard(RackModuleType.metronome, 0);
      final scoreModule = RackModuleEntity.standard(RackModuleType.scoreNotation, 1);

      final clockOutPort = metroModule.outputPorts.firstWhere((p) => p.signalType == SignalType.temporalClock);
      final clockInPort = scoreModule.inputPorts.firstWhere((p) => p.signalType == SignalType.temporalClock);

      final scoreNode = MockInteroperableToolNode(
        nodeId: scoreModule.moduleId,
        moduleType: scoreModule.moduleType,
        declaredInputPorts: scoreModule.inputPorts,
        declaredOutputPorts: scoreModule.outputPorts,
        acceptedSignalTypes: {SignalType.temporalClock, SignalType.pitchEvents},
      );
      bus.registerNode(scoreNode);

      // Conexión punto a punto entre Metrónomo y Pentagrama
      bus.addConnection(ModuleConnection.pointToPoint(source: clockOutPort, destination: clockInPort));

      // Emisión de ticks de compás (Downbeat en tick 0, pulsos regulares en ticks 1-3)
      final tickEvent1 = ClockTickEvent(
        eventId: 'tick_0',
        sourcePort: clockOutPort,
        timestampMicros: 0,
        tickIndex: 0,
        beatsPerBar: 4,
        bpm: 120.0,
        isDownbeat: true,
        tickDurationMs: 500.0,
      );

      final tickEvent2 = ClockTickEvent(
        eventId: 'tick_1',
        sourcePort: clockOutPort,
        timestampMicros: 500000,
        tickIndex: 1,
        beatsPerBar: 4,
        bpm: 120.0,
        isDownbeat: false,
        tickDurationMs: 500.0,
      );

      bus.emit(clockOutPort, tickEvent1);
      bus.emit(clockOutPort, tickEvent2);
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(scoreNode.receivedEvents.length, equals(2));
      final received1 = scoreNode.receivedEvents[0] as ClockTickEvent;
      final received2 = scoreNode.receivedEvents[1] as ClockTickEvent;

      expect(received1.isDownbeat, isTrue);
      expect(received1.tickIndex, equals(0));
      expect(received2.isDownbeat, isFalse);
      expect(received2.tickIndex, equals(1));
    });

    // -------------------------------------------------------------
    // 2. Metrónomo -> Grabador de Estudio (Cuantización al pulso)
    // -------------------------------------------------------------
    test('2. Metrónomo <-> Grabador: Cuantiza inicio de toma de práctica al compás exacto', () async {
      final metroModule = RackModuleEntity.standard(RackModuleType.metronome, 0);
      final recModule = RackModuleEntity.standard(RackModuleType.practiceRecorder, 1);

      final clockOutPort = metroModule.outputPorts.firstWhere((p) => p.signalType == SignalType.temporalClock);
      final clockInPort = PortId(
        id: 'clock_in',
        displayName: 'Clock In',
        signalType: SignalType.temporalClock,
        direction: PortDirection.input,
        ownerModuleId: recModule.moduleId,
      );

      final recNode = MockInteroperableToolNode(
        nodeId: recModule.moduleId,
        moduleType: recModule.moduleType,
        declaredInputPorts: [...recModule.inputPorts, clockInPort],
        declaredOutputPorts: recModule.outputPorts,
        acceptedSignalTypes: {SignalType.audioPcm, SignalType.temporalClock, SignalType.transportControl},
      );
      bus.registerNode(recNode);

      bus.addConnection(ModuleConnection.pointToPoint(source: clockOutPort, destination: clockInPort));

      final tick = ClockTickEvent(
        eventId: 'tick_downbeat',
        sourcePort: clockOutPort,
        timestampMicros: 1000,
        tickIndex: 0,
        beatsPerBar: 4,
        bpm: 96.0,
        isDownbeat: true,
        tickDurationMs: 625.0,
      );
      bus.emit(clockOutPort, tick);
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(recNode.receivedEvents.length, equals(1));
      expect((recNode.receivedEvents.first as ClockTickEvent).bpm, equals(96.0));
      expect((recNode.receivedEvents.first as ClockTickEvent).isDownbeat, isTrue);
    });

    // -------------------------------------------------------------
    // 3. Afinador Estroboscópico -> Pentagrama ("Tocar y Transcribir")
    // -------------------------------------------------------------
    test('3. Afinador <-> Pentagrama: Transcribe en tiempo real notas detectadas por el micrófono', () async {
      final tunerModule = RackModuleEntity.standard(RackModuleType.strobeTuner, 0);
      final scoreModule = RackModuleEntity.standard(RackModuleType.scoreNotation, 1);

      final pitchOutPort = tunerModule.outputPorts.firstWhere((p) => p.signalType == SignalType.pitchEvents);
      final pitchInPort = scoreModule.inputPorts.firstWhere((p) => p.signalType == SignalType.pitchEvents);

      final scoreNode = MockInteroperableToolNode(
        nodeId: scoreModule.moduleId,
        moduleType: scoreModule.moduleType,
        declaredInputPorts: scoreModule.inputPorts,
        declaredOutputPorts: scoreModule.outputPorts,
        acceptedSignalTypes: {SignalType.pitchEvents},
      );
      bus.registerNode(scoreNode);

      bus.addConnection(ModuleConnection.pointToPoint(source: pitchOutPort, destination: pitchInPort));

      // Emisión de nota A4 (440 Hz con desvío perfecto)
      final pitchEvent = PitchDetectionEvent(
        eventId: 'pitch_a4',
        sourcePort: pitchOutPort,
        timestampMicros: 5000,
        frequencyHz: 440.0,
        noteName: 'A4',
        centsOffset: 0.1,
        clarity: 0.98,
        amplitude: 0.85,
      );

      bus.emit(pitchOutPort, pitchEvent);
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(scoreNode.receivedEvents.length, equals(1));
      final received = scoreNode.receivedEvents.first as PitchDetectionEvent;
      expect(received.noteName, equals('A4'));
      expect(received.frequencyHz, equals(440.0));
      expect(received.clarity, greaterThan(0.95));
    });

    // -------------------------------------------------------------
    // 4. Afinador Estroboscópico -> Tutor de Lecciones (Evaluación)
    // -------------------------------------------------------------
    test('4. Afinador <-> Tutor de Lecciones: Transmite tono cantado para evaluar precisión melódica', () async {
      final tunerModule = RackModuleEntity.standard(RackModuleType.strobeTuner, 0);
      final lessonsModule = RackModuleEntity.standard(RackModuleType.guidedLessons, 1);

      final pitchOutPort = tunerModule.outputPorts.firstWhere((p) => p.signalType == SignalType.pitchEvents);
      final pitchInPort = lessonsModule.inputPorts.firstWhere((p) => p.signalType == SignalType.pitchEvents);

      final lessonsNode = MockInteroperableToolNode(
        nodeId: lessonsModule.moduleId,
        moduleType: lessonsModule.moduleType,
        declaredInputPorts: lessonsModule.inputPorts,
        declaredOutputPorts: lessonsModule.outputPorts,
        acceptedSignalTypes: {SignalType.pitchEvents},
      );
      bus.registerNode(lessonsNode);

      bus.addConnection(ModuleConnection.pointToPoint(source: pitchOutPort, destination: pitchInPort));

      final pitchEvent = PitchDetectionEvent(
        eventId: 'pitch_c5',
        sourcePort: pitchOutPort,
        timestampMicros: 12000,
        frequencyHz: 523.25,
        noteName: 'C5',
        centsOffset: -1.2,
        clarity: 0.96,
        amplitude: 0.78,
      );

      bus.emit(pitchOutPort, pitchEvent);
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(lessonsNode.receivedEvents.length, equals(1));
      final received = lessonsNode.receivedEvents.first as PitchDetectionEvent;
      expect(received.noteName, equals('C5'));
      expect(received.centsOffset, closeTo(-1.2, 0.01));
    });

    // -------------------------------------------------------------
    // 5. Afinador / Mic -> Entrenador a Ciegas (Ear Trainer)
    // -------------------------------------------------------------
    test('5. Afinador <-> Entrenador a Ciegas: Suministra frecuencia vocal para evaluación de intervalos', () async {
      final tunerModule = RackModuleEntity.standard(RackModuleType.strobeTuner, 0);
      final earModule = RackModuleEntity.standard(RackModuleType.earTrainer, 1);

      final pitchOutPort = tunerModule.outputPorts.firstWhere((p) => p.signalType == SignalType.pitchEvents);
      final pitchInPort = earModule.inputPorts.firstWhere((p) => p.signalType == SignalType.pitchEvents);

      final earNode = MockInteroperableToolNode(
        nodeId: earModule.moduleId,
        moduleType: earModule.moduleType,
        declaredInputPorts: earModule.inputPorts,
        declaredOutputPorts: earModule.outputPorts,
        acceptedSignalTypes: {SignalType.pitchEvents},
      );
      bus.registerNode(earNode);

      bus.addConnection(ModuleConnection.pointToPoint(source: pitchOutPort, destination: pitchInPort));

      // Emisión de quinta cantada (E5 = 659.25 Hz)
      final pitchEvent = PitchDetectionEvent(
        eventId: 'pitch_e5',
        sourcePort: pitchOutPort,
        timestampMicros: 25000,
        frequencyHz: 659.25,
        noteName: 'E5',
        centsOffset: 0.3,
        clarity: 0.99,
        amplitude: 0.88,
      );

      bus.emit(pitchOutPort, pitchEvent);
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(earNode.receivedEvents.length, equals(1));
      final received = earNode.receivedEvents.first as PitchDetectionEvent;
      expect(received.noteName, equals('E5'));
      expect(received.frequencyHz, closeTo(659.25, 0.01));
    });

    // -------------------------------------------------------------
    // 6. Mic / Audio PCM -> Visualizador Polifónico & Armónicos
    // -------------------------------------------------------------
    test('6. Audio PCM <-> Analizador Polifónico: Entrega buffer para descomposición de acordes', () async {
      final micOutPort = PortId(
        id: 'mic_out',
        displayName: 'Mic Ingestion',
        signalType: SignalType.audioPcm,
        direction: PortDirection.output,
        ownerModuleId: 'hardware_mic',
      );

      final polyModule = RackModuleEntity.standard(RackModuleType.chordAnalyzer, 0);
      final polyInPort = polyModule.inputPorts.firstWhere((p) => p.signalType == SignalType.audioPcm);

      final polyNode = MockInteroperableToolNode(
        nodeId: polyModule.moduleId,
        moduleType: polyModule.moduleType,
        declaredInputPorts: polyModule.inputPorts,
        declaredOutputPorts: polyModule.outputPorts,
        acceptedSignalTypes: {SignalType.audioPcm},
      );
      bus.registerNode(polyNode);

      bus.addConnection(ModuleConnection.pointToPoint(source: micOutPort, destination: polyInPort));

      final samples = List.generate(1024, (i) => 0.5 * (i % 2 == 0 ? 1.0 : -1.0));
      final pcmEvent = AudioPcmEvent(
        eventId: 'chord_frame_1',
        sourcePort: micOutPort,
        timestampMicros: 40000,
        samples: samples,
        sampleRate: 44100,
        rmsLevel: 0.5,
      );

      bus.emit(micOutPort, pcmEvent);
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(polyNode.receivedEvents.length, equals(1));
      final received = polyNode.receivedEvents.first as AudioPcmEvent;
      expect(received.sampleRate, equals(44100));
      expect(received.samples.length, equals(1024));
    });

    // -------------------------------------------------------------
    // 7. Mic / Audio PCM -> Autotune Vocal DSP
    // -------------------------------------------------------------
    test('7. Audio PCM <-> Autotune Vocal DSP: Recibe audio crudo y emite audio afinado', () async {
      final micOutPort = PortId(
        id: 'mic_vocal_out',
        displayName: 'Mic Vocal',
        signalType: SignalType.audioPcm,
        direction: PortDirection.output,
        ownerModuleId: 'vocal_mic',
      );

      final autoTuneModule = RackModuleEntity.standard(RackModuleType.vocalAutoTune, 0);
      final autoTuneInPort = autoTuneModule.inputPorts.firstWhere((p) => p.signalType == SignalType.audioPcm);

      final autoTuneNode = MockInteroperableToolNode(
        nodeId: autoTuneModule.moduleId,
        moduleType: autoTuneModule.moduleType,
        declaredInputPorts: autoTuneModule.inputPorts,
        declaredOutputPorts: autoTuneModule.outputPorts,
        acceptedSignalTypes: {SignalType.audioPcm},
      );
      bus.registerNode(autoTuneNode);

      bus.addConnection(ModuleConnection.pointToPoint(source: micOutPort, destination: autoTuneInPort));

      final pcmEvent = AudioPcmEvent(
        eventId: 'raw_vocal_1',
        sourcePort: micOutPort,
        timestampMicros: 60000,
        samples: [0.1, 0.2, 0.3],
        sampleRate: 48000,
        rmsLevel: 0.25,
      );

      bus.emit(micOutPort, pcmEvent);
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(autoTuneNode.receivedEvents.length, equals(1));
      expect((autoTuneNode.receivedEvents.first as AudioPcmEvent).sampleRate, equals(48000));
    });

    // -------------------------------------------------------------
    // 8. Dron Armónico / Diapasón -> Matriz de Afinación (Calibración A4)
    // -------------------------------------------------------------
    test('8. Calibración Maestra <-> Dron & Afinador: Sincroniza A4=442 Hz y temperamentos históricos', () async {
      final calibOutPort = PortId(
        id: 'master_calib_out',
        displayName: 'Calibración A4',
        signalType: SignalType.tuningCalibration,
        direction: PortDirection.output,
        ownerModuleId: 'master_clock',
      );

      final tunerModule = RackModuleEntity.standard(RackModuleType.strobeTuner, 0);
      final droneModule = RackModuleEntity.standard(RackModuleType.harmonicDrone, 1);

      final tunerInPort = PortId(
        id: 'calib_in',
        displayName: 'Tuner Calib In',
        signalType: SignalType.tuningCalibration,
        direction: PortDirection.input,
        ownerModuleId: tunerModule.moduleId,
      );

      final droneInPort = PortId(
        id: 'drone_calib_in',
        displayName: 'Drone Calib In',
        signalType: SignalType.tuningCalibration,
        direction: PortDirection.input,
        ownerModuleId: droneModule.moduleId,
      );

      final tunerNode = MockInteroperableToolNode(
        nodeId: tunerModule.moduleId,
        moduleType: tunerModule.moduleType,
        declaredInputPorts: [...tunerModule.inputPorts, tunerInPort],
        declaredOutputPorts: tunerModule.outputPorts,
        acceptedSignalTypes: {SignalType.tuningCalibration},
      );

      final droneNode = MockInteroperableToolNode(
        nodeId: droneModule.moduleId,
        moduleType: droneModule.moduleType,
        declaredInputPorts: [...droneModule.inputPorts, droneInPort],
        declaredOutputPorts: droneModule.outputPorts,
        acceptedSignalTypes: {SignalType.tuningCalibration},
      );

      bus.registerNode(tunerNode);
      bus.registerNode(droneNode);

      // Conexión broadcast de calibración a todas las herramientas
      bus.addConnection(ModuleConnection.broadcast(source: calibOutPort));

      final calibEvent = TuningCalibrationEvent(
        eventId: 'calib_442',
        sourcePort: calibOutPort,
        timestampMicros: 80000,
        referenceA4Hz: 442.0,
        temperamentName: 'werckmeister_iii',
      );

      bus.emit(calibOutPort, calibEvent);
      await Future<void>.delayed(const Duration(milliseconds: 15));

      // Tanto el Afinador como el Dron reciben la nueva calibración simultáneamente
      expect(tunerNode.receivedEvents.length, equals(1));
      expect(droneNode.receivedEvents.length, equals(1));

      final recTuner = tunerNode.receivedEvents.first as TuningCalibrationEvent;
      final recDrone = droneNode.receivedEvents.first as TuningCalibrationEvent;

      expect(recTuner.referenceA4Hz, equals(442.0));
      expect(recDrone.referenceA4Hz, equals(442.0));
      expect(recTuner.temperamentName, equals('werckmeister_iii'));
    });

    // -------------------------------------------------------------
    // 9. Broadcast Simultáneo 1-a-N (Un tono alimenta a 4 herramientas a la vez)
    // -------------------------------------------------------------
    test('9. Sincronización Broadcast Multitool: Una nota alimenta Afinador, Pentagrama, Tutor y Autotune', () async {
      final micPitchOut = PortId(
        id: 'mic_pitch_broadcast',
        displayName: 'Mic Pitch Broadcast',
        signalType: SignalType.pitchEvents,
        direction: PortDirection.output,
        ownerModuleId: 'hardware_mic',
      );

      // Crear 4 herramientas consumidoras
      final scoreNode = MockInteroperableToolNode(
        nodeId: 'score_mod',
        moduleType: RackModuleType.scoreNotation,
        declaredInputPorts: [PortId(id: 'p1', displayName: 'P1', signalType: SignalType.pitchEvents, direction: PortDirection.input, ownerModuleId: 'score_mod')],
        declaredOutputPorts: const [],
        acceptedSignalTypes: {SignalType.pitchEvents},
      );

      final lessonsNode = MockInteroperableToolNode(
        nodeId: 'lessons_mod',
        moduleType: RackModuleType.guidedLessons,
        declaredInputPorts: [PortId(id: 'p2', displayName: 'P2', signalType: SignalType.pitchEvents, direction: PortDirection.input, ownerModuleId: 'lessons_mod')],
        declaredOutputPorts: const [],
        acceptedSignalTypes: {SignalType.pitchEvents},
      );

      final earNode = MockInteroperableToolNode(
        nodeId: 'ear_mod',
        moduleType: RackModuleType.earTrainer,
        declaredInputPorts: [PortId(id: 'p3', displayName: 'P3', signalType: SignalType.pitchEvents, direction: PortDirection.input, ownerModuleId: 'ear_mod')],
        declaredOutputPorts: const [],
        acceptedSignalTypes: {SignalType.pitchEvents},
      );

      bus.registerNode(scoreNode);
      bus.registerNode(lessonsNode);
      bus.registerNode(earNode);

      // Registrar broadcast
      bus.addConnection(ModuleConnection.broadcast(source: micPitchOut));

      final pitchEvent = PitchDetectionEvent(
        eventId: 'shared_pitch_g4',
        sourcePort: micPitchOut,
        timestampMicros: 95000,
        frequencyHz: 392.0,
        noteName: 'G4',
        centsOffset: 0.0,
        clarity: 0.99,
        amplitude: 0.9,
      );

      bus.emit(micPitchOut, pitchEvent);
      await Future<void>.delayed(const Duration(milliseconds: 15));

      // Las 3 herramientas recibieron exactamente el mismo evento sincrónico
      expect(scoreNode.receivedEvents.length, equals(1));
      expect(lessonsNode.receivedEvents.length, equals(1));
      expect(earNode.receivedEvents.length, equals(1));

      expect((scoreNode.receivedEvents.first as PitchDetectionEvent).noteName, equals('G4'));
      expect((lessonsNode.receivedEvents.first as PitchDetectionEvent).noteName, equals('G4'));
      expect((earNode.receivedEvents.first as PitchDetectionEvent).noteName, equals('G4'));
    });

    // -------------------------------------------------------------
    // 10. Desactivación Selectiva (isProcessingActive = false) & Hot Swapping
    // -------------------------------------------------------------
    test('10. Aislamiento: Un módulo apagado descarta señales sin romper la sincronía de los demás', () async {
      final clockOutPort = PortId(
        id: 'metro_clock',
        displayName: 'Metro Clock',
        signalType: SignalType.temporalClock,
        direction: PortDirection.output,
        ownerModuleId: 'metro_source',
      );

      final activeScoreNode = MockInteroperableToolNode(
        nodeId: 'active_score',
        moduleType: RackModuleType.scoreNotation,
        declaredInputPorts: [PortId(id: 'clk1', displayName: 'Clk1', signalType: SignalType.temporalClock, direction: PortDirection.input, ownerModuleId: 'active_score')],
        declaredOutputPorts: const [],
        acceptedSignalTypes: {SignalType.temporalClock},
        isProcessingActive: true,
      );

      final poweredOffRecorderNode = MockInteroperableToolNode(
        nodeId: 'off_recorder',
        moduleType: RackModuleType.practiceRecorder,
        declaredInputPorts: [PortId(id: 'clk2', displayName: 'Clk2', signalType: SignalType.temporalClock, direction: PortDirection.input, ownerModuleId: 'off_recorder')],
        declaredOutputPorts: const [],
        acceptedSignalTypes: {SignalType.temporalClock},
        isProcessingActive: false, // Apagado
      );

      bus.registerNode(activeScoreNode);
      bus.registerNode(poweredOffRecorderNode);

      bus.addConnection(ModuleConnection.broadcast(source: clockOutPort));

      final tick = ClockTickEvent(
        eventId: 'tick_isolation',
        sourcePort: clockOutPort,
        timestampMicros: 100000,
        tickIndex: 2,
        beatsPerBar: 4,
        bpm: 110.0,
        isDownbeat: false,
        tickDurationMs: 545.45,
      );

      bus.emit(clockOutPort, tick);
      await Future<void>.delayed(const Duration(milliseconds: 15));

      // El módulo activo recibe el tick, el módulo apagado lo ignora en O(1)
      expect(activeScoreNode.receivedEvents.length, equals(1));
      expect(poweredOffRecorderNode.receivedEvents.length, equals(0));
    });
  });
}
