import 'package:flutter/foundation.dart';
import '../domain/signal_type.dart';
import '../domain/port_id.dart';
import '../domain/module_connection.dart';
import '../domain/signal_bus.dart';
import '../domain/rack_module_entity.dart';
import '../domain/atomic_signal_event.dart';
import '../domain/interoperable_module_node.dart';
import '../../instrument/domain/universal_instrument_definition.dart';
import '../../instrument/domain/instrument_customization_profile.dart';

/// Implementación atómica de un nodo del rack conectable al bus de señales.
class StandardRackNode implements InteroperableModuleNode {
  @override
  final String nodeId;

  @override
  final RackModuleType moduleType;

  final ModularRackViewModel _parentVm;

  final Set<SignalType> _acceptedTypes;

  /// Último evento de señal recibido por este nodo.
  AtomicSignalEvent? lastReceivedEvent;

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
    lastReceivedEvent = event;
  }
}

/// ViewModel principal del Rack de Estudio Modular y la Consola Multitarea.
/// Gobierna el ciclo de vida de los módulos, las conexiones en el SignalBus,
/// el transporte global sincronizado y la emulación del instrumento activo.
class ModularRackViewModel extends ChangeNotifier {
  final SignalBus signalBus = SignalBus();

  /// Módulos actualmente montados en el rack de trabajo.
  final List<RackModuleEntity> _activeModules = [];
  List<RackModuleEntity> get activeModules => List.unmodifiable(_activeModules);

  /// Instrumento musical actualmente seleccionado para la sesión.
  UniversalInstrumentDefinition _activeInstrument =
      UniversalInstrumentDefinition.classicalGuitar;
  UniversalInstrumentDefinition get activeInstrument => _activeInstrument;

  /// Perfil completo de personalización física, tímbrica y microtonal.
  late InstrumentCustomizationProfile _activeCustomization =
      InstrumentCustomizationProfile.defaultFor(_activeInstrument);
  InstrumentCustomizationProfile get customization => _activeCustomization;

  /// Actualiza la personalización del instrumento y propaga calibración atómica al bus.
  void updateCustomization(InstrumentCustomizationProfile profile) {
    _activeCustomization = profile;
    _activeInstrument = profile.instrument;

    // Propagar evento de calibración a todos los módulos suscritos
    signalBus.broadcastGlobalSignal(
      TuningCalibrationEvent(
        eventId: 'tune_calib_${DateTime.now().microsecondsSinceEpoch}',
        sourcePort: const PortId(
          id: 'tuning_out',
          displayName: 'Afinación Maestra',
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

  /// Estado de transporte global (Consola Multitarea)
  bool _isSessionRunning = false;
  bool get isSessionRunning => _isSessionRunning;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  ModularRackViewModel() {
    _initializeDefaultRack();
  }

  /// Configura el rack inicial por defecto con herramientas clave conectadas.
  void _initializeDefaultRack() {
    final tuner = RackModuleEntity.standard(RackModuleType.strobeTuner, 0);
    final metronome = RackModuleEntity.standard(RackModuleType.metronome, 1);
    final score = RackModuleEntity.standard(RackModuleType.scoreNotation, 2);
    final recorder = RackModuleEntity.standard(RackModuleType.practiceRecorder, 3);

    _activeModules.addAll([tuner, metronome, score, recorder]);

    // Registrar nodos atómicos interoperables
    _registerNodeForModule(tuner, {SignalType.audioPcm, SignalType.tuningCalibration});
    _registerNodeForModule(metronome, {SignalType.transportControl});
    _registerNodeForModule(score, {SignalType.temporalClock, SignalType.pitchEvents});
    _registerNodeForModule(recorder, {SignalType.audioPcm, SignalType.temporalClock, SignalType.transportControl});

    // Establecer conexiones iniciales inteligentes
    // 1. Reloj de metrónomo -> Pentagrama en vivo
    final metroClock = metronome.outputPorts.firstWhere(
      (p) => p.signalType == SignalType.temporalClock,
    );
    final scoreClock = score.inputPorts.firstWhere(
      (p) => p.signalType == SignalType.temporalClock,
    );
    signalBus.addConnection(
      ModuleConnection.pointToPoint(source: metroClock, destination: scoreClock),
    );

    // 2. Pitch del afinador -> Pentagrama (Tocar y transcribir)
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

  /// Cambia el instrumento universal activo y actualiza perfiles tímbricos/visuales.
  void selectInstrument(UniversalInstrumentDefinition instrument) {
    _activeInstrument = instrument;
    _activeCustomization = InstrumentCustomizationProfile.defaultFor(instrument);
    updateCustomization(_activeCustomization);
  }

  /// Agrega un nuevo módulo al rack e inicializa su nodo de interoperabilidad.
  void addModule(RackModuleType type) {
    final newOrder = _activeModules.length;
    final module = RackModuleEntity.standard(type, newOrder);
    _activeModules.add(module);

    // Mapear tipos de señal aceptados según el tipo de módulo
    final accepted = <SignalType>{};
    switch (type) {
      case RackModuleType.strobeTuner:
      case RackModuleType.spectrogram:
        accepted.addAll([SignalType.audioPcm, SignalType.tuningCalibration]);
        break;
      case RackModuleType.scoreNotation:
        accepted.addAll([SignalType.temporalClock, SignalType.pitchEvents]);
        break;
      case RackModuleType.practiceRecorder:
        accepted.addAll([SignalType.audioPcm, SignalType.temporalClock, SignalType.transportControl]);
        break;
      case RackModuleType.vocalAutoTune:
        accepted.addAll([SignalType.audioPcm, SignalType.pitchEvents, SignalType.tuningCalibration]);
        break;
      case RackModuleType.harmonicDrone:
        accepted.addAll([SignalType.tuningCalibration, SignalType.pitchEvents]);
        break;
      case RackModuleType.chordAnalyzer:
        accepted.addAll([SignalType.audioPcm, SignalType.pitchEvents]);
        break;
      case RackModuleType.guidedLessons:
        accepted.addAll([SignalType.temporalClock, SignalType.pitchEvents]);
        break;
      case RackModuleType.metronome:
        accepted.add(SignalType.transportControl);
        break;
    }

    _registerNodeForModule(module, accepted);
    notifyListeners();
  }

  /// Elimina un módulo del rack y desregistra sus puertos y nodo del SignalBus.
  void removeModule(String moduleId) {
    final index = _activeModules.indexWhere((m) => m.moduleId == moduleId);
    if (index != -1) {
      signalBus.unregisterNode(moduleId);
      _activeModules.removeAt(index);
      _reindexModules();
      notifyListeners();
    }
  }

  /// Reordena los módulos tras un gesto Drag & Drop del usuario.
  void reorderModules(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _activeModules.removeAt(oldIndex);
    _activeModules.insert(newIndex, item);
    _reindexModules();
    notifyListeners();
  }

  /// Alterna entre vista compacta y expandida de un módulo.
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

  /// Alterna el encendido / apagado de un módulo.
  void toggleModulePower(String moduleId) {
    final index = _activeModules.indexWhere((m) => m.moduleId == moduleId);
    if (index != -1) {
      final mod = _activeModules[index];
      _activeModules[index] = mod.copyWith(isPoweredOn: !mod.isPoweredOn);
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

  /// Desconecta una conexión por su ID.
  void disconnect(String connectionId) {
    signalBus.removeConnection(connectionId);
    notifyListeners();
  }

  // --- CONTROLES DE LA CONSOLA MULTITAREA ---

  /// Inicia o detiene la sesión multitarea sincronizada de todos los módulos.
  void toggleMasterSession() {
    _isSessionRunning = !_isSessionRunning;

    // Despachar comando de transporte atómico
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

  /// Inicia o detiene la grabación de la sesión maestra.
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

  /// Carga un preset de sesión predeterminado.
  void loadPreset(String presetName) {
    _activeModules.clear();
    signalBus.dispose();

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
        // Conexión automática afinador -> partitura
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
        // Conexión automática autotune -> grabador
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

  void _reindexModules() {
    for (int i = 0; i < _activeModules.length; i++) {
      _activeModules[i] = _activeModules[i].copyWith(orderIndex: i);
    }
  }

  @override
  void dispose() {
    signalBus.dispose();
    super.dispose();
  }
}
