import 'dart:async';
import 'dart:math' as math;

import 'atomic_signal_event.dart';
import 'interoperable_module_node.dart';
import 'module_connection.dart';
import 'port_id.dart';
import 'port_permission_broker.dart';
import 'synergy_policy_engine.dart';

/// Bus de senales en memoria local de Clean Architecture.
/// Permite el despacho determinista de eventos de audio, pitch, notas y reloj
/// entre modulos del rack con validacion por [PortPermissionBroker] y
/// escalado de ganancia por conexion.
class SignalBus {
  final PortPermissionBroker _permissionBroker;
  final Map<String, StreamController<dynamic>> _portControllers = {};
  final Map<String, PortId> _registeredPorts = {};
  final List<ModuleConnection> _connections = [];
  final Map<String, InteroperableModuleNode> _registeredNodes = {};
  final Map<String, List<StreamSubscription>> _nodeSubscriptions = {};
  bool _isDisposed = false;

  SignalBus({
    PortPermissionBroker permissionBroker = const PortPermissionBroker(),
  }) : _permissionBroker = permissionBroker;

  /// Indica si el bus ha sido eliminado definitivamente mediante [dispose].
  bool get isDisposed => _isDisposed;

  /// Lista de todas las conexiones activas registradas en el bus.
  List<ModuleConnection> get activeConnections => List.unmodifiable(_connections);

  /// Nodos modulares atomicos registrados actualmente en el bus.
  Map<String, InteroperableModuleNode> get registeredNodes =>
      Map.unmodifiable(_registeredNodes);

  /// Registra un nodo modular atomico y enlaza sus puertos automaticamente.
  void registerNode(InteroperableModuleNode node) {
    if (_isDisposed) return;
    _registeredNodes[node.nodeId] = node;

    for (final port in node.declaredInputPorts) {
      registerPort(port);
    }
    for (final port in node.declaredOutputPorts) {
      registerPort(port);
    }

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
    if (_isDisposed) return;
    final key = _generatePortKey(port);
    _registeredPorts[key] = port;
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
    _registeredPorts.remove(key);
    _portControllers[key]?.close();
    _portControllers.remove(key);
  }

  /// Conecta dos puertos o crea una conexion broadcast verificando politicas de
  /// [PortPermissionBroker] y [SynergyPolicyEngine].
  void addConnection(ModuleConnection connection) {
    if (_isDisposed) return;
    if (_connections.any((c) => c.connectionId == connection.connectionId)) {
      return;
    }

    if (connection.destinationPort != null) {
      if (!_permissionBroker.canAuthorizeConnection(
        connection.sourcePort,
        connection.destinationPort!,
      )) {
        throw ArgumentError(
          'Conexion rechazada por PortPermissionBroker: ${connection.sourcePort.id} -> ${connection.destinationPort!.id}',
        );
      }

      final validation = SynergyPolicyEngine.validateConnection(
        sourcePort: connection.sourcePort,
        destinationPort: connection.destinationPort!,
      );
      if (!validation.isApproved) {
        throw ArgumentError(
          'Conexion rechazada por SynergyPolicyEngine: ${validation.rejectionReason}',
        );
      }

      if (_wouldCreateCycle(
        connection.sourcePort.ownerModuleId,
        connection.destinationPort!.ownerModuleId,
      )) {
        throw ArgumentError(
          'Conexion rechazada: forma un ciclo cerrado en el grafo DAG (${connection.sourcePort.ownerModuleId} -> ${connection.destinationPort!.ownerModuleId}).',
        );
      }
    } else if (connection.sourcePort.direction != PortDirection.output) {
      throw ArgumentError(
        'Solo puertos de salida pueden emitir en modo broadcast: ${connection.sourcePort.id}',
      );
    }

    registerPort(connection.sourcePort);
    if (connection.destinationPort != null) {
      registerPort(connection.destinationPort!);
    }

    _connections.add(connection);
  }

  /// Verifica mediante busqueda en anchura (BFS) si agregar la arista dirigida
  /// `sourceModuleId -> destinationModuleId` cierra un ciclo en el grafo de conexiones.
  bool _wouldCreateCycle(String sourceModuleId, String destinationModuleId) {
    if (sourceModuleId == destinationModuleId) return true;

    final adjacency = <String, Set<String>>{};
    for (final conn in _connections) {
      final dest = conn.destinationPort;
      if (dest == null) continue;
      adjacency
          .putIfAbsent(conn.sourcePort.ownerModuleId, () => <String>{})
          .add(dest.ownerModuleId);
    }

    final visited = <String>{destinationModuleId};
    final queue = <String>[destinationModuleId];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final neighbors = adjacency[current];
      if (neighbors == null) continue;

      for (final next in neighbors) {
        if (next == sourceModuleId) {
          return true;
        }
        if (visited.add(next)) {
          queue.add(next);
        }
      }
    }

    return false;
  }

  /// Actualiza la ganancia, estado de silencio o habilitacion de una conexion existente.
  /// Retorna la conexion actualizada, o `null` si [connectionId] no existe.
  ModuleConnection? updateConnection(
    String connectionId, {
    double? gain,
    bool? isMuted,
    bool? isEnabled,
  }) {
    if (_isDisposed) return null;
    final index = _connections.indexWhere((c) => c.connectionId == connectionId);
    if (index == -1) return null;

    final updated = _connections[index].copyWith(
      gain: gain,
      isMuted: isMuted,
      isEnabled: isEnabled,
    );
    _connections[index] = updated;
    return updated;
  }

  /// Busca un puerto registrado por ID de modulo propietario e ID de puerto.
  PortId? findPort(String ownerModuleId, String portId) {
    for (final port in _registeredPorts.values) {
      if (port.ownerModuleId == ownerModuleId && port.id == portId) {
        return port;
      }
    }
    return null;
  }

  /// Elimina una conexion por su identificador.
  void removeConnection(String connectionId) {
    _connections.removeWhere((c) => c.connectionId == connectionId);
  }

  /// Serializa la topologia de conexiones activas del bus en formato JSON canonico.
  Map<String, dynamic> toJson() => {
        'connections': _connections.map((c) => c.toJson()).toList(growable: false),
      };

  /// Reconstruye un [SignalBus] a partir de una topologia JSON serializada.
  factory SignalBus.fromJson(
    Map<String, dynamic> json, {
    PortPermissionBroker permissionBroker = const PortPermissionBroker(),
  }) {
    final bus = SignalBus(permissionBroker: permissionBroker);
    bus.restoreConnectionsFromJson(json);
    return bus;
  }

  /// Reemplaza las conexiones activas actuales restaurandolas desde [json].
  void restoreConnectionsFromJson(Map<String, dynamic> json) {
    if (_isDisposed) return;
    _connections.clear();
    final rawList = json['connections'] as List<dynamic>? ?? const [];
    for (final item in rawList) {
      if (item is Map<String, dynamic>) {
        final conn = ModuleConnection.fromJson(item);
        addConnection(conn);
      }
    }
  }

  /// Despacha un evento de datos desde un puerto de salida hacia los receptores
  /// conectados, validando cada enlace con [PortPermissionBroker.canAuthorizeConnection]
  /// y aplicando el escalado de ganancia [ModuleConnection.gain].
  void emit(PortId sourcePort, dynamic data) {
    if (_isDisposed) return;
    if (sourcePort.direction != PortDirection.output) {
      throw ArgumentError('Solo los puertos de salida pueden emitir datos.');
    }

    final sourceKey = _generatePortKey(sourcePort);
    _portControllers[sourceKey]?.add(data);

    final dispatchedKeys = <String>{sourceKey};

    for (final conn in _connections) {
      if (!conn.isEnabled || conn.isMuted) continue;

      if (conn.sourcePort == sourcePort) {
        if (conn.scope == ConnectionScope.broadcast) {
          for (final entry in _registeredPorts.entries) {
            final destPort = entry.value;
            if (!dispatchedKeys.contains(entry.key) &&
                _permissionBroker.canAuthorizeConnection(conn.sourcePort, destPort)) {
              dispatchedKeys.add(entry.key);
              final scaledData = _applyConnectionGain(data, conn.gain);
              _portControllers[entry.key]?.add(scaledData);
            }
          }
        } else if (conn.destinationPort != null) {
          if (!_permissionBroker.canAuthorizeConnection(
            conn.sourcePort,
            conn.destinationPort!,
          )) {
            continue;
          }
          final destKey = _generatePortKey(conn.destinationPort!);
          if (!dispatchedKeys.contains(destKey)) {
            dispatchedKeys.add(destKey);
            final scaledData = _applyConnectionGain(data, conn.gain);
            _portControllers[destKey]?.add(scaledData);
          }
        }
      }
    }
  }

  /// Escala buffers de audio PCM y eventos de amplitud segun el factor [rawGain]
  /// de la conexion activa, preservando el rango fisico normalizado.
  dynamic _applyConnectionGain(dynamic payload, double rawGain) {
    final double gain = rawGain.clamp(0.0, 2.0);
    if ((gain - 1.0).abs() <= 1e-6) {
      return payload;
    }

    if (payload is AudioPcmEvent) {
      final List<double> scaledSamples = List<double>.generate(
        payload.samples.length,
        (i) => (payload.samples[i] * gain).clamp(-1.0, 1.0),
        growable: false,
      );
      double scaledRms;
      if (scaledSamples.isNotEmpty) {
        double sumSquares = 0.0;
        for (final s in scaledSamples) {
          sumSquares += s * s;
        }
        scaledRms = math.sqrt(sumSquares / scaledSamples.length).clamp(0.0, 1.0);
      } else {
        scaledRms = (payload.rmsLevel * gain).clamp(0.0, 1.0);
      }
      return AudioPcmEvent(
        eventId: payload.eventId,
        sourcePort: payload.sourcePort,
        timestampMicros: payload.timestampMicros,
        samples: scaledSamples,
        sampleRate: payload.sampleRate,
        rmsLevel: scaledRms,
      );
    }

    if (payload is PitchDetectionEvent) {
      return PitchDetectionEvent(
        eventId: payload.eventId,
        sourcePort: payload.sourcePort,
        timestampMicros: payload.timestampMicros,
        frequencyHz: payload.frequencyHz,
        noteName: payload.noteName,
        centsOffset: payload.centsOffset,
        clarity: payload.clarity,
        amplitude: (payload.amplitude * gain).clamp(0.0, 2.0),
      );
    }

    if (payload is List<double>) {
      return payload.map((s) => (s * gain).clamp(-1.0, 1.0)).toList(growable: false);
    }

    return payload;
  }

  /// Despacha un evento atomico directamente a traves del bus y de sus nodos suscritos.
  void emitAtomicEvent(AtomicSignalEvent event) {
    emit(event.sourcePort, event);
  }

  /// Transmite una senal global a todos los nodos que acepten este tipo de senal.
  void broadcastGlobalSignal(AtomicSignalEvent event) {
    if (_isDisposed) return;
    for (final node in _registeredNodes.values) {
      if (node.isProcessingActive && node.acceptedSignalTypes.contains(event.signalType)) {
        node.onReceiveAtomicSignal(event);
      }
    }
  }

  /// Se suscribe al flujo de datos que ingresa a un puerto receptor (o que sale de un emisor).
  Stream<T> subscribe<T>(PortId port) {
    if (_isDisposed) {
      return Stream<T>.empty();
    }
    final key = _generatePortKey(port);
    registerPort(port);
    return _portControllers[key]!.stream.where((event) => event is T).cast<T>();
  }

  /// Limpia las rutas, conexiones y nodos registrados sin cerrar los
  /// [StreamController]s internos, permitiendo reutilizar el bus tras cargar
  /// un nuevo preset o paquete de proyecto.
  void clearRoutes() {
    if (_isDisposed) return;
    for (final subs in _nodeSubscriptions.values) {
      for (final sub in subs) {
        sub.cancel();
      }
    }
    _nodeSubscriptions.clear();
    _registeredNodes.clear();
    _connections.clear();
  }

  /// Alias de [clearRoutes] para reiniciar las rutas activas del bus.
  void reset() => clearRoutes();

  /// Limpia todas las conexiones y cierra definitivamente los streams del bus.
  void dispose() {
    if (_isDisposed) return;
    clearRoutes();
    _isDisposed = true;
    _registeredPorts.clear();
    for (final controller in _portControllers.values) {
      controller.close();
    }
    _portControllers.clear();
  }

  static String _generatePortKey(PortId port) =>
      '${port.ownerModuleId}_${port.id}_${port.direction.name}_${port.signalType.code}';
}
