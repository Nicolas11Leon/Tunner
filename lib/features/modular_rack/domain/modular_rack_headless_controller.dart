import 'dart:convert';

import 'atomic_signal_event.dart';
import 'interoperable_module_node.dart';
import 'module_connection.dart';
import 'port_id.dart';
import 'port_permission_broker.dart';
import 'rack_module_entity.dart';
import 'signal_bus.dart';
import 'signal_type.dart';
import 'synergy_policy_engine.dart';

/// Nodo modular atomico Pure Dart para ejecucion headless del Rack de Estudio.
/// No depende de Flutter ni de [ModularRackViewModel].
class HeadlessRackNode implements InteroperableModuleNode {
  @override
  final String nodeId;

  @override
  final RackModuleType moduleType;

  final RackModuleEntity? Function(String moduleId) _moduleResolver;
  final Set<SignalType> _acceptedTypes;
  final void Function(HeadlessRackNode node, AtomicSignalEvent event)? _onSignal;

  /// Telemetria verificable del ultimo evento recibido.
  AtomicSignalEvent? lastReceivedEvent;
  int processedEventsCount = 0;

  HeadlessRackNode({
    required this.nodeId,
    required this.moduleType,
    required RackModuleEntity? Function(String moduleId) moduleResolver,
    required Set<SignalType> acceptedTypes,
    void Function(HeadlessRackNode node, AtomicSignalEvent event)? onSignal,
  })  : _moduleResolver = moduleResolver,
        _acceptedTypes = acceptedTypes,
        _onSignal = onSignal;

  RackModuleEntity _resolveModule() {
    return _moduleResolver(nodeId) ??
        RackModuleEntity.standard(moduleType, -1, customId: nodeId);
  }

  @override
  bool get isProcessingActive => _resolveModule().isPoweredOn;

  @override
  List<PortId> get declaredInputPorts => _resolveModule().inputPorts;

  @override
  List<PortId> get declaredOutputPorts => _resolveModule().outputPorts;

  @override
  Set<SignalType> get acceptedSignalTypes => _acceptedTypes;

  @override
  void onReceiveAtomicSignal(AtomicSignalEvent event) {
    if (!isProcessingActive) return;
    lastReceivedEvent = event;
    processedEventsCount++;
    _onSignal?.call(this, event);
  }

  Map<String, dynamic> toTelemetryJson() => {
        'nodeId': nodeId,
        'moduleType': moduleType.code,
        'isProcessingActive': isProcessingActive,
        'processedEventsCount': processedEventsCount,
        'lastSignalType': lastReceivedEvent?.signalType.code,
      };
}

/// Controlador Pure Dart headless del Rack Modular de Estudio.
///
/// Gestiona el ciclo de vida de modulos, nodos de interoperabilidad, cables en
/// [SignalBus], presets de sesion y serializacion JSON de la topologia completa
/// sin depender de `ChangeNotifier`, Flutter ni `TunerViewModel`.
class ModularRackHeadlessController {
  final SignalBus signalBus;
  final PortPermissionBroker permissionBroker;
  final List<RackModuleEntity> _activeModules = [];
  final Map<String, HeadlessRackNode> _nodes = {};
  final void Function(HeadlessRackNode node, AtomicSignalEvent event)? _onNodeSignal;

  bool _isSessionRunning = false;
  bool _isRecording = false;

  ModularRackHeadlessController({
    SignalBus? signalBus,
    this.permissionBroker = const PortPermissionBroker(),
    bool initializeDefaultRack = false,
    void Function(HeadlessRackNode node, AtomicSignalEvent event)? onNodeSignal,
  })  : signalBus = signalBus ?? SignalBus(permissionBroker: permissionBroker),
        _onNodeSignal = onNodeSignal {
    if (initializeDefaultRack) {
      loadPreset('default');
    }
  }

  List<RackModuleEntity> get activeModules => List.unmodifiable(_activeModules);
  List<ModuleConnection> get activeConnections => signalBus.activeConnections;
  Map<String, HeadlessRackNode> get nodes => Map.unmodifiable(_nodes);
  bool get isSessionRunning => _isSessionRunning;
  bool get isRecording => _isRecording;

  /// Devuelve el conjunto canonico de tipos de senal aceptados para cada [RackModuleType].
  static Set<SignalType> acceptedSignalsForType(RackModuleType type) {
    switch (type) {
      case RackModuleType.strobeTuner:
      case RackModuleType.spectrogram:
        return {SignalType.audioPcm, SignalType.tuningCalibration};
      case RackModuleType.scoreNotation:
        return {
          SignalType.temporalClock,
          SignalType.pitchEvents,
          SignalType.transportControl,
        };
      case RackModuleType.practiceRecorder:
        return {
          SignalType.audioPcm,
          SignalType.temporalClock,
          SignalType.transportControl,
        };
      case RackModuleType.vocalAutoTune:
        return {
          SignalType.audioPcm,
          SignalType.pitchEvents,
          SignalType.tuningCalibration,
        };
      case RackModuleType.harmonicDrone:
        return {
          SignalType.tuningCalibration,
          SignalType.pitchEvents,
          SignalType.transportControl,
        };
      case RackModuleType.chordAnalyzer:
        return {SignalType.audioPcm, SignalType.pitchEvents};
      case RackModuleType.guidedLessons:
        return {SignalType.temporalClock, SignalType.pitchEvents};
      case RackModuleType.earTrainer:
        return {
          SignalType.pitchEvents,
          SignalType.audioPcm,
          SignalType.tuningCalibration,
          SignalType.transportControl,
        };
      case RackModuleType.metronome:
        return {SignalType.transportControl};
      case RackModuleType.djConsole:
        return {
          SignalType.audioPcm,
          SignalType.temporalClock,
          SignalType.transportControl,
        };
      case RackModuleType.stemMixer:
        return {SignalType.audioPcm, SignalType.transportControl};
    }
  }

  /// Agrega un nuevo modulo al rack y registra su nodo y puertos en [signalBus].
  RackModuleEntity addModule(
    RackModuleType type, {
    String? customId,
    String? title,
    bool isPoweredOn = true,
  }) {
    final int orderIndex = _activeModules.length;
    final String resolvedId = customId ?? _generateUniqueModuleId(type, orderIndex);
    final standard = RackModuleEntity.standard(type, orderIndex, customId: resolvedId);
    final module = standard.copyWith(
      title: title,
      isPoweredOn: isPoweredOn,
    );

    _activeModules.add(module);
    _registerNodeForModule(module);
    return module;
  }

  /// Elimina un modulo por su ID y desregistra su nodo y conexiones del bus.
  bool removeModule(String moduleId) {
    final index = _activeModules.indexWhere((m) => m.moduleId == moduleId);
    if (index == -1) return false;

    signalBus.unregisterNode(moduleId);
    _nodes.remove(moduleId);
    _activeModules.removeAt(index);
    _reindexModules();
    return true;
  }

  /// Busca un modulo activo por su identificador.
  RackModuleEntity? findModule(String moduleId) {
    for (final mod in _activeModules) {
      if (mod.moduleId == moduleId) return mod;
    }
    return null;
  }

  /// Reordena los modulos montados en el rack.
  void reorderModules(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _activeModules.length) return;
    int target = newIndex;
    if (oldIndex < target) {
      target -= 1;
    }
    target = target.clamp(0, _activeModules.length - 1);
    final item = _activeModules.removeAt(oldIndex);
    _activeModules.insert(target, item);
    _reindexModules();
  }

  /// Enciende o apaga un modulo especifico.
  RackModuleEntity? setModulePower(String moduleId, bool isPoweredOn) {
    final index = _activeModules.indexWhere((m) => m.moduleId == moduleId);
    if (index == -1) return null;
    final updated = _activeModules[index].copyWith(isPoweredOn: isPoweredOn);
    _activeModules[index] = updated;
    return updated;
  }

  /// Alterna el estado de encendido de un modulo.
  RackModuleEntity? toggleModulePower(String moduleId) {
    final mod = findModule(moduleId);
    if (mod == null) return null;
    return setModulePower(moduleId, !mod.isPoweredOn);
  }

  /// Renombra un modulo existente.
  RackModuleEntity? renameModule(String moduleId, String newTitle) {
    final index = _activeModules.indexWhere((m) => m.moduleId == moduleId);
    if (index == -1) return null;
    final updated = _activeModules[index].copyWith(title: newTitle);
    _activeModules[index] = updated;
    return updated;
  }

  /// Valida politicas de seguridad y sinergia para un posible enlace entre dos puertos.
  SynergyValidationResult validatePatch(PortId source, PortId destination) {
    if (!permissionBroker.canAuthorizeConnection(source, destination)) {
      return SynergyValidationResult.rejected(
        rejectionReason:
            'Conexion rechazada por PortPermissionBroker: ${source.id} -> ${destination.id}',
      );
    }
    return SynergyPolicyEngine.validateConnection(
      sourcePort: source,
      destinationPort: destination,
    );
  }

  /// Conecta dos puertos (o crea una conexion broadcast si [destination] es nulo).
  ModuleConnection connectPorts(
    PortId source,
    PortId? destination, {
    double gain = 1.0,
    bool isMuted = false,
  }) {
    final connection = destination != null
        ? ModuleConnection.pointToPoint(
            source: source,
            destination: destination,
            gain: gain,
            isMuted: isMuted,
          )
        : ModuleConnection.broadcast(
            source: source,
            gain: gain,
            isMuted: isMuted,
          );
    signalBus.addConnection(connection);
    return connection;
  }

  /// Conecta puertos resolviendolos por IDs textuales (ideal para invocacion CLI/MCP).
  ModuleConnection connectByPortIds({
    required String sourceModuleId,
    required String sourcePortId,
    String? destinationModuleId,
    String? destinationPortId,
    double gain = 1.0,
    bool isMuted = false,
  }) {
    final source = signalBus.findPort(sourceModuleId, sourcePortId);
    if (source == null) {
      throw ArgumentError(
        'Puerto de origen no encontrado: $sourceModuleId.$sourcePortId',
      );
    }

    PortId? dest;
    if (destinationModuleId != null && destinationPortId != null) {
      dest = signalBus.findPort(destinationModuleId, destinationPortId);
      if (dest == null) {
        throw ArgumentError(
          'Puerto de destino no encontrado: $destinationModuleId.$destinationPortId',
        );
      }
    }

    return connectPorts(source, dest, gain: gain, isMuted: isMuted);
  }

  /// Modifica ganancia, silencio o habilitacion de un cable existente en [signalBus].
  ModuleConnection? updateConnection(
    String connectionId, {
    double? gain,
    bool? isMuted,
    bool? isEnabled,
  }) {
    return signalBus.updateConnection(
      connectionId,
      gain: gain,
      isMuted: isMuted,
      isEnabled: isEnabled,
    );
  }

  /// Desconecta y elimina un cable por su identificador.
  void disconnect(String connectionId) {
    signalBus.removeConnection(connectionId);
  }

  /// Emite un evento atomico a traves del bus.
  void emitAtomicEvent(AtomicSignalEvent event) {
    signalBus.emitAtomicEvent(event);
  }

  /// Emite una senal global a todos los nodos activos compatibles.
  void broadcastGlobalSignal(AtomicSignalEvent event) {
    signalBus.broadcastGlobalSignal(event);
  }

  /// Inicia o pausa la sesion maestra emitiendo el comando de transporte por el bus.
  void setSessionRunning(bool running) {
    _isSessionRunning = running;
    if (!running) _isRecording = false;
    _broadcastTransport(running ? TransportCommand.play : TransportCommand.pause);
  }

  /// Inicia o detiene la grabacion maestra.
  void setRecording(bool recording) {
    _isRecording = recording;
    if (recording) _isSessionRunning = true;
    _broadcastTransport(recording ? TransportCommand.record : TransportCommand.stop);
  }

  /// Carga un preset canonico limpiando modulos y rutas previas.
  void loadPreset(String presetName) {
    _activeModules.clear();
    _nodes.clear();
    signalBus.clearRoutes();

    switch (presetName) {
      case 'calentamiento':
        addModule(RackModuleType.strobeTuner);
        addModule(RackModuleType.harmonicDrone);
        addModule(RackModuleType.metronome);
        break;

      case 'transcripcion_partitura':
        final tuner = addModule(RackModuleType.strobeTuner);
        final score = addModule(RackModuleType.scoreNotation);
        addModule(RackModuleType.metronome);
        connectPorts(
          tuner.outputPorts.firstWhere((p) => p.signalType == SignalType.pitchEvents),
          score.inputPorts.firstWhere((p) => p.signalType == SignalType.pitchEvents),
        );
        break;

      case 'produccion_vocal':
        final tune = addModule(RackModuleType.vocalAutoTune);
        final rec = addModule(RackModuleType.practiceRecorder);
        addModule(RackModuleType.spectrogram);
        connectPorts(
          tune.outputPorts.firstWhere((p) => p.signalType == SignalType.audioPcm),
          rec.inputPorts.firstWhere((p) => p.signalType == SignalType.audioPcm),
        );
        break;

      case 'dj_studio':
        final dj = addModule(RackModuleType.djConsole);
        final mixer = addModule(RackModuleType.stemMixer);
        final spec = addModule(RackModuleType.spectrogram);
        connectPorts(
          dj.outputPorts.firstWhere((p) => p.signalType == SignalType.audioPcm),
          mixer.inputPorts.firstWhere((p) => p.signalType == SignalType.audioPcm),
        );
        connectPorts(
          mixer.outputPorts.firstWhere((p) => p.signalType == SignalType.audioPcm),
          spec.inputPorts.firstWhere((p) => p.signalType == SignalType.audioPcm),
        );
        break;

      default:
        addModule(RackModuleType.strobeTuner);
        addModule(RackModuleType.metronome);
        addModule(RackModuleType.scoreNotation);
        break;
    }
  }

  /// Serializa la topologia completa del rack (modulos, conexiones y estado de sesion).
  Map<String, dynamic> toJson() => {
        'isSessionRunning': _isSessionRunning,
        'isRecording': _isRecording,
        'modules': _activeModules.map((m) => m.toJson()).toList(growable: false),
        'signalBus': signalBus.toJson(),
      };

  String toJsonString() => jsonEncode(toJson());

  /// Restaura la topologia completa de modulos y conexiones desde un mapa JSON.
  void loadTopologyFromJson(Map<String, dynamic> json) {
    _activeModules.clear();
    _nodes.clear();
    signalBus.clearRoutes();

    _isSessionRunning = json['isSessionRunning'] as bool? ?? false;
    _isRecording = json['isRecording'] as bool? ?? false;

    final rawModules = json['modules'] as List<dynamic>? ?? const [];
    for (final item in rawModules) {
      if (item is Map<String, dynamic>) {
        final mod = RackModuleEntity.fromJson(item);
        _activeModules.add(mod);
        _registerNodeForModule(mod);
      }
    }
    _reindexModules();

    final busJson = json['signalBus'];
    if (busJson is Map<String, dynamic>) {
      signalBus.restoreConnectionsFromJson(busJson);
    } else if (json['connections'] is List<dynamic>) {
      signalBus.restoreConnectionsFromJson({'connections': json['connections']});
    }
  }

  void loadTopologyFromJsonString(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is Map<String, dynamic>) {
      loadTopologyFromJson(decoded);
    }
  }

  void dispose() {
    _activeModules.clear();
    _nodes.clear();
    signalBus.dispose();
  }

  void _registerNodeForModule(RackModuleEntity module) {
    final node = HeadlessRackNode(
      nodeId: module.moduleId,
      moduleType: module.moduleType,
      moduleResolver: findModule,
      acceptedTypes: acceptedSignalsForType(module.moduleType),
      onSignal: _onNodeSignal,
    );
    _nodes[module.moduleId] = node;
    signalBus.registerNode(node);
  }

  void _reindexModules() {
    for (int i = 0; i < _activeModules.length; i++) {
      _activeModules[i] = _activeModules[i].copyWith(orderIndex: i);
    }
  }

  String _generateUniqueModuleId(RackModuleType type, int seedIndex) {
    int idx = seedIndex;
    while (true) {
      final candidate = 'mod_${type.code}_$idx';
      if (!_activeModules.any((m) => m.moduleId == candidate)) {
        return candidate;
      }
      idx++;
    }
  }

  void _broadcastTransport(TransportCommand command) {
    signalBus.broadcastGlobalSignal(
      TransportControlEvent(
        eventId: 'headless_trans_${DateTime.now().microsecondsSinceEpoch}',
        sourcePort: const PortId(
          id: 'transport_out',
          displayName: 'Transporte Global Headless',
          ownerModuleId: 'master_console',
          signalType: SignalType.transportControl,
          direction: PortDirection.output,
        ),
        timestampMicros: DateTime.now().microsecondsSinceEpoch,
        command: command,
      ),
    );
  }
}
