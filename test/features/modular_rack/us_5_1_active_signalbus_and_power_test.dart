import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/audio_device_entity.dart';
import 'package:tunner/core/audio/domain/audio_pcm_frame.dart';
import 'package:tunner/core/audio/domain/i_studio_audio_input_engine.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_engine.dart';
import 'package:tunner/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/modular_rack/domain/atomic_signal_event.dart';
import 'package:tunner/features/modular_rack/domain/module_connection.dart';
import 'package:tunner/features/modular_rack/domain/port_id.dart';
import 'package:tunner/features/modular_rack/domain/rack_module_entity.dart';
import 'package:tunner/features/modular_rack/domain/signal_bus.dart';
import 'package:tunner/features/modular_rack/domain/signal_type.dart';
import 'package:tunner/features/modular_rack/presentation/modular_rack_viewmodel.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner/presentation/tuner_viewmodel.dart';

class _FakeAudioInputEngine implements IStudioAudioInputEngine {
  final StreamController<AudioPcmFrame> _pcmController =
      StreamController<AudioPcmFrame>.broadcast();
  final StreamController<double> _rmsController =
      StreamController<double>.broadcast();
  final StreamController<double> _peakController =
      StreamController<double>.broadcast();

  bool _isCapturing = false;
  AudioDeviceEntity? _device = AudioDeviceEntity.systemDefault();
  int startCalls = 0;
  int stopCalls = 0;

  @override
  AudioDeviceEntity? get currentDevice => _device;

  @override
  bool get isCapturing => _isCapturing;

  @override
  Stream<AudioPcmFrame> get pcmFrameStream => _pcmController.stream;

  @override
  Stream<double> get rmsDbStream => _rmsController.stream;

  @override
  Stream<double> get peakDbStream => _peakController.stream;

  @override
  Future<List<AudioDeviceEntity>> listInputDevices() async => [
        AudioDeviceEntity.systemDefault(),
      ];

  @override
  Future<void> setInputDevice(String deviceId) async {
    _device = AudioDeviceEntity(id: deviceId, label: deviceId);
  }

  @override
  Future<void> startCapture({int sampleRate = 44100, int bufferSize = 1024}) async {
    startCalls++;
    _isCapturing = true;
  }

  @override
  Future<void> stopCapture() async {
    stopCalls++;
    _isCapturing = false;
  }

  void pushFrame(AudioPcmFrame frame) {
    _pcmController.add(frame);
  }

  @override
  void dispose() {
    unawaited(_pcmController.close());
    unawaited(_rmsController.close());
    unawaited(_peakController.close());
  }
}

class _SpyMetronomeService implements IMetronomeService {
  @override
  Function(int currentSubTick)? onSubTick;

  bool isRunning = false;
  int startCount = 0;
  int stopCount = 0;

  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {
    startCount++;
    isRunning = true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    isRunning = false;
  }
}

class _SpyPitchDetectorService extends IPitchDetectorService {
  bool isStarted = false;

  @override
  Future<void> startRecording() async {
    isStarted = true;
  }

  @override
  Future<void> stopRecording() async {
    isStarted = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-5.1 SignalBus Gain & PortPermissionBroker Validation', () {
    late SignalBus bus;

    setUp(() {
      bus = SignalBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('SignalBus.emit escala AudioPcmEvent, PitchDetectionEvent y List<double> por conn.gain', () async {
      const outPcm = PortId(
        id: 'pcm_out',
        displayName: 'PCM Out',
        signalType: SignalType.audioPcm,
        direction: PortDirection.output,
        ownerModuleId: 'src_mod',
      );
      const inHalfGain = PortId(
        id: 'pcm_in_half',
        displayName: 'PCM In Half',
        signalType: SignalType.audioPcm,
        direction: PortDirection.input,
        ownerModuleId: 'dest_half',
      );
      const inBoostGain = PortId(
        id: 'pcm_in_boost',
        displayName: 'PCM In Boost',
        signalType: SignalType.audioPcm,
        direction: PortDirection.input,
        ownerModuleId: 'dest_boost',
      );

      bus.addConnection(
        ModuleConnection.pointToPoint(
          source: outPcm,
          destination: inHalfGain,
          gain: 0.5,
        ),
      );
      bus.addConnection(
        ModuleConnection.pointToPoint(
          source: outPcm,
          destination: inBoostGain,
          gain: 2.0,
        ),
      );

      final receivedHalf = <AudioPcmEvent>[];
      final receivedBoost = <AudioPcmEvent>[];
      final sub1 = bus.subscribe<AudioPcmEvent>(inHalfGain).listen(receivedHalf.add);
      final sub2 = bus.subscribe<AudioPcmEvent>(inBoostGain).listen(receivedBoost.add);

      bus.emitAtomicEvent(
        AudioPcmEvent(
          eventId: 'pcm_1',
          sourcePort: outPcm,
          timestampMicros: 100,
          samples: const [0.4, -0.8],
          sampleRate: 44100,
          rmsLevel: 0.632,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(receivedHalf.length, equals(1));
      expect(receivedHalf.first.samples[0], closeTo(0.2, 1e-6));
      expect(receivedHalf.first.samples[1], closeTo(-0.4, 1e-6));
      expect(receivedHalf.first.rmsLevel, closeTo(math.sqrt((0.04 + 0.16) / 2.0), 1e-6));

      expect(receivedBoost.length, equals(1));
      expect(receivedBoost.first.samples[0], closeTo(0.8, 1e-6));
      // -0.8 * 2.0 = -1.6 -> clamp a -1.0
      expect(receivedBoost.first.samples[1], equals(-1.0));

      // Verificar PitchDetectionEvent.amplitude escalada
      const outPitch = PortId(
        id: 'pitch_out',
        displayName: 'Pitch Out',
        signalType: SignalType.pitchEvents,
        direction: PortDirection.output,
        ownerModuleId: 'tuner_src',
      );
      const inPitch = PortId(
        id: 'pitch_in',
        displayName: 'Pitch In',
        signalType: SignalType.pitchEvents,
        direction: PortDirection.input,
        ownerModuleId: 'score_dest',
      );
      bus.addConnection(
        ModuleConnection.pointToPoint(
          source: outPitch,
          destination: inPitch,
          gain: 0.25,
        ),
      );

      final receivedPitch = <PitchDetectionEvent>[];
      final subPitch = bus.subscribe<PitchDetectionEvent>(inPitch).listen(receivedPitch.add);
      bus.emitAtomicEvent(
        PitchDetectionEvent(
          eventId: 'pitch_1',
          sourcePort: outPitch,
          timestampMicros: 200,
          frequencyHz: 440.0,
          noteName: 'La4',
          centsOffset: 0.0,
          clarity: 0.98,
          amplitude: 0.8,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(receivedPitch.length, equals(1));
      expect(receivedPitch.first.amplitude, closeTo(0.2, 1e-6));

      await sub1.cancel();
      await sub2.cancel();
      await subPitch.cancel();
    });

    test('SignalBus valida conexiones con PortPermissionBroker (bloquea auto-conexion y loopback en broadcast)', () async {
      const modOut = PortId(
        id: 'out_1',
        displayName: 'Out 1',
        signalType: SignalType.audioPcm,
        direction: PortDirection.output,
        ownerModuleId: 'same_module',
      );
      const sameModIn = PortId(
        id: 'in_self',
        displayName: 'In Self',
        signalType: SignalType.audioPcm,
        direction: PortDirection.input,
        ownerModuleId: 'same_module',
      );
      const otherModIn = PortId(
        id: 'in_other',
        displayName: 'In Other',
        signalType: SignalType.audioPcm,
        direction: PortDirection.input,
        ownerModuleId: 'other_module',
      );

      // addConnection rechaza auto-conexion en el mismo modulo
      expect(
        () => bus.addConnection(
          ModuleConnection.pointToPoint(source: modOut, destination: sameModIn),
        ),
        throwsArgumentError,
      );

      // Broadcast con gain 0.5 solo entrega a other_module y nunca hace loopback a same_module
      bus.registerPort(sameModIn);
      bus.registerPort(otherModIn);
      bus.addConnection(ModuleConnection.broadcast(source: modOut, gain: 0.5));

      final selfEvents = <List<double>>[];
      final otherEvents = <List<double>>[];
      final subSelf = bus.subscribe<List<double>>(sameModIn).listen(selfEvents.add);
      final subOther = bus.subscribe<List<double>>(otherModIn).listen(otherEvents.add);

      bus.emit(modOut, [0.8, -0.6]);
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(selfEvents, isEmpty);
      expect(otherEvents.length, equals(1));
      expect(otherEvents.first[0], closeTo(0.4, 1e-6));
      expect(otherEvents.first[1], closeTo(-0.3, 1e-6));

      await subSelf.cancel();
      await subOther.cancel();
    });
  });

  group('US-5.1 StandardRackNode Activo, Enlace de Motores y Apagado Real', () {
    late MemoryStudioAudioEngine audioEngine;
    late _FakeAudioInputEngine audioInputEngine;
    late _SpyMetronomeService spyMetro;
    late _SpyPitchDetectorService spyPitch;
    late MemoryAudioSynthesizerService memorySynth;
    late TunerViewModel tunerVm;
    late ModularRackViewModel rackVm;

    setUp(() {
      audioEngine = MemoryStudioAudioEngine();
      audioInputEngine = _FakeAudioInputEngine();
      spyMetro = _SpyMetronomeService();
      spyPitch = _SpyPitchDetectorService();
      memorySynth = MemoryAudioSynthesizerService();
      tunerVm = TunerViewModel(
        pitchService: spyPitch,
        metronomeService: spyMetro,
        audioSynthesizerService: memorySynth,
      );
      rackVm = ModularRackViewModel(
        audioEngine: audioEngine,
        audioInputEngine: audioInputEngine,
        tunerViewModel: tunerVm,
      );
    });

    tearDown(() async {
      rackVm.dispose();
      tunerVm.dispose();
      audioInputEngine.dispose();
      await audioEngine.dispose();
    });

    test('StandardRackNode.onReceiveAtomicSignal procesa TransportControlEvent, TuningCalibrationEvent, ClockTickEvent, PitchDetectionEvent y AudioPcmEvent', () async {
      // 1. TransportControlEvent: play inicia metronomo; record activa captura
      expect(tunerVm.isMetronomePlaying, isFalse);
      rackVm.toggleMasterSession(); // emite play
      expect(tunerVm.isMetronomePlaying, isTrue);
      expect(spyMetro.isRunning, isTrue);

      rackVm.toggleMasterRecording(); // emite record
      expect(audioInputEngine.isCapturing, isTrue);

      final metroNode =
          rackVm.signalBus.registeredNodes['mod_metronome_1']! as StandardRackNode;
      expect(metroNode.lastTransportCommand, equals(TransportCommand.record));

      rackVm.stopMasterSession(); // emite stop
      await Future<void>.delayed(Duration.zero);
      expect(tunerVm.isMetronomePlaying, isFalse);
      expect(audioInputEngine.isCapturing, isFalse);

      // 2. TuningCalibrationEvent: calibra A4 y temperamento en TunerViewModel y AutoTune
      rackVm.addModule(RackModuleType.vocalAutoTune);
      final custom = rackVm.customization.copyWith(referencePitchA4: 432.0);
      rackVm.updateCustomization(custom);

      expect(tunerVm.referencePitch, closeTo(432.0, 0.01));
      expect(tunerVm.autoTuneConfig.a4Reference, closeTo(432.0, 0.01));
      final tunerNode =
          rackVm.signalBus.registeredNodes['mod_strobe_tuner_0']! as StandardRackNode;
      expect(tunerNode.lastCalibratedA4Hz, closeTo(432.0, 0.01));

      // 3. ClockTickEvent: sincroniza BPM y sub-tick en ScoreNotation y TunerViewModel
      final metroMod = rackVm.activeModules.firstWhere(
        (m) => m.moduleType == RackModuleType.metronome,
      );
      final clockOut = metroMod.outputPorts.firstWhere(
        (p) => p.signalType == SignalType.temporalClock,
      );
      rackVm.signalBus.emitAtomicEvent(
        ClockTickEvent(
          eventId: 'clk_test',
          sourcePort: clockOut,
          timestampMicros: 5000,
          tickIndex: 6,
          beatsPerBar: 4,
          bpm: 142.0,
          tickDurationMs: 105.6,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final scoreNode =
          rackVm.signalBus.registeredNodes['mod_score_notation_2']! as StandardRackNode;
      expect(scoreNode.lastClockBpm, equals(142.0));
      expect(scoreNode.lastClockTickIndex, equals(6));
      expect(tunerVm.bpm, equals(142));
      expect(tunerVm.currentSubTick, equals(6));
      expect(tunerVm.scorePlaybackCoordinator.bpm, equals(142.0));

      // 4. PitchDetectionEvent: propaga nota detectada a ScoreNotation y TunerViewModel
      final tunerMod = rackVm.activeModules.firstWhere(
        (m) => m.moduleType == RackModuleType.strobeTuner,
      );
      final pitchOut = tunerMod.outputPorts.firstWhere(
        (p) => p.signalType == SignalType.pitchEvents,
      );
      rackVm.signalBus.emitAtomicEvent(
        PitchDetectionEvent(
          eventId: 'pitch_test',
          sourcePort: pitchOut,
          timestampMicros: 6000,
          frequencyHz: 440.0,
          noteName: 'La4',
          centsOffset: 1.5,
          clarity: 0.96,
          amplitude: 0.7,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(scoreNode.lastPitchHz, equals(440.0));
      expect(scoreNode.lastPitchNoteName, equals('La4'));
      expect(tunerVm.frequency, equals(440.0));
      expect(tunerVm.noteName, equals('La4'));

      // 5. AudioPcmEvent desde audioInputEngine -> SignalBus -> nodos y audioEngine
      final frameSamples = Float32List.fromList([0.5, -0.5, 0.5, -0.5]);
      audioInputEngine.pushFrame(
        AudioPcmFrame(
          samples: frameSamples,
          rawBytes: Uint8List(8),
          sampleRate: 44100,
          channels: 1,
          timestampMicros: 7000,
          rmsDb: -6.0,
          peakDb: -6.0,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(rackVm.audioCaptureFrameCount, greaterThanOrEqualTo(1));
      expect(tunerNode.lastPcmRms, closeTo(0.5, 0.01));
      expect(tunerVm.latestAudioSamples, isNotNull);
      expect(tunerVm.latestAudioSamples!.length, equals(4));

      // El canal del grabador en audioEngine sincronizo su volumen con el nivel PCM recibido
      final recChannel = audioEngine.getChannel('mod_practice_recorder_3');
      expect(recChannel.volume, closeTo(0.5, 0.01));
    });

    test('toggleModulePower y removeModule detienen subsistemas activos correspondientes', () async {
      // Preparar subsistemas activos: Metronomo, Dron, AutoTune, ChordAnalyzer y Captura
      rackVm.addModule(RackModuleType.harmonicDrone);
      rackVm.addModule(RackModuleType.vocalAutoTune);
      rackVm.addModule(RackModuleType.chordAnalyzer);

      await tunerVm.startSongWithCountIn();
      await tunerVm.toggleDrone();
      tunerVm.toggleAutoTune();
      tunerVm.setChordRecognitionActive(true);
      await tunerVm.toggleRecording();
      await audioInputEngine.startCapture();

      expect(tunerVm.isMetronomePlaying, isTrue);
      expect(tunerVm.isDronePlaying, isTrue);
      expect(tunerVm.isAutoTuneActive, isTrue);
      expect(tunerVm.isChordRecognitionActive, isTrue);
      expect(tunerVm.isRecording, isTrue);
      expect(audioInputEngine.isCapturing, isTrue);

      // 1. Apagar modulo Metronomo detiene metrónomo activo
      final metroId = rackVm.activeModules
          .firstWhere((m) => m.moduleType == RackModuleType.metronome)
          .moduleId;
      rackVm.toggleModulePower(metroId);
      expect(tunerVm.isMetronomePlaying, isFalse);

      // Un nodo apagado ignora nuevas senales en el SignalBus
      final metroNode = rackVm.signalBus.registeredNodes[metroId]! as StandardRackNode;
      final eventsBefore = metroNode.processedEventsCount;
      metroNode.onReceiveAtomicSignal(
        TransportControlEvent(
          eventId: 'ignored_play',
          sourcePort: ModularRackViewModel.masterClockOutputPort,
          timestampMicros: 9000,
          command: TransportCommand.play,
        ),
      );
      expect(metroNode.processedEventsCount, equals(eventsBefore));
      expect(tunerVm.isMetronomePlaying, isFalse);

      // 2. Apagar modulo Dron detiene el dron activo
      final droneId = rackVm.activeModules
          .firstWhere((m) => m.moduleType == RackModuleType.harmonicDrone)
          .moduleId;
      rackVm.toggleModulePower(droneId);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(tunerVm.isDronePlaying, isFalse);

      // 3. Retirar modulo VocalAutoTune desactiva AutoTune
      final autoTuneId = rackVm.activeModules
          .firstWhere((m) => m.moduleType == RackModuleType.vocalAutoTune)
          .moduleId;
      rackVm.removeModule(autoTuneId);
      expect(tunerVm.isAutoTuneActive, isFalse);

      // 4. Retirar ChordAnalyzer desactiva reconocimiento de acordes
      final chordId = rackVm.activeModules
          .firstWhere((m) => m.moduleType == RackModuleType.chordAnalyzer)
          .moduleId;
      rackVm.removeModule(chordId);
      expect(tunerVm.isChordRecognitionActive, isFalse);

      // 5. Apagar grabadora y afinador detiene captura cuando ya no quedan consumidores de audio
      final recorderId = rackVm.activeModules
          .firstWhere((m) => m.moduleType == RackModuleType.practiceRecorder)
          .moduleId;
      final tunerId = rackVm.activeModules
          .firstWhere((m) => m.moduleType == RackModuleType.strobeTuner)
          .moduleId;
      rackVm.toggleModulePower(recorderId);
      expect(audioInputEngine.isCapturing, isTrue); // StrobeTuner sigue encendido

      rackVm.toggleModulePower(tunerId);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(tunerVm.isRecording, isFalse);
      expect(audioInputEngine.isCapturing, isFalse);
    });

    test('No detiene subsistema compartido si existe otra instancia activa del mismo tipo', () async {
      // Agregar un segundo metronomo al rack
      rackVm.addModule(RackModuleType.metronome);
      await tunerVm.startSongWithCountIn();
      expect(tunerVm.isMetronomePlaying, isTrue);

      final metroModules = rackVm.activeModules
          .where((m) => m.moduleType == RackModuleType.metronome)
          .toList();
      expect(metroModules.length, equals(2));

      // Apagar el primero mantiene el metronomo corriendo porque el segundo sigue activo
      rackVm.toggleModulePower(metroModules[0].moduleId);
      expect(tunerVm.isMetronomePlaying, isTrue);

      // Retirar el segundo detiene finalmente el metronomo
      rackVm.removeModule(metroModules[1].moduleId);
      expect(tunerVm.isMetronomePlaying, isFalse);
    });
  });
}
