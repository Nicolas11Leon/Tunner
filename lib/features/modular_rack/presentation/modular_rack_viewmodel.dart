import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/audio/domain/audio_pcm_frame.dart';
import '../../../core/audio/domain/i_studio_audio_engine.dart';
import '../../../core/audio/domain/i_studio_audio_input_engine.dart';
import '../../../core/logging/domain/i_studio_logger.dart';
import '../../instrument/domain/instrument_customization_profile.dart';
import '../../instrument/domain/universal_instrument_definition.dart';
import '../../project_format/domain/patchbay_routing_connection.dart';
import '../../project_format/domain/project_storage_repository.dart';
import '../../project_format/domain/tunner_project_package.dart';
import '../../project_format/domain/tunner_tool_preset.dart';
import '../../../core/file_system/domain/i_platform_file_gateway.dart';
import '../../tuner/domain/note_entity.dart';
import '../../tuner/presentation/tuner_viewmodel.dart';
import '../domain/atomic_signal_event.dart';
import '../domain/interoperable_module_node.dart';
import '../domain/module_connection.dart';
import '../domain/port_id.dart';
import '../domain/rack_module_entity.dart';
import '../domain/signal_bus.dart';
import '../domain/signal_type.dart';

/// Implementacion atomica de un nodo del rack conectable al bus de senales.
class StandardRackNode implements InteroperableModuleNode {
  @override
  final String nodeId;

  @override
  final RackModuleType moduleType;

  final ModularRackViewModel _parentVm;

  final Set<SignalType> _acceptedTypes;

  /// Ultimo evento de senal recibido por este nodo.
  AtomicSignalEvent? lastReceivedEvent;

  /// Telemetria verificable del procesamiento activo por tipo de evento.
  int processedEventsCount = 0;
  TransportCommand? lastTransportCommand;
  double? lastCalibratedA4Hz;
  String? lastTemperamentName;
  double? lastClockBpm;
  int? lastClockTickIndex;
  double? lastPitchHz;
  String? lastPitchNoteName;
  double? lastPitchAmplitude;
  double? lastPcmRms;
  List<double>? lastPcmSamples;
  List<double>? lastAutoTunedPcmSamples;
  List<double>? lastSpectralMagnitudes;

  StandardRackNode({
    required this.nodeId,
    required this.moduleType,
    required ModularRackViewModel parentVm,
    required Set<SignalType> acceptedTypes,
  })  : _parentVm = parentVm,
        _acceptedTypes = acceptedTypes;

  @override
  bool get isProcessingActive {
    final mod = _parentVm.activeModules.firstWhere(
      (m) => m.moduleId == nodeId,
      orElse: () => RackModuleEntity.standard(moduleType, -1, customId: nodeId),
    );
    return mod.isPoweredOn;
  }

  @override
  List<PortId> get declaredInputPorts {
    final mod = _parentVm.activeModules.firstWhere(
      (m) => m.moduleId == nodeId,
      orElse: () => RackModuleEntity.standard(moduleType, -1, customId: nodeId),
    );
    return mod.inputPorts;
  }

  @override
  List<PortId> get declaredOutputPorts {
    final mod = _parentVm.activeModules.firstWhere(
      (m) => m.moduleId == nodeId,
      orElse: () => RackModuleEntity.standard(moduleType, -1, customId: nodeId),
    );
    return mod.outputPorts;
  }

  @override
  Set<SignalType> get acceptedSignalTypes => _acceptedTypes;

  @override
  void onReceiveAtomicSignal(AtomicSignalEvent event) {
    if (!isProcessingActive) return;
    lastReceivedEvent = event;
    processedEventsCount++;
    _parentVm._dispatchSignalToNode(this, event);
  }
}

/// ViewModel principal del Rack de Estudio Modular y la Consola Multitarea.
/// Gobierna el ciclo de vida de los modulos, las conexiones en el SignalBus,
/// el transporte global sincronizado, el enlace con los motores de audio
/// y la emulacion del instrumento activo.
class ModularRackViewModel extends ChangeNotifier {
  static const PortId masterAudioInputPort = PortId(
    id: 'mic_pcm_out',
    displayName: 'Master Audio Input PCM',
    ownerModuleId: 'audio_input_engine',
    signalType: SignalType.audioPcm,
    direction: PortDirection.output,
  );

  static const PortId masterPitchOutputPort = PortId(
    id: 'tuner_pitch_out',
    displayName: 'Master Pitch Output',
    ownerModuleId: 'tuner_viewmodel',
    signalType: SignalType.pitchEvents,
    direction: PortDirection.output,
  );

  static const PortId masterClockOutputPort = PortId(
    id: 'master_clock_out',
    displayName: 'Master Clock Output',
    ownerModuleId: 'tuner_viewmodel',
    signalType: SignalType.temporalClock,
    direction: PortDirection.output,
  );

  final SignalBus signalBus = SignalBus();
  bool _isDisposed = false;
  bool _isDispatchingFromBus = false;

  /// Modulos actualmente montados en el rack de trabajo.
  final List<RackModuleEntity> _activeModules = [];
  List<RackModuleEntity> get activeModules => List.unmodifiable(_activeModules);

  /// Instrumento musical actualmente seleccionado para la sesion.
  UniversalInstrumentDefinition _activeInstrument =
      UniversalInstrumentDefinition.classicalGuitar;
  UniversalInstrumentDefinition get activeInstrument => _activeInstrument;

  /// Perfil completo de personalizacion fisica, timbrica y microtonal.
  late InstrumentCustomizationProfile _activeCustomization =
      InstrumentCustomizationProfile.defaultFor(_activeInstrument);
  InstrumentCustomizationProfile get customization => _activeCustomization;

  /// Telemetria agregada de senales procesadas en el bus.
  double _lastProcessedBpm = 120.0;
  int _lastTickIndex = 0;
  double _lastReferenceA4Hz = 440.0;
  String _lastTemperamentName = 'equal';
  double _lastDetectedPitchHz = 0.0;
  String _lastDetectedNoteName = '--';
  double _lastPcmRms = 0.0;
  int _audioCaptureFrameCount = 0;

  double get lastProcessedBpm => _lastProcessedBpm;
  int get lastTickIndex => _lastTickIndex;
  double get lastReferenceA4Hz => _lastReferenceA4Hz;
  String get lastTemperamentName => _lastTemperamentName;
  double get lastDetectedPitchHz => _lastDetectedPitchHz;
  String get lastDetectedNoteName => _lastDetectedNoteName;
  double get lastPcmRms => _lastPcmRms;
  int get audioCaptureFrameCount => _audioCaptureFrameCount;

  /// Actualiza la personalizacion del instrumento y propaga calibracion atomica al bus.
  void updateCustomization(InstrumentCustomizationProfile profile) {
    _activeCustomization = profile;
    _activeInstrument = profile.instrument;

    signalBus.broadcastGlobalSignal(
      TuningCalibrationEvent(
        eventId: 'tune_calib_${DateTime.now().microsecondsSinceEpoch}',
        sourcePort: const PortId(
          id: 'tuning_out',
          displayName: 'Afinacion Maestra',
          ownerModuleId: 'master_console',
          signalType: SignalType.tuningCalibration,
          direction: PortDirection.output,
        ),
        timestampMicros: DateTime.now().microsecondsSinceEpoch,
        referenceA4Hz: profile.referencePitchA4,
        temperamentName: profile.temperament.name,
      ),
    );

    notifyListeners();
  }

  /// Estado de transporte global (Consola Multitarea).
  bool _isSessionRunning = false;
  bool get isSessionRunning => _isSessionRunning;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  final ProjectStorageRepository _storageRepo;
  final IPlatformFileGateway? _fileGateway;
  final IStudioAudioEngine? audioEngine;
  final IStudioAudioInputEngine? audioInputEngine;
  final IStudioLogger _logger;
  TunerViewModel? _tunerViewModel;
  StreamSubscription<AudioPcmFrame>? _audioInputSubscription;

  double _lastForwardedPitchHz = 0.0;
  String _lastForwardedNoteName = '--';
  int _lastForwardedSubTick = -1;
  double _lastForwardedRefPitch = 440.0;
  String _lastForwardedTemperament = 'equal';

  TunerViewModel? get tunerViewModel => _tunerViewModel;

  ModularRackViewModel({
    ProjectStorageRepository? storageRepository,
    IPlatformFileGateway? fileGateway,
    this.audioEngine,
    this.audioInputEngine,
    TunerViewModel? tunerViewModel,
    IStudioLogger? logger,
  })  : _storageRepo = storageRepository ?? const NoOpProjectStorageRepository(),
        _fileGateway = fileGateway,
        _tunerViewModel = tunerViewModel,
        _logger = logger ?? const NoOpStudioLogger() {
    _initializeDefaultRack();
    _bindAudioInputEngine();
    if (_tunerViewModel != null) {
      bindTunerViewModel(_tunerViewModel!);
    }
  }

  /// Enlaza un [TunerViewModel] con el [SignalBus] de forma bidireccional
  /// con proteccion anti-bucles de retroalimentacion.
  void bindTunerViewModel(TunerViewModel? vm) {
    if (identical(_tunerViewModel, vm)) {
      if (vm != null) {
        _syncSnapshotFromTuner(vm);
      }
      return;
    }
    _unbindTunerViewModel();
    _tunerViewModel = vm;
    if (vm != null) {
      _syncSnapshotFromTuner(vm);
      vm.addListener(_onTunerViewModelChanged);
    }
  }

  void _syncSnapshotFromTuner(TunerViewModel vm) {
    _lastForwardedPitchHz = vm.frequency;
    _lastForwardedNoteName = vm.noteName;
    _lastForwardedSubTick = vm.currentSubTick;
    _lastForwardedRefPitch = vm.referencePitch;
    _lastForwardedTemperament = vm.selectedTemperament.id;
  }

  void _unbindTunerViewModel() {
    _tunerViewModel?.removeListener(_onTunerViewModelChanged);
  }

  void _bindAudioInputEngine() {
    final input = audioInputEngine;
    if (input == null) return;
    signalBus.registerPort(masterAudioInputPort);
    unawaited(_audioInputSubscription?.cancel());
    _audioInputSubscription = input.pcmFrameStream.listen((frame) {
      if (_isDisposed) return;
      final samples = frame.samples.toList(growable: false);
      double sumSquares = 0.0;
      for (final s in samples) {
        sumSquares += s * s;
      }
      final rms = samples.isNotEmpty
          ? math.sqrt(sumSquares / samples.length).clamp(0.0, 1.0)
          : 0.0;

      final event = AudioPcmEvent(
        eventId: 'pcm_${frame.timestampMicros}',
        sourcePort: masterAudioInputPort,
        timestampMicros: frame.timestampMicros,
        samples: samples,
        sampleRate: frame.sampleRate,
        rmsLevel: rms,
      );

      final hasCustomWiring = signalBus.activeConnections.any(
        (c) => c.sourcePort == masterAudioInputPort,
      );
      if (hasCustomWiring) {
        signalBus.emitAtomicEvent(event);
      } else {
        signalBus.broadcastGlobalSignal(event);
      }
    });
  }

  void _onTunerViewModelChanged() {
    final vm = _tunerViewModel;
    if (_isDisposed || _isDispatchingFromBus || vm == null) return;

    final nowMicros = DateTime.now().microsecondsSinceEpoch;

    if (vm.frequency > 20.0 &&
        (vm.frequency != _lastForwardedPitchHz || vm.noteName != _lastForwardedNoteName)) {
      _lastForwardedPitchHz = vm.frequency;
      _lastForwardedNoteName = vm.noteName;

      final tunerMod = _findActiveModuleByType(RackModuleType.strobeTuner);
      if (tunerMod != null && tunerMod.isPoweredOn) {
        final pitchPort = tunerMod.outputPorts.firstWhere(
          (p) => p.signalType == SignalType.pitchEvents,
          orElse: () => masterPitchOutputPort,
        );
        signalBus.emitAtomicEvent(
          PitchDetectionEvent(
            eventId: 'pitch_$nowMicros',
            sourcePort: pitchPort,
            timestampMicros: nowMicros,
            frequencyHz: vm.frequency,
            noteName: vm.noteName,
            centsOffset: vm.cents,
            clarity: vm.lastClarity > 0.0 ? vm.lastClarity : 0.95,
            amplitude: vm.currentMicRmsLevel.clamp(0.0, 1.0),
          ),
        );
      }
    }

    if (vm.isMetronomePlaying &&
        vm.currentSubTick >= 0 &&
        vm.currentSubTick != _lastForwardedSubTick) {
      _lastForwardedSubTick = vm.currentSubTick;
      final metroMod = _findActiveModuleByType(RackModuleType.metronome);
      if (metroMod != null && metroMod.isPoweredOn) {
        final clockPort = metroMod.outputPorts.firstWhere(
          (p) => p.signalType == SignalType.temporalClock,
          orElse: () => masterClockOutputPort,
        );
        final ts = vm.currentMeasureTimeSignature;
        signalBus.emitAtomicEvent(
          ClockTickEvent(
            eventId: 'clk_$nowMicros',
            sourcePort: clockPort,
            timestampMicros: nowMicros,
            tickIndex: vm.currentSubTick,
            beatsPerBar: ts.numerator,
            bpm: vm.bpm.toDouble(),
            isDownbeat: vm.currentSubTick == 0,
            tickDurationMs: 60000.0 / math.max(1, vm.bpm) / 4.0,
          ),
        );
      }
    }

    if ((vm.referencePitch - _lastForwardedRefPitch).abs() > 0.01 ||
        vm.selectedTemperament.id != _lastForwardedTemperament) {
      _lastForwardedRefPitch = vm.referencePitch;
      _lastForwardedTemperament = vm.selectedTemperament.id;
      signalBus.broadcastGlobalSignal(
        TuningCalibrationEvent(
          eventId: 'tuner_calib_$nowMicros',
          sourcePort: masterPitchOutputPort,
          timestampMicros: nowMicros,
          referenceA4Hz: vm.referencePitch,
          temperamentName: vm.selectedTemperament.id,
        ),
      );
    }
  }

  RackModuleEntity? _findActiveModuleByType(RackModuleType type) {
    for (final mod in _activeModules) {
      if (mod.moduleType == type) return mod;
    }
    return null;
  }

  void _runWithoutBusFeedback(void Function() action) {
    if (_isDispatchingFromBus) {
      action();
      return;
    }
    _isDispatchingFromBus = true;
    try {
      action();
    } finally {
      _isDispatchingFromBus = false;
    }
  }

  void _fireAndLog(Future<void>? future, String actionName) {
    if (future == null) return;
    unawaited(
      future.catchError((Object error, StackTrace stackTrace) {
        _logger.warning(
          'ModularRackViewModel',
          'Fallo en accion asincrona $actionName: $error',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  void _dispatchSignalToNode(StandardRackNode node, AtomicSignalEvent event) {
    _runWithoutBusFeedback(() {
      switch (event) {
        case TransportControlEvent():
          _handleNodeTransportEvent(node, event);
        case TuningCalibrationEvent():
          _handleNodeCalibrationEvent(node, event);
        case ClockTickEvent():
          _handleNodeClockTickEvent(node, event);
        case PitchDetectionEvent():
          _handleNodePitchEvent(node, event);
        case AudioPcmEvent():
          _handleNodeAudioPcmEvent(node, event);
        case SpectralDataEvent():
          node.lastSpectralMagnitudes = event.magnitudes;
      }
    });
  }

  void _handleNodeTransportEvent(StandardRackNode node, TransportControlEvent event) {
    node.lastTransportCommand = event.command;
    final vm = _tunerViewModel;
    final cmd = event.command;

    switch (node.moduleType) {
      case RackModuleType.metronome:
        if (cmd == TransportCommand.play && vm != null && !vm.isMetronomePlaying) {
          _fireAndLog(vm.startSongWithCountIn(), 'startMetronomeFromBus');
        } else if ((cmd == TransportCommand.pause || cmd == TransportCommand.stop) &&
            vm != null &&
            vm.isMetronomePlaying) {
          vm.stopSong();
        } else if (cmd == TransportCommand.stop) {
          _fireAndLog(audioEngine?.getChannel('metronome_click').stop(), 'stopMetronomeChannel');
        }
      case RackModuleType.practiceRecorder:
        if (cmd == TransportCommand.record) {
          if (audioInputEngine != null && !audioInputEngine!.isCapturing) {
            _fireAndLog(audioInputEngine!.startCapture(), 'startCaptureForRecorder');
          }
          if (vm != null && !vm.isAudioRecording) {
            _fireAndLog(vm.startPracticeRecording(), 'startPracticeRecordingFromBus');
          }
        } else if (cmd == TransportCommand.toggleRecord) {
          _fireAndLog(vm?.togglePracticeRecording(), 'togglePracticeRecordingFromBus');
        } else if (cmd == TransportCommand.stop || cmd == TransportCommand.pause) {
          if (vm != null && vm.isAudioRecording) {
            _fireAndLog(vm.stopPracticeRecording(), 'stopPracticeRecordingFromBus');
          }
          if (vm != null && vm.isPlayingAudio) {
            _fireAndLog(vm.stopActiveRecordingPlayback(), 'stopPlaybackFromBus');
          }
          if (cmd == TransportCommand.stop) {
            if (audioInputEngine != null && audioInputEngine!.isCapturing) {
              _fireAndLog(audioInputEngine!.stopCapture(), 'stopCaptureFromRecorderBus');
            }
            _fireAndLog(audioEngine?.getChannel('practice_take').stop(), 'stopPracticeChannel');
          }
        } else if (cmd == TransportCommand.rewind) {
          _fireAndLog(vm?.seekPlayback(Duration.zero), 'rewindPracticePlayback');
        }
      case RackModuleType.strobeTuner:
        if (cmd == TransportCommand.play || cmd == TransportCommand.record) {
          if (audioInputEngine != null && !audioInputEngine!.isCapturing) {
            _fireAndLog(audioInputEngine!.startCapture(), 'startCaptureForTuner');
          }
          if (vm != null && !vm.isRecording) {
            _fireAndLog(vm.toggleRecording(), 'startTunerFromBus');
          }
        } else if (cmd == TransportCommand.stop || cmd == TransportCommand.pause) {
          if (vm != null && vm.isRecording) {
            _fireAndLog(vm.toggleRecording(), 'stopTunerFromBus');
          }
          if (cmd == TransportCommand.stop && audioInputEngine != null && audioInputEngine!.isCapturing) {
            _fireAndLog(audioInputEngine!.stopCapture(), 'stopCaptureFromBus');
          }
        }
      case RackModuleType.harmonicDrone:
        if (cmd == TransportCommand.stop || cmd == TransportCommand.pause) {
          _fireAndLog(vm?.stopDrone(), 'stopDroneFromBus');
          _fireAndLog(audioEngine?.getChannel('harmonic_drone').stop(), 'stopDroneChannel');
        }
      case RackModuleType.scoreNotation:
        if (cmd == TransportCommand.rewind) {
          vm?.resetSongState();
        } else if (cmd == TransportCommand.stop) {
          vm?.scorePlaybackCoordinator.stopPlayback();
        }
      case RackModuleType.earTrainer:
        if (cmd == TransportCommand.stop || cmd == TransportCommand.pause) {
          _fireAndLog(vm?.stopReferenceTone(), 'stopReferenceToneFromBus');
          _fireAndLog(audioEngine?.getChannel('tuning_diapason').stop(), 'stopDiapasonChannel');
        }
      case RackModuleType.vocalAutoTune:
      case RackModuleType.spectrogram:
      case RackModuleType.chordAnalyzer:
      case RackModuleType.guidedLessons:
      case RackModuleType.djConsole:
      case RackModuleType.stemMixer:
        break;
    }
  }

  void _handleNodeCalibrationEvent(StandardRackNode node, TuningCalibrationEvent event) {
    node.lastCalibratedA4Hz = event.referenceA4Hz;
    node.lastTemperamentName = event.temperamentName;
    _lastReferenceA4Hz = event.referenceA4Hz;
    _lastTemperamentName = event.temperamentName;

    final vm = _tunerViewModel;
    if (vm == null) return;

    vm.setReferencePitch(event.referenceA4Hz);
    if (event.temperamentName.isNotEmpty) {
      vm.setTemperament(event.temperamentName);
    }
    if (node.moduleType == RackModuleType.vocalAutoTune) {
      final clampedA4 = event.referenceA4Hz.clamp(415.0, 466.0);
      if ((vm.autoTuneConfig.a4Reference - clampedA4).abs() > 0.01) {
        vm.updateAutoTuneConfig(
          vm.autoTuneConfig.copyWith(a4Reference: clampedA4),
        );
      }
    }
    _syncSnapshotFromTuner(vm);
  }

  void _handleNodeClockTickEvent(StandardRackNode node, ClockTickEvent event) {
    node.lastClockBpm = event.bpm;
    node.lastClockTickIndex = event.tickIndex;
    _lastProcessedBpm = event.bpm;
    _lastTickIndex = event.tickIndex;

    final vm = _tunerViewModel;
    if (vm == null) return;

    if (node.moduleType == RackModuleType.scoreNotation ||
        node.moduleType == RackModuleType.guidedLessons ||
        node.moduleType == RackModuleType.practiceRecorder) {
      vm.ingestBusClockTick(tickIndex: event.tickIndex, bpm: event.bpm);
      _syncSnapshotFromTuner(vm);
    }
  }

  void _handleNodePitchEvent(StandardRackNode node, PitchDetectionEvent event) {
    node.lastPitchHz = event.frequencyHz;
    node.lastPitchNoteName = event.noteName;
    node.lastPitchAmplitude = event.amplitude;
    _lastDetectedPitchHz = event.frequencyHz;
    if (event.noteName.isNotEmpty) {
      _lastDetectedNoteName = event.noteName;
    } else if (event.frequencyHz > 20.0) {
      _lastDetectedNoteName = NoteEntity.fromFrequency(
        event.frequencyHz,
        a4Ref: _lastReferenceA4Hz,
      ).name;
    }

    final vm = _tunerViewModel;
    if (vm == null) return;

    if (node.moduleType == RackModuleType.vocalAutoTune) {
      if (vm.isAutoTuneActive && event.frequencyHz > 20.0) {
        vm.autoTuneProcessor.evaluatePitchFrame(
          detectedPitchHz: event.frequencyHz,
        );
      }
      return;
    }

    if (node.moduleType == RackModuleType.scoreNotation ||
        node.moduleType == RackModuleType.guidedLessons ||
        node.moduleType == RackModuleType.earTrainer) {
      vm.ingestBusPitchFrame(
        frequencyHz: event.frequencyHz,
        noteName: event.noteName,
        centsOffset: event.centsOffset,
        clarity: event.clarity,
      );
      _syncSnapshotFromTuner(vm);
    }
  }

  void _handleNodeAudioPcmEvent(StandardRackNode node, AudioPcmEvent event) {
    node.lastPcmRms = event.rmsLevel;
    node.lastPcmSamples = event.samples;
    _lastPcmRms = event.rmsLevel;
    _audioCaptureFrameCount++;

    final vm = _tunerViewModel;
    final engine = audioEngine;

    if (engine != null &&
        (node.moduleType == RackModuleType.vocalAutoTune ||
            node.moduleType == RackModuleType.practiceRecorder ||
            node.moduleType == RackModuleType.earTrainer)) {
      _fireAndLog(
        engine.getChannel(node.nodeId).setVolume(event.rmsLevel.clamp(0.0, 1.0)),
        'syncChannelVolume_${node.nodeId}',
      );
    }

    if (node.moduleType == RackModuleType.vocalAutoTune &&
        vm != null &&
        vm.isAutoTuneActive &&
        event.samples.isNotEmpty &&
        _lastDetectedPitchHz > 20.0) {
      final processed = vm.autoTuneProcessor.processAudioBlock(
        pcmSamples: Float64List.fromList(event.samples),
        detectedPitchHz: _lastDetectedPitchHz,
        sampleRate: event.sampleRate,
      );
      node.lastAutoTunedPcmSamples = processed.toList(growable: false);
    }

    if (vm == null) return;

    if (node.moduleType == RackModuleType.chordAnalyzer) {
      if (vm.isChordRecognitionActive && event.samples.isNotEmpty) {
        vm.processChordSamples(event.samples);
        _syncSnapshotFromTuner(vm);
      }
    } else if (node.moduleType == RackModuleType.strobeTuner ||
        node.moduleType == RackModuleType.spectrogram) {
      vm.ingestBusAudioPcm(event.samples);
      _syncSnapshotFromTuner(vm);
    }
  }

  /// Configura el rack inicial por defecto con herramientas clave conectadas.
  void _initializeDefaultRack() {
    final tuner = RackModuleEntity.standard(RackModuleType.strobeTuner, 0);
    final metronome = RackModuleEntity.standard(RackModuleType.metronome, 1);
    final score = RackModuleEntity.standard(RackModuleType.scoreNotation, 2);
    final recorder = RackModuleEntity.standard(RackModuleType.practiceRecorder, 3);

    _activeModules.addAll([tuner, metronome, score, recorder]);

    _registerNodeForModule(tuner, {SignalType.audioPcm, SignalType.tuningCalibration});
    _registerNodeForModule(metronome, {SignalType.transportControl});
    _registerNodeForModule(score, {SignalType.temporalClock, SignalType.pitchEvents});
    _registerNodeForModule(
      recorder,
      {SignalType.audioPcm, SignalType.temporalClock, SignalType.transportControl},
    );

    final metroClock = metronome.outputPorts.firstWhere(
      (p) => p.signalType == SignalType.temporalClock,
    );
    final scoreClock = score.inputPorts.firstWhere(
      (p) => p.signalType == SignalType.temporalClock,
    );
    signalBus.addConnection(
      ModuleConnection.pointToPoint(source: metroClock, destination: scoreClock),
    );

    final tunerPitch = tuner.outputPorts.firstWhere(
      (p) => p.signalType == SignalType.pitchEvents,
    );
    final scorePitch = score.inputPorts.firstWhere(
      (p) => p.signalType == SignalType.pitchEvents,
    );
    signalBus.addConnection(
      ModuleConnection.pointToPoint(source: tunerPitch, destination: scorePitch),
    );
  }

  void _registerNodeForModule(RackModuleEntity module, Set<SignalType> acceptedTypes) {
    final node = StandardRackNode(
      nodeId: module.moduleId,
      moduleType: module.moduleType,
      parentVm: this,
      acceptedTypes: acceptedTypes,
    );
    signalBus.registerNode(node);
  }

  /// Cambia el instrumento universal activo y actualiza perfiles timbricos/visuales.
  void selectInstrument(UniversalInstrumentDefinition instrument) {
    _activeInstrument = instrument;
    _activeCustomization = InstrumentCustomizationProfile.defaultFor(instrument);
    updateCustomization(_activeCustomization);
  }

  /// Devuelve el conjunto de tipos de senal compatibles para un tipo de modulo.
  Set<SignalType> getAcceptedSignalsForType(RackModuleType type) {
    switch (type) {
      case RackModuleType.strobeTuner:
      case RackModuleType.spectrogram:
        return {SignalType.audioPcm, SignalType.tuningCalibration};
      case RackModuleType.scoreNotation:
        return {SignalType.temporalClock, SignalType.pitchEvents, SignalType.transportControl};
      case RackModuleType.practiceRecorder:
        return {SignalType.audioPcm, SignalType.temporalClock, SignalType.transportControl};
      case RackModuleType.vocalAutoTune:
        return {SignalType.audioPcm, SignalType.pitchEvents, SignalType.tuningCalibration};
      case RackModuleType.harmonicDrone:
        return {SignalType.tuningCalibration, SignalType.pitchEvents, SignalType.transportControl};
      case RackModuleType.chordAnalyzer:
        return {SignalType.audioPcm, SignalType.pitchEvents};
      case RackModuleType.guidedLessons:
        return {SignalType.temporalClock, SignalType.pitchEvents};
      case RackModuleType.earTrainer:
        return {SignalType.pitchEvents, SignalType.audioPcm, SignalType.tuningCalibration, SignalType.transportControl};
      case RackModuleType.metronome:
        return {SignalType.transportControl};
      case RackModuleType.djConsole:
        return {SignalType.audioPcm, SignalType.temporalClock, SignalType.transportControl};
      case RackModuleType.stemMixer:
        return {SignalType.audioPcm, SignalType.transportControl};
    }
  }

  /// Agrega un nuevo modulo al rack e inicializa su nodo de interoperabilidad.
  void addModule(RackModuleType type) {
    final newOrder = _activeModules.length;
    final module = RackModuleEntity.standard(type, newOrder);
    _activeModules.add(module);

    _registerNodeForModule(module, getAcceptedSignalsForType(type));
    notifyListeners();
  }

  /// Elimina un modulo del rack, detiene su subsistema activo y desregistra
  /// sus puertos y nodo del SignalBus.
  void removeModule(String moduleId) {
    final index = _activeModules.indexWhere((m) => m.moduleId == moduleId);
    if (index != -1) {
      final mod = _activeModules[index];
      _shutdownSubsystemForModule(mod);
      signalBus.unregisterNode(moduleId);
      _activeModules.removeAt(index);
      _reindexModules();
      notifyListeners();
    }
  }

  /// Reordena los modulos tras un gesto Drag & Drop del usuario.
  void reorderModules(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _activeModules.removeAt(oldIndex);
    _activeModules.insert(newIndex, item);
    _reindexModules();
    notifyListeners();
  }

  /// Alterna entre vista compacta y expandida de un modulo.
  void toggleViewMode(String moduleId) {
    final index = _activeModules.indexWhere((m) => m.moduleId == moduleId);
    if (index != -1) {
      final mod = _activeModules[index];
      final newMode = mod.viewMode == ModuleViewMode.expanded
          ? ModuleViewMode.compact
          : ModuleViewMode.expanded;
      _activeModules[index] = mod.copyWith(viewMode: newMode);
      notifyListeners();
    }
  }

  /// Alterna el encendido / apagado de un modulo y detiene su subsistema activo
  /// al transicionar a estado apagado.
  void toggleModulePower(String moduleId) {
    final index = _activeModules.indexWhere((m) => m.moduleId == moduleId);
    if (index != -1) {
      final mod = _activeModules[index];
      final updated = mod.copyWith(isPoweredOn: !mod.isPoweredOn);
      _activeModules[index] = updated;
      if (!updated.isPoweredOn) {
        _shutdownSubsystemForModule(updated);
      }
      notifyListeners();
    }
  }

  void _shutdownSubsystemForModule(RackModuleEntity module) {
    final hasOtherActive = _activeModules.any(
      (m) => m.moduleId != module.moduleId && m.moduleType == module.moduleType && m.isPoweredOn,
    );
    if (hasOtherActive) return;

    final vm = _tunerViewModel;
    _runWithoutBusFeedback(() {
      switch (module.moduleType) {
        case RackModuleType.metronome:
          if (vm != null && vm.isMetronomePlaying) {
            vm.stopSong();
          }
          _fireAndLog(
            audioEngine?.getChannel('metronome_click').stop(),
            'shutdownMetronomeChannel',
          );
        case RackModuleType.harmonicDrone:
          if (vm != null) {
            _fireAndLog(vm.stopDrone(), 'shutdownDrone');
          }
          _fireAndLog(
            audioEngine?.getChannel('harmonic_drone').stop(),
            'shutdownDroneChannel',
          );
        case RackModuleType.practiceRecorder:
          _isRecording = false;
          if (vm != null && vm.isAudioRecording) {
            _fireAndLog(vm.stopPracticeRecording(), 'shutdownPracticeRecording');
          }
          if (vm != null && vm.isPlayingAudio) {
            _fireAndLog(vm.stopActiveRecordingPlayback(), 'shutdownPracticePlayback');
          }
          _fireAndLog(
            audioEngine?.getChannel('practice_take').stop(),
            'shutdownPracticeTakeChannel',
          );
          _stopCaptureIfNoActiveAudioConsumers(excludingModuleId: module.moduleId);
        case RackModuleType.vocalAutoTune:
          if (vm != null && vm.isAutoTuneActive) {
            vm.toggleAutoTune();
          }
          _stopCaptureIfNoActiveAudioConsumers(excludingModuleId: module.moduleId);
        case RackModuleType.strobeTuner:
          if (vm != null && vm.isRecording) {
            _fireAndLog(vm.toggleRecording(), 'shutdownStrobeTuner');
          }
          _stopCaptureIfNoActiveAudioConsumers(excludingModuleId: module.moduleId);
        case RackModuleType.chordAnalyzer:
          if (vm != null && vm.isChordRecognitionActive) {
            vm.setChordRecognitionActive(false);
          }
          _stopCaptureIfNoActiveAudioConsumers(excludingModuleId: module.moduleId);
        case RackModuleType.scoreNotation:
          if (vm != null) {
            vm.scorePlaybackCoordinator.stopPlayback();
            if (vm.isLiveTranscriptionActive) {
              vm.toggleLiveTranscription();
            }
            if (vm.isPolyphonicTranscriptionActive) {
              vm.togglePolyphonicLiveTranscription();
            }
          }
        case RackModuleType.guidedLessons:
          if (vm != null && vm.hasActiveGuidedLesson) {
            vm.cancelGuidedLesson();
          }
        case RackModuleType.earTrainer:
          if (vm != null) {
            _fireAndLog(vm.stopReferenceTone(), 'shutdownEarTrainerTone');
          }
          _fireAndLog(
            audioEngine?.getChannel('tuning_diapason').stop(),
            'shutdownDiapasonChannel',
          );
          _fireAndLog(
            audioEngine?.getChannel('instrument_note').stop(),
            'shutdownInstrumentNoteChannel',
          );
        case RackModuleType.spectrogram:
          _stopCaptureIfNoActiveAudioConsumers(excludingModuleId: module.moduleId);
        case RackModuleType.djConsole:
        case RackModuleType.stemMixer:
          break;
      }
      _fireAndLog(
        audioEngine?.getChannel(module.moduleId).stop(),
        'shutdownModuleChannel_${module.moduleId}',
      );
      if (vm != null) {
        _syncSnapshotFromTuner(vm);
      }
    });
  }

  void _stopCaptureIfNoActiveAudioConsumers({required String excludingModuleId}) {
    final input = audioInputEngine;
    if (input == null || !input.isCapturing) return;
    final hasOtherAudioConsumer = _activeModules.any(
      (m) =>
          m.moduleId != excludingModuleId &&
          m.isPoweredOn &&
          (m.moduleType == RackModuleType.strobeTuner ||
              m.moduleType == RackModuleType.practiceRecorder ||
              m.moduleType == RackModuleType.spectrogram ||
              m.moduleType == RackModuleType.chordAnalyzer ||
              m.moduleType == RackModuleType.vocalAutoTune),
    );
    if (!hasOtherAudioConsumer) {
      _fireAndLog(input.stopCapture(), 'stopCaptureOnModuleShutdown');
    }
  }

  /// Renombra una herramienta activa del rack en tiempo real.
  void renameModule(String moduleId, String newTitle) {
    final index = _activeModules.indexWhere((m) => m.moduleId == moduleId);
    if (index != -1 && newTitle.trim().isNotEmpty) {
      final mod = _activeModules[index];
      _activeModules[index] = mod.copyWith(title: newTitle.trim());
      notifyListeners();
    }
  }

  /// Conecta dos puertos en modo punto a punto o broadcast.
  void connectPorts(PortId source, PortId destination, {bool broadcast = false}) {
    if (broadcast) {
      signalBus.addConnection(ModuleConnection.broadcast(source: source));
    } else {
      signalBus.addConnection(
        ModuleConnection.pointToPoint(source: source, destination: destination),
      );
    }
    notifyListeners();
  }

  /// Desconecta una conexion por su ID.
  void disconnect(String connectionId) {
    signalBus.removeConnection(connectionId);
    notifyListeners();
  }

  // --- CONTROLES DE LA CONSOLA MULTITAREA ---

  /// Inicia o detiene la sesion multitarea sincronizada de todos los modulos.
  void toggleMasterSession() {
    _isSessionRunning = !_isSessionRunning;

    signalBus.broadcastGlobalSignal(
      TransportControlEvent(
        eventId: 'trans_${DateTime.now().microsecondsSinceEpoch}',
        sourcePort: const PortId(
          id: 'transport_out',
          displayName: 'Transporte Global',
          ownerModuleId: 'master_console',
          signalType: SignalType.transportControl,
          direction: PortDirection.output,
        ),
        timestampMicros: DateTime.now().microsecondsSinceEpoch,
        command: _isSessionRunning ? TransportCommand.play : TransportCommand.pause,
      ),
    );

    notifyListeners();
  }

  /// Inicia o detiene la grabacion de la sesion maestra.
  void toggleMasterRecording() {
    if (!_isSessionRunning && !_isRecording) {
      _isSessionRunning = true;
    }
    _isRecording = !_isRecording;

    signalBus.broadcastGlobalSignal(
      TransportControlEvent(
        eventId: 'trans_rec_${DateTime.now().microsecondsSinceEpoch}',
        sourcePort: const PortId(
          id: 'transport_out',
          displayName: 'Transporte Global',
          ownerModuleId: 'master_console',
          signalType: SignalType.transportControl,
          direction: PortDirection.output,
        ),
        timestampMicros: DateTime.now().microsecondsSinceEpoch,
        command: _isRecording ? TransportCommand.record : TransportCommand.stop,
      ),
    );

    notifyListeners();
  }

  /// Detiene todo el transporte global.
  void stopMasterSession() {
    _isSessionRunning = false;
    _isRecording = false;

    signalBus.broadcastGlobalSignal(
      TransportControlEvent(
        eventId: 'trans_stop_${DateTime.now().microsecondsSinceEpoch}',
        sourcePort: const PortId(
          id: 'transport_out',
          displayName: 'Transporte Global',
          ownerModuleId: 'master_console',
          signalType: SignalType.transportControl,
          direction: PortDirection.output,
        ),
        timestampMicros: DateTime.now().microsecondsSinceEpoch,
        command: TransportCommand.stop,
      ),
    );

    notifyListeners();
  }

  /// Carga un preset de sesion predeterminado.
  void loadPreset(String presetName) {
    _activeModules.clear();
    signalBus.clearRoutes();

    switch (presetName) {
      case 'calentamiento':
        addModule(RackModuleType.strobeTuner);
        addModule(RackModuleType.harmonicDrone);
        addModule(RackModuleType.metronome);
        break;

      case 'transcripcion_partitura':
        addModule(RackModuleType.strobeTuner);
        addModule(RackModuleType.scoreNotation);
        addModule(RackModuleType.metronome);
        final tuner = _activeModules[0];
        final score = _activeModules[1];
        signalBus.addConnection(
          ModuleConnection.pointToPoint(
            source: tuner.outputPorts.firstWhere((p) => p.signalType == SignalType.pitchEvents),
            destination: score.inputPorts.firstWhere((p) => p.signalType == SignalType.pitchEvents),
          ),
        );
        break;

      case 'produccion_vocal':
        addModule(RackModuleType.vocalAutoTune);
        addModule(RackModuleType.practiceRecorder);
        addModule(RackModuleType.spectrogram);
        final tune = _activeModules[0];
        final rec = _activeModules[1];
        signalBus.addConnection(
          ModuleConnection.pointToPoint(
            source: tune.outputPorts.firstWhere((p) => p.signalType == SignalType.audioPcm),
            destination: rec.inputPorts.firstWhere((p) => p.signalType == SignalType.audioPcm),
          ),
        );
        break;

      default:
        _initializeDefaultRack();
        break;
    }

    _reindexModules();
    notifyListeners();
  }

  // --- FORMATO DE PROYECTO PROPIETARIO HIPER-COMPRIMIDO (.tunner / .tnt) ---

  /// Empaqueta la sesion actual en un TunnerProjectPackage inmutable.
  TunnerProjectPackage createProjectPackage({
    String projectName = 'Mi Proyecto Tunner',
    String author = 'Tunner Artist',
    String notes = '',
  }) {
    final toolPresets = _activeModules
        .map((m) => TunnerToolPreset.fromModule(m))
        .toList();

    final connections = signalBus.activeConnections.map((c) {
      return PatchbayRoutingConnection(
        connectionId: c.connectionId,
        sourceModuleId: c.sourcePort.ownerModuleId,
        sourcePortId: c.sourcePort.id,
        destinationModuleId: c.destinationPort?.ownerModuleId,
        destinationPortId: c.destinationPort?.id,
        signalType: c.sourcePort.signalType,
        isBroadcast: c.scope == ConnectionScope.broadcast,
      );
    }).toList();

    final now = DateTime.now().microsecondsSinceEpoch;

    return TunnerProjectPackage(
      projectId: 'proj_$now',
      projectName: projectName,
      author: author,
      notes: notes,
      tools: toolPresets,
      patchConnections: connections,
      createdAtMicros: now,
      updatedAtMicros: now,
    );
  }

  /// Carga y restaura un proyecto completo, reconfigurando modulos y cableado en el SignalBus.
  void loadProjectPackage(TunnerProjectPackage package) {
    _activeModules.clear();
    signalBus.clearRoutes();

    for (int i = 0; i < package.tools.length; i++) {
      final preset = package.tools[i];
      final mod = preset.toModuleEntity(i, customId: 'mod_${preset.moduleTypeCode}_$i');
      _activeModules.add(mod);
      _registerNodeForModule(mod, getAcceptedSignalsForType(mod.moduleType));
    }

    for (final conn in package.patchConnections) {
      final sourceMod = _activeModules.cast<RackModuleEntity?>().firstWhere(
        (m) => m?.moduleId == conn.sourceModuleId,
        orElse: () => null,
      );
      if (sourceMod == null) continue;

      final sourcePort = sourceMod.outputPorts.cast<PortId?>().firstWhere(
        (p) => p?.id == conn.sourcePortId,
        orElse: () => null,
      );
      if (sourcePort == null) continue;

      if (conn.isBroadcast) {
        signalBus.addConnection(ModuleConnection.broadcast(source: sourcePort));
      } else if (conn.destinationModuleId != null && conn.destinationPortId != null) {
        final destMod = _activeModules.cast<RackModuleEntity?>().firstWhere(
          (m) => m?.moduleId == conn.destinationModuleId,
          orElse: () => null,
        );
        if (destMod != null) {
          final destPort = destMod.inputPorts.cast<PortId?>().firstWhere(
            (p) => p?.id == conn.destinationPortId,
            orElse: () => null,
          );
          if (destPort != null) {
            signalBus.addConnection(
              ModuleConnection.pointToPoint(source: sourcePort, destination: destPort),
            );
          }
        }
      }
    }

    _reindexModules();
    notifyListeners();
  }

  /// Exporta una herramienta especifica a un preset individual TunnerToolPreset (.tnt).
  TunnerToolPreset exportToolPreset(String moduleId) {
    final module = _activeModules.firstWhere(
      (m) => m.moduleId == moduleId,
      orElse: () => throw StateError('Modulo no encontrado: $moduleId'),
    );
    return TunnerToolPreset.fromModule(module);
  }

  /// Importa una herramienta desde un preset y la monta en el rack de trabajo.
  void importToolPreset(TunnerToolPreset preset) {
    final newOrder = _activeModules.length;
    final module = preset.toModuleEntity(
      newOrder,
      customId: 'imported_${preset.moduleTypeCode}_${DateTime.now().microsecondsSinceEpoch}',
    );
    _activeModules.add(module);
    _registerNodeForModule(module, getAcceptedSignalsForType(module.moduleType));
    notifyListeners();
  }

  /// Guarda el proyecto actual en disco con compresion binaria (.tunner).
  Future<String> saveProjectToFile({String? filePath, String? projectName}) async {
    final package = createProjectPackage(
      projectName: projectName ?? 'Proyecto Tunner',
    );
    final safeName = projectName?.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_') ?? 'proyecto';
    String target;
    if (filePath != null && filePath.isNotEmpty) {
      target = filePath;
    } else {
      final docsDir = await _fileGateway?.getDocumentsDirectoryPath() ?? '';
      target = docsDir.isNotEmpty ? '$docsDir/$safeName.tunner' : '$safeName.tunner';
    }
    await _storageRepo.saveProject(target, package);
    return target;
  }

  /// Carga y descomprime un proyecto desde disco (.tunner).
  Future<void> loadProjectFromFile(String filePath) async {
    final package = await _storageRepo.loadProject(filePath);
    loadProjectPackage(package);
  }

  /// Abre el selector nativo para cargar un proyecto `.tunner`.
  Future<String?> pickAndLoadProject() async {
    final picked = await _fileGateway?.pickFile(allowedExtensions: const ['tunner']);
    final path = picked?.path;
    if (path == null || path.isEmpty) return null;
    await loadProjectFromFile(path);
    return picked?.name ?? path;
  }

  /// Exporta una herramienta a un archivo binario comprimido (.tnt).
  Future<String> exportToolPresetToFile(String moduleId, [String? filePath]) async {
    final preset = exportToolPreset(moduleId);
    final target = filePath ?? '${moduleId}_preset.tnt';
    await _storageRepo.saveToolPreset(target, preset);
    return target;
  }

  /// Importa una herramienta desde un archivo (.tnt).
  Future<void> importToolPresetFromFile(String filePath) async {
    final preset = await _storageRepo.loadToolPreset(filePath);
    importToolPreset(preset);
  }

  /// Abre el selector nativo para importar un preset de herramienta `.tnt`.
  Future<String?> pickAndImportToolPreset() async {
    final picked = await _fileGateway?.pickFile(allowedExtensions: const ['tnt']);
    final path = picked?.path;
    if (path == null || path.isEmpty) return null;
    await importToolPresetFromFile(path);
    return picked?.name ?? path;
  }

  void _reindexModules() {
    for (int i = 0; i < _activeModules.length; i++) {
      _activeModules[i] = _activeModules[i].copyWith(orderIndex: i);
    }
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    unawaited(_audioInputSubscription?.cancel());
    _audioInputSubscription = null;
    _unbindTunerViewModel();
    signalBus.dispose();
    super.dispose();
  }
}
