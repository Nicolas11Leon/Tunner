import 'package:flutter/foundation.dart';
import '../domain/signal_type.dart';
import '../domain/port_id.dart';
import '../domain/module_connection.dart';
import '../domain/signal_bus.dart';
import '../domain/rack_module_entity.dart';
import '../../instrument/domain/universal_instrument_definition.dart';

/// ViewModel principal del Rack de Estudio Modular y la Consola Multitarea.
/// Gobierna el ciclo de vida de los módulos, las conexiones en el SignalBus,
/// el transporte global sincronizado y la emulación del instrumento activo.
class ModularRackViewModel extends ChangeNotifier {
  final SignalBus signalBus = SignalBus();

  /// Módulos actualmente montados en el rack de trabajo.
  final List<RackModuleEntity> _activeModules = [];
  List<RackModuleEntity> get activeModules => List.unmodifiable(_activeModules);

  /// Instrumento musical actualmente seleccionado para la sesión.
  UniversalInstrumentDefinition _activeInstrument = UniversalInstrumentDefinition.classicalGuitar;
  UniversalInstrumentDefinition get activeInstrument => _activeInstrument;

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

    // Establecer conexiones iniciales inteligentes
    // 1. Reloj de metrónomo -> Pentagrama en vivo
    final metroClock = metronome.outputPorts.firstWhere((p) => p.signalType == SignalType.temporalClock);
    final scoreClock = score.inputPorts.firstWhere((p) => p.signalType == SignalType.temporalClock);
    signalBus.addConnection(ModuleConnection.pointToPoint(source: metroClock, destination: scoreClock));

    // 2. Pitch del afinador -> Pentagrama (Tocar y transcribir)
    final tunerPitch = tuner.outputPorts.firstWhere((p) => p.signalType == SignalType.pitchEvents);
    final scorePitch = score.inputPorts.firstWhere((p) => p.signalType == SignalType.pitchEvents);
    signalBus.addConnection(ModuleConnection.pointToPoint(source: tunerPitch, destination: scorePitch));
  }

  /// Cambia el instrumento universal activo y actualiza perfiles tímbricos/visuales.
  void selectInstrument(UniversalInstrumentDefinition instrument) {
    _activeInstrument = instrument;
    notifyListeners();
  }

  /// Agrega un nuevo módulo al rack.
  void addModule(RackModuleType type) {
    final newOrder = _activeModules.length;
    final module = RackModuleEntity.standard(type, newOrder);
    _activeModules.add(module);
    notifyListeners();
  }

  /// Elimina un módulo del rack y desregistra sus puertos del SignalBus.
  void removeModule(String moduleId) {
    final index = _activeModules.indexWhere((m) => m.moduleId == moduleId);
    if (index != -1) {
      final module = _activeModules[index];
      for (final port in [...module.inputPorts, ...module.outputPorts]) {
        signalBus.unregisterPort(port);
      }
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
      signalBus.addConnection(ModuleConnection.pointToPoint(source: source, destination: destination));
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
    notifyListeners();
  }

  /// Inicia o detiene la grabación de la sesión maestra.
  void toggleMasterRecording() {
    if (!_isSessionRunning && !_isRecording) {
      _isSessionRunning = true;
    }
    _isRecording = !_isRecording;
    notifyListeners();
  }

  /// Detiene todo el transporte global.
  void stopMasterSession() {
    _isSessionRunning = false;
    _isRecording = false;
    notifyListeners();
  }

  /// Carga un preset de sesión predeterminado.
  void loadPreset(String presetName) {
    _activeModules.clear();
    signalBus.dispose();

    switch (presetName) {
      case 'calentamiento':
        _activeModules.add(RackModuleEntity.standard(RackModuleType.strobeTuner, 0));
        _activeModules.add(RackModuleEntity.standard(RackModuleType.harmonicDrone, 1));
        _activeModules.add(RackModuleEntity.standard(RackModuleType.metronome, 2));
        break;

      case 'transcripcion_partitura':
        _activeModules.add(RackModuleEntity.standard(RackModuleType.strobeTuner, 0));
        _activeModules.add(RackModuleEntity.standard(RackModuleType.scoreNotation, 1));
        _activeModules.add(RackModuleEntity.standard(RackModuleType.metronome, 2));
        // Conexión automática mic -> partitura
        final tuner = _activeModules[0];
        final score = _activeModules[1];
        signalBus.addConnection(ModuleConnection.pointToPoint(
          source: tuner.outputPorts.first,
          destination: score.inputPorts.firstWhere((p) => p.signalType == SignalType.pitchEvents),
        ));
        break;

      case 'produccion_vocal':
        _activeModules.add(RackModuleEntity.standard(RackModuleType.vocalAutoTune, 0));
        _activeModules.add(RackModuleEntity.standard(RackModuleType.practiceRecorder, 1));
        _activeModules.add(RackModuleEntity.standard(RackModuleType.spectrogram, 2));
        // Conexión automática autotune -> grabador
        final tune = _activeModules[0];
        final rec = _activeModules[1];
        signalBus.addConnection(ModuleConnection.pointToPoint(
          source: tune.outputPorts.first,
          destination: rec.inputPorts.first,
        ));
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
