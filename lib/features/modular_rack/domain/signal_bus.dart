import 'dart:async';
import 'port_id.dart';
import 'module_connection.dart';

/// Bus de señales en memoria local de Clean Architecture.
/// Permite el despacho determinista de eventos de audio, pitch, notas y reloj
/// entre módulos del rack sin acoplamientos y con soporte para hot-swapping.
class SignalBus {
  final Map<String, StreamController<dynamic>> _portControllers = {};
  final List<ModuleConnection> _connections = [];

  /// Lista de todas las conexiones activas registradas en el bus.
  List<ModuleConnection> get activeConnections => List.unmodifiable(_connections);

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
    _connections.removeWhere((c) =>
        c.sourcePort == port || c.destinationPort == port);
    _portControllers[key]?.close();
    _portControllers.remove(key);
  }

  /// Conecta dos puertos o crea una conexión broadcast.
  void addConnection(ModuleConnection connection) {
    // Si ya existe la misma conexión, no duplicar
    if (_connections.any((c) => c.connectionId == connection.connectionId)) {
      return;
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
            if (entry.key != sourceKey) {
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

  /// Se suscribe al flujo de datos que ingresa a un puerto receptor (o que sale de un emisor).
  Stream<T> subscribe<T>(PortId port) {
    final key = _generatePortKey(port);
    registerPort(port);
    return _portControllers[key]!.stream.where((event) => event is T).cast<T>();
  }

  /// Limpia todas las conexiones y cierra los streams del bus.
  void dispose() {
    _connections.clear();
    for (final controller in _portControllers.values) {
      controller.close();
    }
    _portControllers.clear();
  }

  static String _generatePortKey(PortId port) =>
      '${port.ownerModuleId}:${port.id}';
}
