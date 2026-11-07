import 'dart:async';
import 'atomic_signal_event.dart';
import 'interoperable_module_node.dart';
import 'module_connection.dart';
import 'port_id.dart';

/// Bus de señales en memoria local de Clean Architecture.
/// Permite el despacho determinista de eventos de audio, pitch, notas y reloj
/// entre módulos del rack sin acoplamientos y con soporte para hot-swapping e interoperabilidad atómica.
class SignalBus {
  final Map<String, StreamController<dynamic>> _portControllers = {};
  final List<ModuleConnection> _connections = [];
  final Map<String, InteroperableModuleNode> _registeredNodes = {};
  final Map<String, List<StreamSubscription>> _nodeSubscriptions = {};

  /// Lista de todas las conexiones activas registradas en el bus.
  List<ModuleConnection> get activeConnections => List.unmodifiable(_connections);

  /// Nodos modulares atómicos registrados actualmente en el bus.
  Map<String, InteroperableModuleNode> get registeredNodes =>
      Map.unmodifiable(_registeredNodes);

  /// Registra un nodo modular atómico y enlaza sus puertos automáticamente.
  void registerNode(InteroperableModuleNode node) {
    _registeredNodes[node.nodeId] = node;

    // Registrar puertos declarados
    for (final port in node.declaredInputPorts) {
      registerPort(port);
    }
    for (final port in node.declaredOutputPorts) {
      registerPort(port);
    }

    // Suscribir el nodo a sus puertos de entrada declarados
    final subs = <StreamSubscription>[];
    for (final inPort in node.declaredInputPorts) {
      final sub = subscribe<AtomicSignalEvent>(inPort).listen((event) {
        if (node.isProcessingActive && node.acceptedSignalTypes.contains(event.signalType)) {
          node.onReceiveAtomicSignal(event);
        }
      });
      subs.add(sub);
    }
    _nodeSubscriptions[node.nodeId] = subs;
  }

  /// Desregistra un nodo modular y cancela sus suscripciones.
  void unregisterNode(String nodeId) {
    final subs = _nodeSubscriptions.remove(nodeId);
    if (subs != null) {
      for (final sub in subs) {
        sub.cancel();
      }
    }

    final node = _registeredNodes.remove(nodeId);
    if (node != null) {
      for (final inPort in node.declaredInputPorts) {
        unregisterPort(inPort);
      }
      for (final outPort in node.declaredOutputPorts) {
        unregisterPort(outPort);
      }
    }
  }

  /// Registra un puerto en el bus y crea su stream subyacente.
  void registerPort(PortId port) {
    final key = _generatePortKey(port);
    _portControllers.putIfAbsent(
      key,
      () => StreamController<dynamic>.broadcast(),
    );
  }

  /// Desregistra un puerto y elimina todas las conexiones asociadas.
  void unregisterPort(PortId port) {
    final key = _generatePortKey(port);
    _connections.removeWhere(
      (c) => c.sourcePort == port || c.destinationPort == port,
    );
    _portControllers[key]?.close();
    _portControllers.remove(key);
  }

  /// Conecta dos puertos o crea una conexión broadcast verificando compatibilidad de tipos.
  void addConnection(ModuleConnection connection) {
    // Si ya existe la misma conexión, no duplicar
    if (_connections.any((c) => c.connectionId == connection.connectionId)) {
      return;
    }

    // Validar compatibilidad de señales si es punto a punto
    if (connection.destinationPort != null &&
        connection.sourcePort.signalType != connection.destinationPort!.signalType) {
      throw ArgumentError(
        'Incompatibilidad de señal: No se puede conectar ${connection.sourcePort.signalType.displayName} con ${connection.destinationPort!.signalType.displayName}',
      );
    }

    registerPort(connection.sourcePort);
    if (connection.destinationPort != null) {
      registerPort(connection.destinationPort!);
    }

    _connections.add(connection);
  }

  /// Elimina una conexión por su identificador.
  void removeConnection(String connectionId) {
    _connections.removeWhere((c) => c.connectionId == connectionId);
  }

  /// Despacha un evento de datos desde un puerto de salida hacia los receptores conectados.
  void emit(PortId sourcePort, dynamic data) {
    if (sourcePort.direction != PortDirection.output) {
      throw ArgumentError('Solo los puertos de salida pueden emitir datos.');
    }

    // 1. Emitir en el propio stream del puerto de origen
    final sourceKey = _generatePortKey(sourcePort);
    _portControllers[sourceKey]?.add(data);

    // 2. Enrutar hacia los destinos configurados
    for (final conn in _connections) {
      if (!conn.isEnabled) continue;

      if (conn.sourcePort == sourcePort) {
        if (conn.scope == ConnectionScope.broadcast) {
          // Difusión global a todos los puertos de entrada compatibles del mismo SignalType
          for (final entry in _portControllers.entries) {
            if (entry.key != sourceKey && entry.key.contains(sourcePort.signalType.code)) {
              entry.value.add(data);
            }
          }
        } else if (conn.destinationPort != null) {
          // Despacho punto a punto exclusivo
          final destKey = _generatePortKey(conn.destinationPort!);
          _portControllers[destKey]?.add(data);
        }
      }
    }
  }

  /// Despacha un evento atómico directamente a través del bus y de sus nodos suscritos.
  void emitAtomicEvent(AtomicSignalEvent event) {
    emit(event.sourcePort, event);
  }

  /// Transmite una señal global a todos los nodos que acepten este tipo de señal.
  void broadcastGlobalSignal(AtomicSignalEvent event) {
    for (final node in _registeredNodes.values) {
      if (node.isProcessingActive && node.acceptedSignalTypes.contains(event.signalType)) {
        node.onReceiveAtomicSignal(event);
      }
    }
  }

  /// Se suscribe al flujo de datos que ingresa a un puerto receptor (o que sale de un emisor).
  Stream<T> subscribe<T>(PortId port) {
    final key = _generatePortKey(port);
    registerPort(port);
    return _portControllers[key]!.stream.where((event) => event is T).cast<T>();
  }

  /// Limpia todas las conexiones y cierra los streams del bus.
  void dispose() {
    for (final subs in _nodeSubscriptions.values) {
      for (final sub in subs) {
        sub.cancel();
      }
    }
    _nodeSubscriptions.clear();
    _registeredNodes.clear();
    _connections.clear();
    for (final controller in _portControllers.values) {
      controller.close();
    }
    _portControllers.clear();
  }

  static String _generatePortKey(PortId port) =>
      '${port.ownerModuleId}_${port.id}_${port.signalType.code}';
}
