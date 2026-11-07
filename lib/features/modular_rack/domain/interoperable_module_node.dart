import 'atomic_signal_event.dart';
import 'port_id.dart';
import 'rack_module_entity.dart';
import 'signal_type.dart';

/// Contrato formal que debe implementar cualquier módulo del rack para participar
/// en la red de interoperabilidad atómica sin acoplarse con otros módulos.
abstract interface class InteroperableModuleNode {
  /// Identificador único del módulo en el rack.
  String get nodeId;

  /// Tipo de módulo.
  RackModuleType get moduleType;

  /// Indica si el módulo se encuentra activo para procesar señales.
  bool get isProcessingActive;

  /// Puertos de entrada declarados por este módulo.
  List<PortId> get declaredInputPorts;

  /// Puertos de salida declarados por este módulo.
  List<PortId> get declaredOutputPorts;

  /// Procesa una señal atómica entrante dirigida a uno de sus puertos o broadcast.
  void onReceiveAtomicSignal(AtomicSignalEvent event);

  /// Tipos de señales compatibles que este módulo es capaz de consumir.
  Set<SignalType> get acceptedSignalTypes;
}
